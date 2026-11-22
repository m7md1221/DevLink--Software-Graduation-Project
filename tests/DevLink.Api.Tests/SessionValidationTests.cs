using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // T-SC-01…05 (per-request session check, C2), T-SP-01…03 (suspended accounts), T-REG-01.
    public class SessionValidationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public SessionValidationTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<(int UserId, string Token)> SignedInAsync(string userType = "Customer")
        {
            var email = ApiTestHelpers.UniqueEmail("session");
            var userId = await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", userType);
            var token = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", userType));
            return (userId, token);
        }

        private SessionStateCache Cache => _factory.Services.GetRequiredService<SessionStateCache>();

        private Task<HttpResponseMessage> Me(string token) => SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token);

        [Fact]
        public async Task T_SC_01_security_stamp_change_through_the_api_takes_effect_on_the_next_request()
        {
            var (userId, token) = await SignedInAsync();
            Assert.Equal(HttpStatusCode.OK, (await Me(token)).StatusCode);

            await _factory.WithDbAsync(async db =>
                await db.Users.Where(u => u.Id == userId).ExecuteUpdateAsync(s => s.SetProperty(u => u.SecurityStamp, User.NewSecurityStamp())));
            Cache.Invalidate(userId); // what every API write path does after committing

            var response = await Me(token);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(response));
        }

        [Fact]
        public async Task T_SC_02_revoked_or_expired_session_is_rejected()
        {
            var (revokedUser, revokedToken) = await SignedInAsync();
            var (expiredUser, expiredToken) = await SignedInAsync();

            await _factory.WithDbAsync(async db =>
            {
                await db.AuthSessions.Where(s => s.UserId == revokedUser).ExecuteUpdateAsync(s => s.SetProperty(x => x.Status, AuthSessionStatus.Revoked));
                await db.AuthSessions.Where(s => s.UserId == expiredUser).ExecuteUpdateAsync(s => s.SetProperty(x => x.AbsoluteExpiresAt, DateTime.UtcNow.AddMinutes(-1)));
            });
            Cache.Invalidate(revokedUser);
            Cache.Invalidate(expiredUser);

            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(await Me(revokedToken)));
            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(await Me(expiredToken)));
        }

        [Fact]
        public async Task T_SC_03_a_new_login_is_accepted_immediately_although_the_user_was_cached()
        {
            var email = ApiTestHelpers.UniqueEmail("relogin");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");
            var first = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer"));
            Assert.Equal(HttpStatusCode.OK, (await Me(first)).StatusCode); // user state is now cached

            var second = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer"));

            Assert.Equal(HttpStatusCode.OK, (await Me(second)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Me(first)).StatusCode); // other sessions unaffected
        }

        [Fact]
        public async Task T_SC_05_out_of_process_changes_take_effect_within_30_seconds()
        {
            var (userId, token) = await SignedInAsync();
            Assert.Equal(HttpStatusCode.OK, (await Me(token)).StatusCode);

            // A change made outside the API (no invalidation): served from the cache for at most 30 s.
            await _factory.WithDbAsync(async db =>
                await db.Users.Where(u => u.Id == userId).ExecuteUpdateAsync(s => s.SetProperty(u => u.SecurityStamp, User.NewSecurityStamp())));
            Assert.Equal(HttpStatusCode.OK, (await Me(token)).StatusCode);

            _factory.Time.Advance(TimeSpan.FromSeconds(31));
            try
            {
                Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(await Me(token)));
            }
            finally
            {
                _factory.Time.Advance(TimeSpan.FromSeconds(-31)); // shared fixture clock
            }
        }

        [Fact]
        public async Task T_SC_04_session_check_fails_closed_with_503_when_the_database_is_unavailable()
        {
            // Real validator, but the host's database does not exist.
            using var factory = new HostOnlyApiFactory(useRealSessionValidator: true);
            var client = factory.CreateClient();
            var token = new TokenMinter { KeyBase64 = factory.SigningKey }.Mint();

            var response = await SessionApiFactory.GetWithToken(client, "/__tests/auth/me", token);

            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            Assert.Equal("SERVICE_UNAVAILABLE", await SessionApiFactory.ErrorCode(response));
        }

        [Fact]
        public async Task T_SP_01_suspended_account_signs_in_to_restricted_mode()
        {
            var email = ApiTestHelpers.UniqueEmail("suspended");
            var userId = await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");
            await _factory.WithDbAsync(async db =>
                await db.Users.Where(u => u.Id == userId).ExecuteUpdateAsync(s => s
                    .SetProperty(u => u.Status, UserStatus.Suspended)
                    .SetProperty(u => u.SuspendedReason, "Spam reports under review")));

            var login = await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer");
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            var loginBody = await login.Content.ReadFromJsonAsync<JsonElement>();
            var token = loginBody.GetProperty("accessToken").GetString()!;
            Assert.Equal("Suspended", loginBody.GetProperty("status").GetString());

            // Allowed: the notice (Auth/me) and own support conversations.
            var me = await Me(token);
            Assert.Equal(HttpStatusCode.OK, me.StatusCode);
            var meBody = await me.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("Suspended", meBody.GetProperty("status").GetString());
            Assert.Equal("Spam reports under review", meBody.GetProperty("suspendedReason").GetString());
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, $"/api/Support/my/{userId}", token)).StatusCode);

            // Everything else: 403 ACCOUNT_SUSPENDED.
            foreach (var route in new[] { "/__tests/auth/me", $"/api/Posts/feed?userId={userId}", "/api/ProgrammerProfile/all", $"/api/Notifications/{userId}" })
            {
                var blocked = await SessionApiFactory.GetWithToken(_client, route, token);
                Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
                Assert.Equal("ACCOUNT_SUSPENDED", await SessionApiFactory.ErrorCode(blocked));
            }
        }

        [Fact]
        public async Task T_SP_02_active_accounts_are_not_affected_and_anonymous_calls_need_sign_in()
        {
            var (userId, token) = await SignedInAsync();

            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={userId}", token)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/__tests/auth/me", token)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={userId}", null)).StatusCode);
        }

        [Fact]
        public async Task T_REG_01_member_routes_refuse_invalid_or_revoked_tokens()
        {
            var (userId, token) = await SignedInAsync();
            await _factory.WithDbAsync(async db =>
                await db.AuthSessions.Where(s => s.UserId == userId).ExecuteUpdateAsync(s => s.SetProperty(x => x.Status, AuthSessionStatus.Revoked)));
            Cache.Invalidate(userId);

            // Since M2.7d the feed needs a token, so a bad one is refused instead of meaning "anonymous".
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={userId}", token)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={userId}", "garbage.token.value")).StatusCode);
        }
    }
}
