using System.Net;
using System.Security.Cryptography;
using System.Text;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // T-RT-06/07: concurrent use of one refresh token. Exactly one rotation succeeds; any other
    // request with the same token is treated as reuse; the database never holds two active tokens.
    public class ConcurrentRefreshTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public ConcurrentRefreshTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private async Task<(int UserId, string Cookie)> LoginWebAsync()
        {
            var email = ApiTestHelpers.UniqueEmail("concurrent");
            await ApiTestHelpers.RegisterAsync(_factory.CreateClient(), _factory.Emails, email, "Secret123", "Customer");
            var response = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }));
            var body = await CookieClient.Json(response);
            return (body.GetProperty("userId").GetInt32(), CookieClient.CookieValue(response)!);
        }

        private async Task<HttpResponseMessage[]> RefreshInParallel(string cookie, int parallel)
        {
            using var start = new Barrier(parallel);
            var tasks = Enumerable.Range(0, parallel).Select(_ => Task.Run(async () =>
            {
                start.SignalAndWait();
                return await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie));
            }));
            return await Task.WhenAll(tasks);
        }

        private async Task AssertConsistentAsync(int userId, string originalCookie)
        {
            await _factory.WithDbAsync(async db =>
            {
                var sessionIds = await db.AuthSessions.Where(s => s.UserId == userId).Select(s => s.Id).ToListAsync();
                foreach (var sid in sessionIds)
                {
                    Assert.True(await db.RefreshTokens.CountAsync(t => t.SessionId == sid && t.Status == RefreshTokenStatus.Active) <= 1);
                }

                // The presented token's row is still there (never overwritten) and marked Rotated.
                var hash = SHA256.HashData(Encoding.ASCII.GetBytes(originalCookie));
                var original = await db.RefreshTokens.AsNoTracking().SingleAsync(t => t.TokenHash == hash);
                Assert.Equal(RefreshTokenStatus.Rotated, original.Status);
            });
        }

        [Fact]
        public async Task T_RT_06_two_parallel_refreshes_with_one_token_one_rotation_one_reuse()
        {
            for (var round = 0; round < 10; round++)
            {
                var (userId, cookie) = await LoginWebAsync();

                var responses = await RefreshInParallel(cookie, 2);

                var statuses = responses.Select(r => r.StatusCode).OrderBy(s => s).ToList();
                Assert.Equal(new[] { HttpStatusCode.OK, HttpStatusCode.Unauthorized }, statuses);
                var loser = responses.Single(r => r.StatusCode == HttpStatusCode.Unauthorized);
                Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(loser));

                await AssertConsistentAsync(userId, cookie);
                await _factory.WithDbAsync(async db =>
                {
                    var session = await db.AuthSessions.AsNoTracking().SingleAsync(s => s.UserId == userId);
                    Assert.Equal("ReuseDetected", session.RevokeReason); // the late request counted as reuse
                    Assert.Equal(2, await db.RefreshTokens.CountAsync(t => t.SessionId == session.Id)); // RT0 + the one successor
                    Assert.Equal(1, await db.SecurityEvents.CountAsync(e => e.UserId == userId && e.EventType == "Auth.RefreshTokenReuse"));
                });
            }
        }

        [Fact]
        public async Task T_RT_06_ten_parallel_refreshes_with_one_token_exactly_one_succeeds()
        {
            for (var round = 0; round < 3; round++)
            {
                var (userId, cookie) = await LoginWebAsync();

                var responses = await RefreshInParallel(cookie, 10);

                Assert.Equal(1, responses.Count(r => r.StatusCode == HttpStatusCode.OK));
                Assert.Equal(9, responses.Count(r => r.StatusCode == HttpStatusCode.Unauthorized));
                await AssertConsistentAsync(userId, cookie);
            }
        }

        [Fact]
        public async Task T_RT_07_a_refresh_waits_for_the_row_lock_held_by_another_transaction()
        {
            var (_, cookie) = await LoginWebAsync();
            var hash = SHA256.HashData(Encoding.ASCII.GetBytes(cookie));

            await using var connection = new SqlConnection(_factory.ConnectionString);
            await connection.OpenAsync();
            await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();
            await using (var command = new SqlCommand("SELECT Id FROM RefreshTokens WITH (UPDLOCK, ROWLOCK) WHERE TokenHash = @h", connection, transaction))
            {
                command.Parameters.Add(new SqlParameter("@h", hash));
                Assert.NotNull(await command.ExecuteScalarAsync());
            }

            var refresh = _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie));
            await Task.Delay(700);
            Assert.False(refresh.IsCompleted, "the refresh must wait for the row lock");

            await transaction.RollbackAsync();
            var response = await refresh.WaitAsync(TimeSpan.FromSeconds(15));
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
    }
}
