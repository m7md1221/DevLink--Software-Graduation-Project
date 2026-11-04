using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // M2.5b: T-AD-01/02 (new routes are Admin-only), T-SU-01…05 (suspend / unsuspend),
    // T-DEL-01…03 (KI-39: delete removes sessions and refresh tokens), T-AU-01/02 (admin audit).
    public class AdminAccountActionsTests : IClassFixture<SessionApiFactory>
    {
        private const string Password = "Secret123";
        private const string AdminPassword = "Admin-Pass-91x";
        private const string Reason = "Repeated spam in project posts";

        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public AdminAccountActionsTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private sealed record Account(int Id, string Email, string Token);

        private async Task<Account> CustomerAsync(string userType = "Customer")
        {
            var email = ApiTestHelpers.UniqueEmail("admin-target");
            var id = await ApiTestHelpers.RegisterAsync(_factory.CreateClient(), _factory.Emails, email, Password, userType);
            return new Account(id, email, await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, Password, userType)));
        }

        // Admins can't be created through the API (Q10): inserted directly, signing in through the normal login.
        private async Task<Account> AdminAsync()
        {
            var email = ApiTestHelpers.UniqueEmail("admin");
            int id = 0;
            await _factory.WithDbAsync(async db =>
            {
                var admin = new User { Email = email, PasswordHash = AdminPassword, UserType = "Admin" };
                db.Users.Add(admin);
                await db.SaveChangesAsync();
                id = admin.Id;
            });
            return new Account(id, email, await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, email, AdminPassword, "Admin")));
        }

        private Task<HttpResponseMessage> Send(HttpMethod method, string route, string? token, object? body = null)
        {
            var request = new HttpRequestMessage(method, route);
            if (body != null) request.Content = JsonContent.Create(body);
            if (token != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return _client.SendAsync(request);
        }

        private Task<HttpResponseMessage> Suspend(int id, string? token, string? reason = Reason) =>
            Send(HttpMethod.Post, $"/api/Admin/users/{id}/suspend", token, new { reason });

        private Task<HttpResponseMessage> Unsuspend(int id, string? token) =>
            Send(HttpMethod.Post, $"/api/Admin/users/{id}/unsuspend", token);

        private static async Task<string?> Message(HttpResponseMessage response) =>
            JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement.TryGetProperty("message", out var m) ? m.GetString() : null;

        private async Task<List<SecurityEvent>> EventsFor(int userId, string type)
        {
            var events = new List<SecurityEvent>();
            await _factory.WithDbAsync(async db =>
                events = await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == userId && e.EventType == type).OrderBy(e => e.Id).ToListAsync());
            return events;
        }

        // ---------------- T-AD: new routes require an Admin token ----------------

        [Fact]
        public async Task T_AD_01_suspend_and_unsuspend_require_an_admin_token()
        {
            var target = await CustomerAsync();
            var customer = await CustomerAsync();
            var programmer = await CustomerAsync("Programmer");

            foreach (var send in new Func<string?, Task<HttpResponseMessage>>[] { t => Suspend(target.Id, t), t => Unsuspend(target.Id, t) })
            {
                var anonymous = await send(null);
                Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
                Assert.Equal("UNAUTHENTICATED", await SessionApiFactory.ErrorCode(anonymous));

                foreach (var token in new[] { customer.Token, programmer.Token })
                {
                    var forbidden = await send(token);
                    Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
                    Assert.Equal("FORBIDDEN", await SessionApiFactory.ErrorCode(forbidden));
                }
            }

            await _factory.WithDbAsync(async db => Assert.Equal(UserStatus.Active, (await db.Users.SingleAsync(u => u.Id == target.Id)).Status));
        }

        [Fact]
        public async Task T_AD_02_a_revoked_admin_token_cannot_suspend()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();
            Assert.Equal(HttpStatusCode.NoContent, (await _client.SendAsync(CookieClient.Post("/api/Auth/logout-all", bearer: admin.Token, client: null, origin: null))).StatusCode);

            var response = await Suspend(target.Id, admin.Token);

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(response));
        }

        // ---------------- T-SU: suspend / unsuspend ----------------

        [Fact]
        public async Task T_SU_01_suspension_rejects_the_old_token_at_once_and_a_new_login_is_restricted()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", target.Token)).StatusCode);
            string stampBefore = "";
            await _factory.WithDbAsync(async db => stampBefore = (await db.Users.SingleAsync(u => u.Id == target.Id)).SecurityStamp);

            var response = await Suspend(target.Id, admin.Token);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal("User suspended successfully", await Message(response));

            // C2: no 30-second window through the API — the very next request is refused.
            var old = await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", target.Token);
            Assert.Equal(HttpStatusCode.Unauthorized, old.StatusCode);
            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(old));

            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == target.Id);
                Assert.Equal(UserStatus.Suspended, user.Status);
                Assert.Equal(Reason, user.SuspendedReason);
                Assert.NotNull(user.SuspendedAt);
                Assert.NotEqual(stampBefore, user.SecurityStamp);
                Assert.False(await db.AuthSessions.AnyAsync(s => s.UserId == target.Id && s.Status == AuthSessionStatus.Active));
                Assert.Equal("Suspended", (await db.AuthSessions.AsNoTracking().FirstAsync(s => s.UserId == target.Id)).RevokeReason);
            });

            // A new login succeeds into restricted mode only.
            var login = await SessionApiFactory.LoginAsync(_client, target.Email, Password, "Customer");
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            Assert.Equal("Suspended", (await CookieClient.Json(login)).GetProperty("status").GetString());
            var restricted = await SessionApiFactory.TokenFrom(login);

            var me = await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", restricted);
            Assert.Equal(HttpStatusCode.OK, me.StatusCode);
            Assert.Equal(Reason, (await CookieClient.Json(me)).GetProperty("suspendedReason").GetString());

            var feed = await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={target.Id}", restricted);
            Assert.Equal(HttpStatusCode.Forbidden, feed.StatusCode);
            Assert.Equal("ACCOUNT_SUSPENDED", await SessionApiFactory.ErrorCode(feed));
        }

        [Fact]
        public async Task T_SU_02_unsuspend_restores_full_access_immediately_and_clears_the_reason()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();
            Assert.Equal(HttpStatusCode.OK, (await Suspend(target.Id, admin.Token)).StatusCode);
            var restricted = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, target.Email, Password, "Customer"));
            Assert.Equal(HttpStatusCode.Forbidden, (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={target.Id}", restricted)).StatusCode);

            var response = await Unsuspend(target.Id, admin.Token);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal("User unsuspended successfully", await Message(response));
            // The session opened while suspended now has full access (cache cleared, no 30 s wait).
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={target.Id}", restricted)).StatusCode);

            var login = await SessionApiFactory.LoginAsync(_client, target.Email, Password, "Customer");
            Assert.Equal("Active", (await CookieClient.Json(login)).GetProperty("status").GetString());
            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == target.Id);
                Assert.Equal(UserStatus.Active, user.Status);
                Assert.Null(user.SuspendedReason);
                Assert.Null(user.SuspendedAt);
            });
        }

        [Fact]
        public async Task T_SU_03_admins_cannot_suspend_themselves_or_another_admin()
        {
            var admin = await AdminAsync();
            var other = await AdminAsync();

            var self = await Suspend(admin.Id, admin.Token);
            Assert.Equal(HttpStatusCode.Forbidden, self.StatusCode);
            Assert.Equal("You cannot suspend your own account", await Message(self));

            var otherAdmin = await Suspend(other.Id, admin.Token);
            Assert.Equal(HttpStatusCode.Forbidden, otherAdmin.StatusCode);
            Assert.Equal("Admin accounts cannot be suspended", await Message(otherAdmin));
            Assert.Equal(HttpStatusCode.Forbidden, (await Unsuspend(other.Id, admin.Token)).StatusCode);

            // Both admins keep working sessions.
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", other.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", admin.Token)).StatusCode);
        }

        [Theory]
        [InlineData(null)]
        [InlineData("   ")]
        [InlineData("too-long")]
        public async Task T_SU_04_a_reason_of_1_to_500_characters_is_required(string? reason)
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();
            if (reason == "too-long") reason = new string('x', 501);

            var response = await Suspend(target.Id, admin.Token, reason);

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", target.Token)).StatusCode);
        }

        [Fact]
        public async Task T_SU_05_unknown_users_get_404_and_repeated_actions_change_nothing()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();

            Assert.Equal(HttpStatusCode.NotFound, (await Suspend(999_999, admin.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await Unsuspend(999_999, admin.Token)).StatusCode);
            Assert.Equal("User is not suspended", await Message(await Unsuspend(target.Id, admin.Token)));

            Assert.Equal(HttpStatusCode.OK, (await Suspend(target.Id, admin.Token)).StatusCode);
            var restricted = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, target.Email, Password, "Customer"));
            var again = await Suspend(target.Id, admin.Token, "another reason");

            Assert.Equal("User is already suspended", await Message(again));
            // No second revocation and the first reason is kept.
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", restricted)).StatusCode);
            await _factory.WithDbAsync(async db => Assert.Equal(Reason, (await db.Users.SingleAsync(u => u.Id == target.Id)).SuspendedReason));
        }

        // ---------------- T-DEL: KI-39 ----------------

        [Fact]
        public async Task T_DEL_01_deleting_a_user_with_sessions_and_refresh_tokens_succeeds()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();
            // A web session with a rotated refresh-token chain (self-referencing rows) as well.
            var web = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = target.Email, password = Password, userType = "Customer" }));
            var rotated = await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: CookieClient.CookieValue(web)));
            Assert.Equal(HttpStatusCode.OK, rotated.StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.True(await db.AuthSessions.CountAsync(s => s.UserId == target.Id) >= 2);
                Assert.True(await db.RefreshTokens.CountAsync(t => t.ParentTokenId != null) >= 1);
            });

            var response = await Send(HttpMethod.Delete, $"/api/Admin/users/{target.Id}", admin.Token);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal("User deleted successfully", await Message(response));
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", target.Token)).StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.False(await db.Users.AnyAsync(u => u.Id == target.Id));
                Assert.False(await db.AuthSessions.AnyAsync(s => s.UserId == target.Id));
                // Security events stay (no FK): the login history and the deletion itself.
                var types = await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == target.Id).Select(e => e.EventType).ToListAsync();
                Assert.Contains("Auth.LoginSucceeded", types);
                Assert.Contains("Admin.UserDeleted", types);
            });
        }

        [Fact]
        public async Task T_DEL_02_since_M2_7a_a_delete_without_a_token_is_refused_and_deletes_nothing()
        {
            // The tokenless (development fallback) case, audited without an actor, is T-7A-03c.
            var target = await CustomerAsync();

            var response = await Send(HttpMethod.Delete, $"/api/Admin/users/{target.Id}", null);

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Empty(await EventsFor(target.Id, "Admin.UserDeleted"));
            await _factory.WithDbAsync(async db => Assert.True(await db.Users.AnyAsync(u => u.Id == target.Id)));
        }

        [Fact]
        public async Task T_DEL_03_deleting_an_admin_stays_forbidden_and_is_audited()
        {
            var admin = await AdminAsync();
            var other = await AdminAsync();

            var response = await Send(HttpMethod.Delete, $"/api/Admin/users/{other.Id}", admin.Token);

            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            var evt = Assert.Single(await EventsFor(other.Id, "Admin.UserDeleted"));
            Assert.Equal(SecurityEventOutcome.Blocked, evt.Outcome);
            Assert.Equal(admin.Id, evt.ActorUserId);
        }

        // ---------------- T-AU: audit ----------------

        [Fact]
        public async Task T_AU_01_every_admin_action_records_actor_target_and_outcome()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();

            await Suspend(target.Id, admin.Token);
            await Unsuspend(target.Id, admin.Token);
            await Suspend(admin.Id, admin.Token);
            await Send(HttpMethod.Delete, $"/api/Admin/users/{target.Id}", admin.Token);

            var suspended = Assert.Single(await EventsFor(target.Id, "Admin.UserSuspended"));
            var unsuspended = Assert.Single(await EventsFor(target.Id, "Admin.UserUnsuspended"));
            var deleted = Assert.Single(await EventsFor(target.Id, "Admin.UserDeleted"));
            var self = Assert.Single(await EventsFor(admin.Id, "Admin.UserSuspended"));

            foreach (var evt in new[] { suspended, unsuspended, deleted })
            {
                Assert.Equal(admin.Id, evt.ActorUserId);
                Assert.Equal("User", evt.TargetType);
                Assert.Equal(target.Id.ToString(), evt.TargetId);
                Assert.Equal(SecurityEventOutcome.Success, evt.Outcome);
                Assert.Null(evt.IpPrefix);
            }

            Assert.Contains("\"sessionsEnded\":1", suspended.Details);
            Assert.Equal(SecurityEventOutcome.Blocked, self.Outcome);
            Assert.Contains("Self", self.Details);
        }

        [Fact]
        public async Task T_AU_02_audit_rows_hold_no_reason_text_password_or_token()
        {
            var admin = await AdminAsync();
            var target = await CustomerAsync();

            await Suspend(target.Id, admin.Token);

            await _factory.WithDbAsync(async db =>
            {
                var rows = await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == target.Id || e.ActorUserId == admin.Id).ToListAsync();
                var text = JsonSerializer.Serialize(rows);
                foreach (var secret in new[] { Reason, Password, AdminPassword, target.Token, admin.Token, target.Email, admin.Email })
                {
                    Assert.DoesNotContain(secret, text);
                }
            });
        }
    }
}
