using System.Net;
using System.Net.Http.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Services;

namespace DevLink.Api.Tests
{
    // T-PW-01…06 (reset revokes sessions; policy C7) and T-RC-01 (admin role change signs the user out).
    public class PasswordPolicyTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public PasswordPolicyTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<(string Email, int UserId)> AccountAsync()
        {
            var email = ApiTestHelpers.UniqueEmail("policy");
            return (email, await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer"));
        }

        [Fact]
        public async Task T_PW_01_password_reset_revokes_every_session_and_clears_the_lockout()
        {
            var (email, userId) = await AccountAsync();
            var cookieClient = CookieClient.Create(_factory);
            var web = await cookieClient.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }));
            var webAccess = (await CookieClient.Json(web)).GetProperty("accessToken").GetString()!;
            var cookie = CookieClient.CookieValue(web)!;
            var legacyAccess = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer"));
            for (var i = 0; i < 3; i++) await SessionApiFactory.LoginAsync(_client, email, "Wrong-pass1", "Customer");
            string stampBefore = "";
            await _factory.WithDbAsync(async db => stampBefore = (await db.Users.SingleAsync(u => u.Id == userId)).SecurityStamp);

            var resetToken = await ApiTestHelpers.VerifyResetAsync(_client, _factory.Emails, email);
            var reset = await _client.PostAsJsonAsync("/api/Auth/reset-password", new { email, newPassword = "Brand-New-Pass-42", resetToken });

            Assert.Equal(HttpStatusCode.OK, reset.StatusCode);
            foreach (var token in new[] { webAccess, legacyAccess })
            {
                var me = await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token);
                Assert.Equal(HttpStatusCode.Unauthorized, me.StatusCode);
                Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(me));
            }

            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await cookieClient.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie))));
            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == userId);
                Assert.NotEqual(stampBefore, user.SecurityStamp);
                Assert.Equal(0, user.FailedLoginCount);
                Assert.False(await db.AuthSessions.AnyAsync(s => s.UserId == userId && s.Status == AuthSessionStatus.Active));
                Assert.Equal("PasswordReset", (await db.AuthSessions.AsNoTracking().FirstAsync(s => s.UserId == userId)).RevokeReason);
                Assert.Contains(await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == userId).Select(e => e.EventType).ToListAsync(), t => t == "Auth.PasswordReset");
            });

            _factory.Emails.WaitFor(email, m => m.Subject == "Your DevLink password was changed");
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, email, "Brand-New-Pass-42", "Customer")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer")).StatusCode);
        }

        [Theory]
        [InlineData("Short7!")]          // 7 characters
        [InlineData("12345678")]         // on the list
        [InlineData("PASSWORD")]         // on the list, any case
        [InlineData(" iloveyou ")]       // on the list, surrounding spaces
        public async Task T_PW_02_new_passwords_must_meet_the_policy_and_a_rejection_keeps_the_proof(string password)
        {
            var email = ApiTestHelpers.UniqueEmail("weak");
            var token = await ApiTestHelpers.VerifyEmailAsync(_client, _factory.Emails, email);

            var weak = await _client.PostAsJsonAsync("/api/Auth/signup", new { email, password, userType = "Customer", signupToken = token });
            Assert.Equal(HttpStatusCode.BadRequest, weak.StatusCode);
            Assert.Equal("PASSWORD_POLICY", await SessionApiFactory.ErrorCode(weak));

            // The proof was not spent: the same token works with an acceptable password.
            Assert.Equal(HttpStatusCode.OK, (await _client.PostAsJsonAsync("/api/Auth/signup",
                new { email, password = "Kq7#mzpw-ok", userType = "Customer", signupToken = token })).StatusCode);
        }

        [Fact]
        public async Task T_PW_03_the_email_or_its_local_part_is_not_accepted_as_a_password()
        {
            var email = ApiTestHelpers.UniqueEmail("selfpass");
            var token = await ApiTestHelpers.VerifyEmailAsync(_client, _factory.Emails, email);
            var localPart = email.Split('@')[0];

            foreach (var password in new[] { email, email.ToUpperInvariant(), localPart })
            {
                var response = await _client.PostAsJsonAsync("/api/Auth/signup", new { email, password, userType = "Customer", signupToken = token });
                Assert.Equal("PASSWORD_POLICY", await SessionApiFactory.ErrorCode(response));
            }
        }

        [Fact]
        public async Task T_PW_04_admin_create_and_update_apply_the_policy()
        {
            var email = ApiTestHelpers.UniqueEmail("admin-made");
            Assert.Equal(HttpStatusCode.BadRequest, (await _client.PostAsJsonAsync("/api/Admin/users", new { email, password = "password1", userType = "Customer" })).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await _client.PostAsJsonAsync("/api/Admin/users", new { email, password = "Managed-Ok-9", userType = "Customer" })).StatusCode);

            int id = 0;
            await _factory.WithDbAsync(async db => id = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync());
            Assert.Equal(HttpStatusCode.BadRequest, (await _client.PutAsJsonAsync($"/api/Admin/users/{id}", new { password = "qwerty123" })).StatusCode);
        }

        [Fact]
        public async Task T_PW_05_legacy_accounts_with_short_or_listed_passwords_still_sign_in()
        {
            foreach (var legacy in new[] { "abc123", "password" })
            {
                var email = ApiTestHelpers.UniqueEmail("legacy-pw");
                await _factory.WithDbAsync(async db =>
                {
                    db.Users.Add(new User { Email = email, PasswordHash = legacy, UserType = "Customer" });
                    await db.SaveChangesAsync();
                });

                Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, email, legacy, "Customer")).StatusCode);
            }
        }

        [Fact]
        public void T_PW_06_the_bundled_list_is_loaded_and_matches_case_insensitively()
        {
            var service = new PasswordService(new ConfigurationBuilder().Build());

            Assert.InRange(PasswordService.CommonPasswordCount, 9_900, 10_001);
            Assert.Equal(8, service.MinLength);
            Assert.Equal(PasswordService.TooCommonMessage, service.ValidatePolicy("QwErTy123"));
            Assert.Null(service.ValidatePolicy("Kq7#mzpw-ok"));
        }

        [Fact]
        public async Task T_RC_01_an_admin_role_change_signs_the_user_out_and_a_new_login_carries_the_new_role()
        {
            var (email, userId) = await AccountAsync();
            var token = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Customer"));
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token)).StatusCode);

            var update = await _client.PutAsJsonAsync($"/api/Admin/users/{userId}", new { userType = "Programmer" });
            Assert.Equal(HttpStatusCode.OK, update.StatusCode);

            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", token)));
            var relogin = await SessionApiFactory.LoginAsync(_client, email, "Secret123", "Programmer");
            Assert.Equal("Programmer", new Microsoft.IdentityModel.JsonWebTokens.JsonWebToken(await SessionApiFactory.TokenFrom(relogin)).GetPayloadValue<string>("role"));
            await _factory.WithDbAsync(async db =>
            {
                var sessions = await db.AuthSessions.AsNoTracking().Where(s => s.UserId == userId).ToListAsync();
                Assert.Contains(sessions, s => s.Status == AuthSessionStatus.Revoked && s.RevokeReason == "RoleChanged"); // the old one
                Assert.Single(sessions, s => s.Status == AuthSessionStatus.Active);                                       // the new login
            });
        }
    }
}
