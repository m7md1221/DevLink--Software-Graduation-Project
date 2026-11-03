using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.JsonWebTokens;

namespace DevLink.Api.Tests
{
    // T-LG-01…05, T-SE-01, T-LOG-02 — password login in M2.4a.
    public class LoginTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public LoginTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<(string Email, int UserId)> NewAccountAsync(string userType = "Customer", string password = "Secret123")
        {
            var email = ApiTestHelpers.UniqueEmail(userType.ToLower());
            var id = await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, password, userType);
            return (email, id);
        }

        [Fact]
        public async Task T_LG_01_web_login_creates_a_session_and_returns_a_15_minute_token()
        {
            var (email, userId) = await NewAccountAsync();
            var before = DateTime.UtcNow.AddSeconds(-5);

            var response = await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            var token = body.GetProperty("accessToken").GetString()!;

            Assert.Equal("Customer", body.GetProperty("role").GetString());
            Assert.Equal("Active", body.GetProperty("status").GetString());
            Assert.False(response.Headers.Contains("Set-Cookie")); // refresh cookie is M2.4b

            var jwt = new JsonWebToken(token);
            Assert.Equal("at+jwt", jwt.Typ);
            Assert.Equal(userId.ToString(), jwt.Subject);
            Assert.InRange(jwt.ValidTo - jwt.IssuedAt, TimeSpan.FromMinutes(15), TimeSpan.FromMinutes(15));
            Assert.False(jwt.TryGetPayloadValue<string>("email", out _));

            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == userId);
                var session = await db.AuthSessions.AsNoTracking().SingleAsync(s => s.UserId == userId);

                Assert.Equal(jwt.GetPayloadValue<string>("sid"), session.Id.ToString());
                Assert.Equal(jwt.GetPayloadValue<string>("sstamp"), user.SecurityStamp);
                Assert.Equal(AuthClientType.Web, session.ClientType);
                Assert.Equal(AuthSessionStatus.Active, session.Status);
                Assert.InRange(session.AbsoluteExpiresAt - session.CreatedAt, TimeSpan.FromDays(30), TimeSpan.FromDays(30));
                Assert.True(user.LastLoginAt >= before);
                Assert.False(await db.RefreshTokens.AnyAsync(t => t.SessionId == session.Id)); // M2.4b
            });

            var me = await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token);
            Assert.Equal(HttpStatusCode.OK, me.StatusCode);
            var meBody = await me.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(userId, meBody.GetProperty("userId").GetInt32());
            Assert.Equal("Customer", meBody.GetProperty("role").GetString());
        }

        [Fact]
        public async Task T_LG_02_mobile_header_creates_a_mobile_session_and_admins_get_24_hours()
        {
            var (email, userId) = await NewAccountAsync("Programmer");
            await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Programmer", "mobile"));

            var adminEmail = ApiTestHelpers.UniqueEmail("admin");
            await _factory.WithDbAsync(async db =>
            {
                var admin = new User { Email = adminEmail, UserType = "Admin", PasswordHash = "" };
                admin.PasswordHash = new Services.PasswordService(new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build())
                    .Hash(admin, "AdminPass123");
                db.Users.Add(admin);
                await db.SaveChangesAsync();
            });
            await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, adminEmail, "AdminPass123", "Admin"));

            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal(AuthClientType.Mobile, (await db.AuthSessions.SingleAsync(s => s.UserId == userId)).ClientType);
                var adminSession = await db.AuthSessions.SingleAsync(s => s.User!.Email == adminEmail);
                Assert.InRange(adminSession.AbsoluteExpiresAt - adminSession.CreatedAt, TimeSpan.FromHours(24), TimeSpan.FromHours(24));
            });
        }

        [Fact]
        public async Task T_LG_03_unknown_email_wrong_password_and_wrong_portal_are_indistinguishable()
        {
            var (email, _) = await NewAccountAsync();

            var unknown = await SessionApiFactory.LoginAsync(_client, ApiTestHelpers.UniqueEmail("nobody"), "Secret123", "Customer");
            var wrongPassword = await SessionApiFactory.LoginAsync(_client, email, "Wrong-pass1", "Customer");
            var wrongPortal = await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Programmer");

            var bodies = new List<(HttpStatusCode, string?, string?)>();
            foreach (var r in new[] { unknown, wrongPassword, wrongPortal })
            {
                var b = await r.Content.ReadFromJsonAsync<JsonElement>();
                bodies.Add((r.StatusCode, b.GetProperty("errorCode").GetString(), b.GetProperty("message").GetString()));
            }

            Assert.All(bodies, b => Assert.Equal((HttpStatusCode.Unauthorized, "INVALID_CREDENTIALS", "Email or password is incorrect."), b));
        }

        [Fact]
        public async Task T_LG_04_legacy_short_plaintext_password_still_logs_in_and_is_rehashed()
        {
            var email = ApiTestHelpers.UniqueEmail("legacy");
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(new User { Email = email, PasswordHash = "abc123", UserType = "Customer" });
                await db.SaveChangesAsync();
            });

            await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "abc123", "Customer"));

            await _factory.WithDbAsync(async db =>
                Assert.True(Services.PasswordService.IsIdentityHash((await db.Users.SingleAsync(u => u.Email == email)).PasswordHash)));
        }

        [Fact]
        public async Task T_SE_01_login_events_are_recorded_with_ip_prefix_only_on_failures_and_no_secrets()
        {
            var (email, userId) = await NewAccountAsync();
            var unknownEmail = ApiTestHelpers.UniqueEmail("ghost");

            var token = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer"));
            await SessionApiFactory.LoginAsync(_client, email, "Wrong-pass1", "Customer");
            await SessionApiFactory.LoginAsync(_client, unknownEmail, "Wrong-pass1", "Customer");

            await _factory.WithDbAsync(async db =>
            {
                var mine = await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == userId).ToListAsync();
                var success = Assert.Single(mine, e => e.EventType == "Auth.LoginSucceeded");
                Assert.Equal("Success", success.Outcome);
                Assert.NotNull(success.SessionId);
                Assert.Null(success.IpPrefix); // R3: no IP for successful logins

                var failed = Assert.Single(mine, e => e.EventType == "Auth.LoginFailed");
                Assert.Equal(SessionApiFactory.ClientIpPrefix, failed.IpPrefix);
                Assert.Contains("WrongPassword", failed.Details);

                Assert.Contains(await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == null && e.EventType == "Auth.LoginFailed").ToListAsync(),
                    e => e.Details!.Contains("UnknownEmail") && e.IpPrefix == SessionApiFactory.ClientIpPrefix);

                var everything = string.Join("|", (await db.SecurityEvents.AsNoTracking().ToListAsync()).Select(e =>
                    $"{e.EventType}{e.Outcome}{e.TargetType}{e.TargetId}{e.EmailKey}{e.IpPrefix}{e.ClientType}{e.TraceId}{e.Details}"));
                foreach (var secret in new[] { email, unknownEmail, "Secret123", "Wrong-pass1", token, SessionApiFactory.ClientIp })
                {
                    Assert.DoesNotContain(secret, everything);
                }
            });
        }

        [Fact]
        public async Task T_LOG_02_login_logs_contain_no_password_email_token_or_ip()
        {
            var (email, _) = await NewAccountAsync();
            var token = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer"));
            await SessionApiFactory.LoginAsync(_client, email, "Wrong-pass1", "Customer");
            await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token);

            var logs = _factory.Logs.AllText;
            Assert.Contains("Auth.LoginSucceeded", logs);
            Assert.Contains("Auth.LoginFailed", logs);
            foreach (var secret in new[] { email, "Secret123", "Wrong-pass1", token, SessionApiFactory.ClientIp, SessionApiFactory.ClientIpPrefix })
            {
                Assert.DoesNotContain(secret, logs);
            }
        }
    }
}
