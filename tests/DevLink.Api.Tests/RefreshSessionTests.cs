using System.Net;
using System.Security.Cryptography;
using System.Text;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // T-LG-09…11 (refresh token at login), T-RT-01…05, 09, 11…13 (rotation, reuse, logout), T-MT-06, T-SP-03.
    public class RefreshSessionTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public RefreshSessionTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        internal sealed record WebLogin(int UserId, string Email, string AccessToken, string Cookie);

        private async Task<string> NewAccountAsync(string userType = "Customer")
        {
            var email = ApiTestHelpers.UniqueEmail("refresh");
            await ApiTestHelpers.RegisterAsync(_factory.CreateClient(), _factory.Emails, email, "Secret123", userType);
            return email;
        }

        private async Task<WebLogin> LoginWebAsync(string? email = null, string userType = "Customer")
        {
            email ??= await NewAccountAsync(userType);
            var response = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType }));
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await CookieClient.Json(response);
            return new WebLogin(body.GetProperty("userId").GetInt32(), email, body.GetProperty("accessToken").GetString()!,
                CookieClient.CookieValue(response) ?? throw new Xunit.Sdk.XunitException("no refresh cookie"));
        }

        private Task<HttpResponseMessage> Refresh(string cookie) =>
            _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie));

        private Task<HttpResponseMessage> Me(string accessToken) =>
            SessionApiFactory.GetWithToken(_client, "/api/Auth/me", accessToken);

        private static byte[] Hash(string raw) => SHA256.HashData(Encoding.ASCII.GetBytes(raw));

        private static int MaxAge(string setCookie) =>
            int.Parse(System.Text.RegularExpressions.Regex.Match(setCookie, @"max-age=(\d+)").Groups[1].Value);

        // ---------------- login ----------------

        [Fact]
        public async Task T_LG_09_web_login_sets_an_httponly_secure_strict_cookie_and_stores_only_its_hash()
        {
            var email = await NewAccountAsync();
            var response = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }));

            var line = CookieClient.SetCookieLine(response)!;
            Assert.NotNull(line);
            var flags = line.ToLowerInvariant();
            Assert.Contains("httponly", flags);
            Assert.Contains("secure", flags);
            Assert.Contains("samesite=strict", flags);
            Assert.Contains("path=/api/auth/session", flags);
            Assert.InRange(MaxAge(flags), 604_790, 604_800); // 7-day idle lifetime
            Assert.DoesNotContain("domain=", flags);

            var body = await CookieClient.Json(response);
            Assert.Equal(System.Text.Json.JsonValueKind.Null, body.GetProperty("refreshToken").ValueKind); // never in the body for web
            Assert.Equal(System.Text.Json.JsonValueKind.String, body.GetProperty("refreshTokenExpiresAt").ValueKind);

            var cookie = CookieClient.CookieValue(response)!;
            Assert.Equal(32, Microsoft.IdentityModel.Tokens.Base64UrlEncoder.DecodeBytes(cookie).Length); // 256 bits
            await _factory.WithDbAsync(async db =>
            {
                var row = await db.RefreshTokens.AsNoTracking().SingleAsync(t => t.TokenHash == Hash(cookie));
                Assert.Equal(RefreshTokenStatus.Active, row.Status);
                Assert.Null(row.ParentTokenId);
            });
        }

        [Fact]
        public async Task T_LG_10_mobile_login_returns_the_token_in_the_body_and_legacy_login_gets_none()
        {
            var email = await NewAccountAsync();

            var mobile = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }, client: "mobile", origin: null));
            Assert.Equal(HttpStatusCode.OK, mobile.StatusCode);
            Assert.Null(CookieClient.SetCookieLine(mobile));
            var mobileToken = (await CookieClient.Json(mobile)).GetProperty("refreshToken").GetString();
            Assert.False(string.IsNullOrEmpty(mobileToken));

            // Mobile refresh: token in the body, new token in the body, no cookie.
            var refreshed = await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", new { refreshToken = mobileToken }, client: "mobile", origin: null));
            Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
            Assert.Null(CookieClient.SetCookieLine(refreshed));
            Assert.NotEqual(mobileToken, (await CookieClient.Json(refreshed)).GetProperty("refreshToken").GetString());

            // No client header (today's Flutter app): no cookie, no token, no refresh-token row — as in M2.4a.
            var legacy = await SessionApiFactory.LoginAsync(_factory.CreateClient(), email, "Secret123", "Customer");
            Assert.Equal(HttpStatusCode.OK, legacy.StatusCode);
            Assert.Null(CookieClient.SetCookieLine(legacy));
            var legacyBody = await CookieClient.Json(legacy);
            Assert.Equal(System.Text.Json.JsonValueKind.Null, legacyBody.GetProperty("refreshToken").ValueKind);
            var sid = new Microsoft.IdentityModel.JsonWebTokens.JsonWebToken(legacyBody.GetProperty("accessToken").GetString()).GetPayloadValue<string>("sid");
            await _factory.WithDbAsync(async db =>
                Assert.False(await db.RefreshTokens.AnyAsync(t => t.SessionId == Guid.Parse(sid))));
        }

        [Fact]
        public async Task T_LG_11_admin_refresh_tokens_live_8_hours_idle_within_24_hours()
        {
            var adminEmail = ApiTestHelpers.UniqueEmail("admin-rt");
            await _factory.WithDbAsync(async db =>
            {
                var admin = new User { Email = adminEmail, UserType = "Admin", PasswordHash = "" };
                admin.PasswordHash = new Services.PasswordService(new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build()).Hash(admin, "Secret123");
                db.Users.Add(admin);
                await db.SaveChangesAsync();
            });

            var response = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = adminEmail, password = "Secret123", userType = "Admin" }));
            Assert.InRange(MaxAge(CookieClient.SetCookieLine(response)!.ToLowerInvariant()), 28_790, 28_800);

            var cookie = CookieClient.CookieValue(response)!;
            await _factory.WithDbAsync(async db =>
            {
                var token = await db.RefreshTokens.AsNoTracking().SingleAsync(t => t.TokenHash == Hash(cookie));
                var session = await db.AuthSessions.AsNoTracking().SingleAsync(s => s.Id == token.SessionId);
                Assert.Equal(TimeSpan.FromHours(8), token.ExpiresAt - token.CreatedAt);
                Assert.Equal(TimeSpan.FromHours(24), session.AbsoluteExpiresAt - session.CreatedAt);
            });
        }

        // ---------------- rotation ----------------

        [Fact]
        public async Task T_RT_01_unknown_idle_expired_and_absolute_expired_tokens_are_refused()
        {
            var unknown = await Refresh(Microsoft.IdentityModel.Tokens.Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(32)));
            Assert.Equal(HttpStatusCode.Unauthorized, unknown.StatusCode);
            Assert.Equal("SESSION_EXPIRED", await CookieClient.ErrorCode(unknown));
            Assert.True(CookieClient.DeletesCookie(unknown));

            var absolute = await LoginWebAsync();
            await _factory.WithDbAsync(async db => await db.AuthSessions.Where(s => s.UserId == absolute.UserId)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.AbsoluteExpiresAt, DateTime.UtcNow.AddMinutes(-1))));
            Assert.Equal("SESSION_EXPIRED", await CookieClient.ErrorCode(await Refresh(absolute.Cookie)));

            var idle = await LoginWebAsync();
            _factory.Time.Advance(TimeSpan.FromDays(7) + TimeSpan.FromMinutes(1));
            try
            {
                Assert.Equal("SESSION_EXPIRED", await CookieClient.ErrorCode(await Refresh(idle.Cookie)));
            }
            finally
            {
                _factory.Time.Advance(-(TimeSpan.FromDays(7) + TimeSpan.FromMinutes(1)));
            }

            await _factory.WithDbAsync(async db =>
            {
                Assert.All(await db.AuthSessions.AsNoTracking().Where(s => s.UserId == absolute.UserId || s.UserId == idle.UserId).ToListAsync(),
                    s => Assert.Equal(AuthSessionStatus.Expired, s.Status));
            });
        }

        [Fact]
        public async Task T_RT_02_rotation_keeps_the_old_row_and_links_old_and_new()
        {
            var login = await LoginWebAsync();
            var response = await Refresh(login.Cookie);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var next = CookieClient.CookieValue(response)!;
            Assert.NotEqual(login.Cookie, next);
            Assert.Equal(HttpStatusCode.OK, (await Me((await CookieClient.Json(response)).GetProperty("accessToken").GetString()!)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var old = await db.RefreshTokens.AsNoTracking().SingleAsync(t => t.TokenHash == Hash(login.Cookie));
                var successor = await db.RefreshTokens.AsNoTracking().SingleAsync(t => t.TokenHash == Hash(next));
                Assert.Equal(RefreshTokenStatus.Rotated, old.Status);
                Assert.NotNull(old.ConsumedAt);
                Assert.Equal(successor.Id, old.ReplacedByTokenId);
                Assert.Equal(old.Id, successor.ParentTokenId);
                Assert.Equal(old.SessionId, successor.SessionId);
                Assert.Equal(RefreshTokenStatus.Active, successor.Status);
                Assert.Equal(2, await db.RefreshTokens.CountAsync(t => t.SessionId == old.SessionId));
            });
        }

        [Fact]
        public async Task T_RT_03_replaying_a_rotated_token_revokes_the_whole_session_family()
        {
            var login = await LoginWebAsync();
            var rotated = await Refresh(login.Cookie);
            var newAccess = (await CookieClient.Json(rotated)).GetProperty("accessToken").GetString()!;
            Assert.Equal(HttpStatusCode.OK, (await Me(newAccess)).StatusCode);

            var replay = await Refresh(login.Cookie);

            Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(replay));
            Assert.True(CookieClient.DeletesCookie(replay));

            // The current access token of that session is rejected immediately (cache cleared).
            var me = await Me(newAccess);
            Assert.Equal(HttpStatusCode.Unauthorized, me.StatusCode);
            Assert.Equal("SESSION_REVOKED", await SessionApiFactory.ErrorCode(me));

            // ...and so is the successor refresh token.
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await Refresh(CookieClient.CookieValue(rotated)!)));

            await _factory.WithDbAsync(async db =>
            {
                var session = await db.AuthSessions.AsNoTracking().SingleAsync(s => s.UserId == login.UserId);
                Assert.Equal(AuthSessionStatus.Revoked, session.Status);
                Assert.Equal("ReuseDetected", session.RevokeReason);
                Assert.False(await db.RefreshTokens.AnyAsync(t => t.SessionId == session.Id && t.Status == RefreshTokenStatus.Active));
                var evt = await db.SecurityEvents.AsNoTracking().SingleAsync(e => e.UserId == login.UserId && e.EventType == "Auth.RefreshTokenReuse");
                Assert.Equal(session.Id, evt.SessionId);
                Assert.Equal(SessionApiFactory.ClientIpPrefix, evt.IpPrefix);
                Assert.DoesNotContain(login.Cookie, evt.Details ?? "");
            });
        }

        [Fact]
        public async Task T_RT_04_replaying_an_older_token_in_the_chain_also_kills_the_newest()
        {
            var login = await LoginWebAsync();
            var rt1 = CookieClient.CookieValue(await Refresh(login.Cookie))!;
            var rt2 = CookieClient.CookieValue(await Refresh(rt1))!;

            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await Refresh(login.Cookie)));
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await Refresh(rt2)));
        }

        [Fact]
        public async Task T_RT_05_reuse_affects_only_that_session_and_does_not_rotate_the_stamp()
        {
            var email = await NewAccountAsync();
            var first = await LoginWebAsync(email);
            var second = await LoginWebAsync(email);
            string stampBefore = "";
            await _factory.WithDbAsync(async db => stampBefore = (await db.Users.SingleAsync(u => u.Id == first.UserId)).SecurityStamp);

            await Refresh(first.Cookie);
            await Refresh(first.Cookie); // reuse in session 1

            var secondRefresh = await Refresh(second.Cookie);
            Assert.Equal(HttpStatusCode.OK, secondRefresh.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Me(second.AccessToken)).StatusCode);
            await _factory.WithDbAsync(async db =>
                Assert.Equal(stampBefore, (await db.Users.SingleAsync(u => u.Id == first.UserId)).SecurityStamp));
        }

        [Fact]
        public async Task T_RT_09_a_token_of_an_ended_session_is_refused_without_a_reuse_alarm()
        {
            var login = await LoginWebAsync();
            Assert.Equal(HttpStatusCode.NoContent, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/logout", cookie: login.Cookie))).StatusCode);

            var again = await Refresh(login.Cookie);

            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(again));
            await _factory.WithDbAsync(async db =>
            {
                var types = await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == login.UserId).Select(e => e.EventType).ToListAsync();
                Assert.DoesNotContain("Auth.RefreshTokenReuse", types);
                Assert.Contains("Auth.EndedSessionTokenPresented", types);
                Assert.Contains("Auth.Logout", types);
            });
        }

        [Fact]
        public async Task T_RT_11_logout_ends_the_current_session_and_deletes_the_cookie()
        {
            var login = await LoginWebAsync();

            var logout = await _client.SendAsync(CookieClient.Post("/api/Auth/session/logout", cookie: login.Cookie));

            Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
            Assert.True(CookieClient.DeletesCookie(logout));
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await Refresh(login.Cookie)));
            Assert.Equal(HttpStatusCode.Unauthorized, (await Me(login.AccessToken)).StatusCode);

            // Without a client header, logout needs the Bearer token (today's app); otherwise it is refused.
            var legacy = await LoginWebAsync();
            Assert.Equal(HttpStatusCode.NoContent, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/logout", client: null, origin: null, bearer: legacy.AccessToken))).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await Me(legacy.AccessToken)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/logout", client: null, origin: null))).StatusCode);
        }

        [Fact]
        public async Task T_RT_12_logout_everywhere_ends_every_session_and_rotates_the_stamp()
        {
            var email = await NewAccountAsync();
            var a = await LoginWebAsync(email);
            var b = await LoginWebAsync(email);
            string stampBefore = "";
            await _factory.WithDbAsync(async db => stampBefore = (await db.Users.SingleAsync(u => u.Id == a.UserId)).SecurityStamp);

            var all = await _client.SendAsync(CookieClient.Post("/api/Auth/logout-all", bearer: a.AccessToken));

            Assert.Equal(HttpStatusCode.NoContent, all.StatusCode);
            Assert.True(CookieClient.DeletesCookie(all));
            foreach (var s in new[] { a, b })
            {
                Assert.Equal(HttpStatusCode.Unauthorized, (await Me(s.AccessToken)).StatusCode);
                Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await Refresh(s.Cookie)));
            }

            await _factory.WithDbAsync(async db =>
            {
                Assert.NotEqual(stampBefore, (await db.Users.SingleAsync(u => u.Id == a.UserId)).SecurityStamp);
                Assert.False(await db.AuthSessions.AnyAsync(s => s.UserId == a.UserId && s.Status == AuthSessionStatus.Active));
                Assert.Contains(await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == a.UserId).Select(e => e.EventType).ToListAsync(), t => t == "Auth.LogoutAll");
            });

            Assert.Equal(HttpStatusCode.Unauthorized, (await _client.SendAsync(CookieClient.Post("/api/Auth/logout-all"))).StatusCode); // needs a Bearer token
        }

        [Fact]
        public async Task T_RT_13_rotation_slides_the_idle_lifetime_but_never_past_the_absolute_limit()
        {
            var login = await LoginWebAsync();
            await _factory.WithDbAsync(async db => await db.AuthSessions.Where(s => s.UserId == login.UserId)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.AbsoluteExpiresAt, DateTime.UtcNow.AddDays(2))));

            var next = CookieClient.CookieValue(await Refresh(login.Cookie))!;

            await _factory.WithDbAsync(async db =>
            {
                var token = await db.RefreshTokens.AsNoTracking().SingleAsync(t => t.TokenHash == Hash(next));
                var session = await db.AuthSessions.AsNoTracking().SingleAsync(s => s.Id == token.SessionId);
                Assert.Equal(session.AbsoluteExpiresAt, token.ExpiresAt); // capped at 2 days, not 7
            });
        }

        [Fact]
        public async Task T_MT_06_two_tabs_sharing_one_cookie_refresh_one_after_the_other_without_reuse()
        {
            var login = await LoginWebAsync();

            // Tab A refreshes; the shared cookie jar now holds RT1; tab B then refreshes with RT1.
            var tabA = await Refresh(login.Cookie);
            var tabB = await Refresh(CookieClient.CookieValue(tabA)!);

            Assert.Equal(HttpStatusCode.OK, tabA.StatusCode);
            Assert.Equal(HttpStatusCode.OK, tabB.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Me((await CookieClient.Json(tabA)).GetProperty("accessToken").GetString()!)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Me((await CookieClient.Json(tabB)).GetProperty("accessToken").GetString()!)).StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                var sessionId = (await db.AuthSessions.SingleAsync(s => s.UserId == login.UserId)).Id;
                Assert.Equal(1, await db.RefreshTokens.CountAsync(t => t.SessionId == sessionId && t.Status == RefreshTokenStatus.Active));
                Assert.False(await db.SecurityEvents.AnyAsync(e => e.UserId == login.UserId && e.EventType == "Auth.RefreshTokenReuse"));
            });
        }

        [Fact]
        public async Task T_LOG_03_refresh_tokens_never_appear_in_logs_or_security_events()
        {
            var login = await LoginWebAsync();
            var rotated = await Refresh(login.Cookie);
            var next = CookieClient.CookieValue(rotated)!;
            await Refresh(login.Cookie); // reuse → audit event + warning log

            var logs = _factory.Logs.AllText;
            Assert.Contains("Auth.RefreshTokenReuse", logs);
            await _factory.WithDbAsync(async db =>
            {
                var events = string.Join("|", (await db.SecurityEvents.AsNoTracking().ToListAsync())
                    .Select(e => $"{e.TargetId}{e.Details}{e.TraceId}{e.EmailKey}{e.IpPrefix}"));
                foreach (var secret in new[] { login.Cookie, next, login.AccessToken })
                {
                    Assert.DoesNotContain(secret, logs);
                    Assert.DoesNotContain(secret, events);
                }
            });
        }

        [Fact]
        public async Task T_SP_03_suspended_accounts_can_refresh_into_restricted_mode()
        {
            var login = await LoginWebAsync();
            await _factory.WithDbAsync(async db => await db.Users.Where(u => u.Id == login.UserId)
                .ExecuteUpdateAsync(s => s.SetProperty(u => u.Status, UserStatus.Suspended)));

            var response = await Refresh(login.Cookie);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal("Suspended", (await CookieClient.Json(response)).GetProperty("status").GetString());
        }
    }
}
