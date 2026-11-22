using System.Net;
using System.Net.Http.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // Google keys from the tests (for Google-only accounts) and a change-password limit high enough for a whole class.
    public class ChangePasswordApiFactory : GoogleApiFactory
    {
        protected override IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?>
        {
            ["RateLimits:PasswordChange:PermitLimit"] = "1000"
        };
    }

    public class LowChangePasswordLimitFactory : SessionApiFactory
    {
        protected override IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?>
        {
            ["RateLimits:PasswordChange:PermitLimit"] = "2"
        };
    }

    // ============================================================
    // M2.11b: POST /api/Auth/change-password (FR-AUTH-11; design §3.6, C7).
    // The change-password parts of T-PW-01 and T-PW-05…08, plus the wrong
    // current password (lockout), Google-only accounts, rate limit and
    // anonymous callers.
    // ============================================================
    public class ChangePasswordTests : IClassFixture<ChangePasswordApiFactory>
    {
        private const string Password = "Matrix-Pass-42";

        private readonly ChangePasswordApiFactory _factory;
        private readonly HttpClient _client;

        public ChangePasswordTests(ChangePasswordApiFactory factory)
        {
            factory.Time.Reset();
            factory.GoogleKeys.Fail = false;
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private Task<HttpResponseMessage> ChangeAsync(string? bearer, string currentPassword, string newPassword) =>
            _client.SendAsync(CookieClient.Post("/api/Auth/change-password", new { currentPassword, newPassword }, client: null, origin: null, bearer: bearer));

        private async Task<User> UserAsync(int id)
        {
            User? user = null;
            await _factory.WithDbAsync(async db => user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == id));
            return user!;
        }

        [Fact]
        public async Task T_PW_01c_change_password_keeps_the_current_session_and_ends_every_other_one()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var current = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = account.Email, password = Password, userType = "Customer" }));
            var currentAccess = (await CookieClient.Json(current)).GetProperty("accessToken").GetString()!;
            var currentCookie = CookieClient.CookieValue(current)!;
            var otherWeb = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = account.Email, password = Password, userType = "Customer" }));
            var otherCookie = CookieClient.CookieValue(otherWeb)!;
            var otherAccess = (await CookieClient.Json(otherWeb)).GetProperty("accessToken").GetString()!;
            var stampBefore = (await UserAsync(account.Id)).SecurityStamp;

            var change = await ChangeAsync(currentAccess, Password, "Brand-New-Pass-42");

            Assert.Equal(HttpStatusCode.OK, change.StatusCode);
            var newAccess = (await CookieClient.Json(change)).GetProperty("accessToken").GetString()!;

            // The current session: the new token works and its refresh token still rotates; the old token carries the old stamp.
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", newAccess)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", currentAccess)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: currentCookie))).StatusCode);

            // Every other session ends: its access token (the account's own token from earlier) and its refresh cookie.
            foreach (var token in new[] { account.Token, otherAccess })
            {
                var me = await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token);
                Assert.Equal(HttpStatusCode.Unauthorized, me.StatusCode);
                Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(me));
            }

            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: otherCookie))));

            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == account.Id);
                Assert.NotEqual(stampBefore, user.SecurityStamp);
                Assert.True(user.HasPassword);
                var sessions = await db.AuthSessions.AsNoTracking().Where(s => s.UserId == account.Id).ToListAsync();
                Assert.Single(sessions, s => s.Status == AuthSessionStatus.Active);
                Assert.All(sessions.Where(s => s.Status != AuthSessionStatus.Active), s => Assert.Equal("PasswordChanged", s.RevokeReason));
                var evt = await db.SecurityEvents.AsNoTracking().SingleAsync(e => e.UserId == account.Id && e.EventType == "Auth.PasswordChanged");
                Assert.Equal("Success", evt.Outcome);
                Assert.Equal(sessions.Single(s => s.Status == AuthSessionStatus.Active).Id, evt.SessionId);
                Assert.Contains("\"sessionsEnded\":2", evt.Details);
            });

            _factory.Emails.WaitFor(account.Email, m => m.Subject == PasswordChangeService.NoticeSubject);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, account.Email, "Brand-New-Pass-42", "Customer")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.LoginAsync(_client, account.Email, Password, "Customer")).StatusCode);
        }

        [Theory]
        [InlineData("Short7!")]      // 7 characters
        [InlineData("password1")]    // on the list
        [InlineData("PASSWORD")]     // on the list, any case
        [InlineData(" qwerty123 ")]  // on the list, surrounding spaces
        public async Task T_PW_05c_change_password_refuses_short_or_listed_passwords_and_changes_nothing(string newPassword)
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var before = await UserAsync(account.Id);

            var response = await ChangeAsync(account.Token, Password, newPassword);

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal("PASSWORD_POLICY", await SessionApiFactory.ErrorCode(response));
            var after = await UserAsync(account.Id);
            Assert.Equal(before.SecurityStamp, after.SecurityStamp);
            Assert.Equal(before.PasswordHash, after.PasswordHash);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", account.Token)).StatusCode);
        }

        [Fact]
        public async Task T_PW_06c_change_password_refuses_the_email_or_its_local_part()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");

            foreach (var newPassword in new[] { account.Email, account.Email.ToUpperInvariant(), account.Email.Split('@')[0] })
            {
                Assert.Equal("PASSWORD_POLICY", await SessionApiFactory.ErrorCode(await ChangeAsync(account.Token, Password, newPassword)));
            }
        }

        [Fact]
        public async Task T_PW_07c_a_legacy_account_whose_password_is_listed_can_change_it()
        {
            var email = ApiTestHelpers.UniqueEmail("legacy-change");
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(new User { Email = email, PasswordHash = "password", UserType = "Customer" });
                await db.SaveChangesAsync();
            });
            var token = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "password", "Customer"));

            Assert.Equal(HttpStatusCode.OK, (await ChangeAsync(token, "password", "Kq7#mzpw-ok")).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, email, "Kq7#mzpw-ok", "Customer")).StatusCode);
        }

        [Fact]
        public async Task T_PW_08c_an_unlisted_8_character_password_is_accepted()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Programmer");

            Assert.Equal(HttpStatusCode.OK, (await ChangeAsync(account.Token, Password, "Zx8!pq4w")).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, account.Email, "Zx8!pq4w", "Programmer")).StatusCode);
        }

        [Fact]
        public async Task T_PW_09_a_wrong_current_password_counts_toward_the_same_lockout_as_login()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            for (var i = 0; i < 3; i++)
            {
                await SessionApiFactory.LoginAsync(_client, account.Email, "Wrong-pass-1", "Customer");
            }

            var first = await ChangeAsync(account.Token, "Wrong-pass-1", "Brand-New-Pass-42");
            Assert.Equal(HttpStatusCode.BadRequest, first.StatusCode);
            Assert.Equal("INVALID_CREDENTIALS", await SessionApiFactory.ErrorCode(first));
            Assert.Equal(4, (await UserAsync(account.Id)).FailedLoginCount);

            // The 5th failure in all locks the account: change-password and login both refuse, even the right password.
            Assert.Equal(HttpStatusCode.BadRequest, (await ChangeAsync(account.Token, "Wrong-pass-1", "Brand-New-Pass-42")).StatusCode);
            var locked = await ChangeAsync(account.Token, Password, "Brand-New-Pass-42");
            Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
            Assert.Equal("ACCOUNT_LOCKED", await SessionApiFactory.ErrorCode(locked));
            Assert.Equal(HttpStatusCode.TooManyRequests, (await SessionApiFactory.LoginAsync(_client, account.Email, Password, "Customer")).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var events = await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == account.Id).ToListAsync();
                Assert.Equal(2, events.Count(e => e.EventType == "Auth.LoginFailed" && e.Details!.Contains("ChangePasswordWrongPassword")));
                Assert.Contains(events, e => e.EventType == "Auth.LockedOut");
                Assert.DoesNotContain(events, e => e.EventType == "Auth.PasswordChanged" && e.Outcome == "Success");
            });
        }

        [Fact]
        public async Task T_PW_10_a_google_only_account_is_told_to_use_password_reset_and_can_change_after_one()
        {
            var google = new GoogleToken();
            var signUp = await _client.SendAsync(CookieClient.Post("/api/Auth/google-login",
                new { idToken = google.Mint(_factory.GoogleKeys.Key), userType = "Customer", mode = "signup" }, client: null, origin: null));
            Assert.Equal(HttpStatusCode.OK, signUp.StatusCode);
            var body = await CookieClient.Json(signUp);
            var userId = body.GetProperty("userId").GetInt32();
            var token = body.GetProperty("accessToken").GetString()!;
            Assert.False((await UserAsync(userId)).HasPassword);

            foreach (var guess in new[] { "anything-at-all", "Another-Guess-1", "Third-Guess-22" })
            {
                var response = await ChangeAsync(token, guess, "Brand-New-Pass-42");
                Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
                Assert.Equal("PASSWORD_NOT_SET", await SessionApiFactory.ErrorCode(response));
                Assert.Contains("Forgot password", (await CookieClient.Json(response)).GetProperty("message").GetString());
            }

            // No lockout builds up, and the session is untouched.
            Assert.Equal(0, (await UserAsync(userId)).FailedLoginCount);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token)).StatusCode);

            // A password reset gives the account a password; then change-password works.
            var resetToken = await ApiTestHelpers.VerifyResetAsync(_client, _factory.Emails, google.Email);
            Assert.Equal(HttpStatusCode.OK, (await _client.PostAsJsonAsync("/api/Auth/reset-password", new { email = google.Email, newPassword = "Reset-Pass-Now-7", resetToken })).StatusCode);
            Assert.True((await UserAsync(userId)).HasPassword);
            var fresh = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, google.Email, "Reset-Pass-Now-7", "Customer"));
            Assert.Equal(HttpStatusCode.OK, (await ChangeAsync(fresh, "Reset-Pass-Now-7", "Changed-Pass-Now-8")).StatusCode);
        }

        [Fact]
        public async Task T_PW_11_anonymous_and_ended_sessions_get_401_and_missing_fields_get_400()
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await ChangeAsync(null, Password, "Brand-New-Pass-42")).StatusCode);

            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            Assert.Equal(HttpStatusCode.BadRequest, (await ChangeAsync(account.Token, "", "Brand-New-Pass-42")).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await ChangeAsync(account.Token, Password, "")).StatusCode);

            var other = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, account.Email, Password, "Customer"));
            Assert.Equal(HttpStatusCode.OK, (await ChangeAsync(account.Token, Password, "Brand-New-Pass-42")).StatusCode);

            // The other session's token can't be used to change the password again.
            var stale = await ChangeAsync(other, "Brand-New-Pass-42", "Another-New-Pass-43");
            Assert.Equal(HttpStatusCode.Unauthorized, stale.StatusCode);
            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(stale));
        }
    }

    public class ChangePasswordRateLimitTests : IClassFixture<LowChangePasswordLimitFactory>
    {
        private readonly LowChangePasswordLimitFactory _factory;

        public ChangePasswordRateLimitTests(LowChangePasswordLimitFactory factory)
        {
            factory.Time.Reset();
            _factory = factory;
        }

        [Fact]
        public async Task T_PW_12_change_password_is_rate_limited_per_ip()
        {
            var client = CookieClient.Create(_factory);
            var account = await AdminRoutes.AccountAsync(_factory, client, "Customer");
            Task<HttpResponseMessage> Send() => client.SendAsync(CookieClient.Post("/api/Auth/change-password",
                new { currentPassword = "not-it", newPassword = "Brand-New-Pass-42" }, client: null, origin: null, bearer: account.Token));

            Assert.Equal(HttpStatusCode.BadRequest, (await Send()).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await Send()).StatusCode);
            var limited = await Send();

            Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
            Assert.Equal("RATE_LIMITED", await SessionApiFactory.ErrorCode(limited));
            Assert.True(limited.Headers.Contains("Retry-After"));
        }
    }
}
