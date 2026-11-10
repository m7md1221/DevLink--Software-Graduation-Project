using System.Net;
using System.Net.Http.Json;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Services;
using Services.Files;

namespace DevLink.Api.Tests
{
    // Google's keys replaced by a key the tests hold, so the real validator checks real signatures.
    public sealed class TestGoogleKeys : IGoogleSigningKeys
    {
        public RsaSecurityKey Key { get; } = new(RSA.Create(2048)) { KeyId = "test-google-key" };

        public int Refreshes { get; private set; }

        public bool Fail { get; set; }

        public Task<IReadOnlyCollection<SecurityKey>> GetAsync(bool refresh, CancellationToken cancellationToken)
        {
            if (Fail) throw new HttpRequestException("keys unavailable");
            if (refresh) Refreshes++;
            return Task.FromResult<IReadOnlyCollection<SecurityKey>>(new[] { Key });
        }
    }

    public sealed record GoogleToken
    {
        public const string ClientId = "test-client-id.apps.googleusercontent.com";

        public string Subject { get; init; } = "google-" + Guid.NewGuid().ToString("N");
        public string Email { get; init; } = ApiTestHelpers.UniqueEmail("google");
        public object? EmailVerified { get; init; } = true;
        public string Audience { get; init; } = ClientId;
        public string Issuer { get; init; } = "https://accounts.google.com";
        public DateTime IssuedAt { get; init; } = DateTime.UtcNow;
        public TimeSpan Lifetime { get; init; } = TimeSpan.FromHours(1);
        public SecurityKey? SigningKey { get; init; }
        public string Algorithm { get; init; } = SecurityAlgorithms.RsaSha256;

        public string Mint(SecurityKey key)
        {
            var claims = new Dictionary<string, object> { ["sub"] = Subject, ["email"] = Email };
            if (EmailVerified != null) claims["email_verified"] = EmailVerified;

            return new JsonWebTokenHandler { SetDefaultTimesOnTokenCreation = false }.CreateToken(new SecurityTokenDescriptor
            {
                Issuer = Issuer,
                Audience = Audience,
                IssuedAt = IssuedAt,
                NotBefore = IssuedAt,
                Expires = IssuedAt + Lifetime,
                Claims = claims,
                SigningCredentials = new SigningCredentials(SigningKey ?? key, Algorithm)
            });
        }
    }

    public class GoogleApiFactory : SessionApiFactory
    {
        public TestGoogleKeys GoogleKeys { get; } = new();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IGoogleSigningKeys>();
                services.AddSingleton<IGoogleSigningKeys>(GoogleKeys);
            });
        }
    }

    // ============================================================
    // T-GG-01…14: Google sign-in and linking (M2_AUTH_DESIGN §6.3, Q11, Q13).
    // ============================================================
    public class GoogleSignInTests : IClassFixture<GoogleApiFactory>
    {
        private const string Password = "Matrix-Pass-42";

        private readonly GoogleApiFactory _factory;
        private readonly HttpClient _client;

        public GoogleSignInTests(GoogleApiFactory factory)
        {
            factory.Time.Reset();
            factory.GoogleKeys.Fail = false;
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private string Mint(GoogleToken token) => token.Mint(_factory.GoogleKeys.Key);

        private Task<HttpResponseMessage> GoogleLoginAsync(string idToken, string userType = "Customer", string mode = "signup", string? client = null) =>
            _client.SendAsync(CookieClient.Post("/api/Auth/google-login", new { idToken, userType, mode }, client: client, origin: client == null ? null : TestSecuritySettings.Origin));

        private Task<HttpResponseMessage> LinkAsync(string? bearer, string idToken, string currentPassword) =>
            _client.SendAsync(CookieClient.Post("/api/Auth/google-link", new { idToken, currentPassword }, client: null, origin: null, bearer: bearer));

        private async Task<User?> UserByEmailAsync(string email)
        {
            User? user = null;
            await _factory.WithDbAsync(async db => user = await db.Users.AsNoTracking().SingleOrDefaultAsync(u => u.Email == email));
            return user;
        }

        private async Task<int> SessionCountAsync(int userId)
        {
            var count = 0;
            await _factory.WithDbAsync(async db => count = await db.AuthSessions.CountAsync(s => s.UserId == userId));
            return count;
        }

        [Fact]
        public async Task T_GG_01_a_valid_token_for_a_new_email_creates_an_account_holding_the_subject_and_a_session()
        {
            var google = new GoogleToken();

            var response = await GoogleLoginAsync(Mint(google), "Programmer");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await CookieClient.Json(response);
            Assert.True(body.GetProperty("isNewUser").GetBoolean());
            Assert.Equal("Programmer", body.GetProperty("userType").GetString());
            foreach (var key in new[] { "userId", "email", "hasProfile", "hasProgrammerProfile", "accessToken", "role", "status" })
            {
                Assert.True(body.TryGetProperty(key, out _), key);
            }

            var user = await UserByEmailAsync(google.Email);
            Assert.Equal(google.Subject, user!.GoogleSubject);
            Assert.Equal(1, await SessionCountAsync(user.Id));

            var me = await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", body.GetProperty("accessToken").GetString());
            Assert.Equal(HttpStatusCode.OK, me.StatusCode);
        }

        public static IEnumerable<object[]> BadTokens => new[]
        {
            new object[] { "wrong audience", new GoogleToken { Audience = "someone-else.apps.googleusercontent.com" } },
            new object[] { "wrong issuer", new GoogleToken { Issuer = "https://evil.example" } },
            new object[] { "expired", new GoogleToken { IssuedAt = DateTime.UtcNow.AddHours(-3) } },
            new object[] { "not yet valid", new GoogleToken { IssuedAt = DateTime.UtcNow.AddHours(2) } },
            new object[] { "email not verified", new GoogleToken { EmailVerified = false } },
            new object[] { "email_verified missing", new GoogleToken { EmailVerified = null } },
            new object[] { "email_verified as text false", new GoogleToken { EmailVerified = "false" } },
            new object[] { "forged signature", new GoogleToken { SigningKey = new RsaSecurityKey(RSA.Create(2048)) { KeyId = "test-google-key" } } },
            new object[] { "unknown key", new GoogleToken { SigningKey = new RsaSecurityKey(RSA.Create(2048)) { KeyId = "attacker-key" } } },
            new object[] { "symmetric algorithm", new GoogleToken { SigningKey = new SymmetricSecurityKey(RandomNumberGenerator.GetBytes(64)) { KeyId = "test-google-key" }, Algorithm = SecurityAlgorithms.HmacSha256 } },
        };

        [Theory]
        [MemberData(nameof(BadTokens))]
        public async Task T_GG_02_invalid_tokens_are_refused_and_create_nothing(string why, GoogleToken google)
        {
            var response = await GoogleLoginAsync(Mint(google));

            Assert.True(response.StatusCode == HttpStatusCode.Unauthorized, why);
            Assert.Equal("INVALID_CREDENTIALS", await CookieClient.ErrorCode(response));
            Assert.Null(await UserByEmailAsync(google.Email));
        }

        [Theory]
        [InlineData("not-a-jwt")]
        [InlineData("a.b.c")]
        public async Task T_GG_02b_malformed_tokens_are_refused(string idToken)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GoogleLoginAsync(idToken)).StatusCode);
        }

        [Fact]
        public async Task T_GG_02c_an_unknown_key_triggers_one_refresh_of_googles_keys()
        {
            var before = _factory.GoogleKeys.Refreshes;
            var google = new GoogleToken { SigningKey = new RsaSecurityKey(RSA.Create(2048)) { KeyId = "rotated-key" } };

            Assert.Equal(HttpStatusCode.Unauthorized, (await GoogleLoginAsync(Mint(google))).StatusCode);
            Assert.Equal(before + 1, _factory.GoogleKeys.Refreshes);
        }

        [Fact]
        public async Task T_GG_02d_expiry_follows_the_server_clock()
        {
            var google = new GoogleToken { Lifetime = TimeSpan.FromMinutes(10) };
            var token = Mint(google);

            _factory.Time.Advance(TimeSpan.FromMinutes(12));
            Assert.Equal(HttpStatusCode.Unauthorized, (await GoogleLoginAsync(token)).StatusCode);

            _factory.Time.Reset();
            Assert.Equal(HttpStatusCode.OK, (await GoogleLoginAsync(token)).StatusCode);
        }

        [Fact]
        public async Task T_GG_03_a_known_subject_signs_in_to_that_account_even_if_the_google_email_changed()
        {
            var google = new GoogleToken();
            Assert.Equal(HttpStatusCode.OK, (await GoogleLoginAsync(Mint(google))).StatusCode);
            var user = await UserByEmailAsync(google.Email);

            var again = await GoogleLoginAsync(Mint(google with { Email = ApiTestHelpers.UniqueEmail("renamed") }), mode: "login");

            Assert.Equal(HttpStatusCode.OK, again.StatusCode);
            var body = await CookieClient.Json(again);
            Assert.False(body.GetProperty("isNewUser").GetBoolean());
            Assert.Equal(user!.Id, body.GetProperty("userId").GetInt32());
        }

        [Theory]
        [InlineData("signup")]
        [InlineData("login")]
        public async Task T_GG_04_an_email_that_already_has_a_password_account_is_never_linked_automatically(string mode)
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var before = await SessionCountAsync(account.Id);

            var response = await GoogleLoginAsync(Mint(new GoogleToken { Email = account.Email.ToUpperInvariant() }), mode: mode, client: "web");

            Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
            Assert.Equal("ACCOUNT_LINK_REQUIRED", await CookieClient.ErrorCode(response));
            Assert.Contains("Sign in with your password, then connect Google", (await CookieClient.Json(response)).GetProperty("message").GetString());
            Assert.False(response.Headers.Contains("Set-Cookie"));
            Assert.Null((await UserByEmailAsync(account.Email))!.GoogleSubject);
            Assert.Equal(before, await SessionCountAsync(account.Id));
        }

        [Fact]
        public async Task T_GG_05_a_new_email_from_the_sign_in_screen_must_sign_up_first()
        {
            var google = new GoogleToken();

            var response = await GoogleLoginAsync(Mint(google), mode: "login");

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.True((await CookieClient.Json(response)).GetProperty("requiresSignUp").GetBoolean());
            Assert.Null(await UserByEmailAsync(google.Email));
        }

        [Fact]
        public async Task T_GG_06_admins_can_never_use_google()
        {
            var admin = await AdminRoutes.AccountAsync(_factory, _client, "Admin");
            var google = new GoogleToken { Email = admin.Email };

            // Linking is refused.
            var link = await LinkAsync(admin.Token, Mint(google), Password);
            Assert.Equal(HttpStatusCode.Forbidden, link.StatusCode);
            Assert.Null((await UserByEmailAsync(admin.Email))!.GoogleSubject);

            // Even with a subject stored by hand, sign-in is refused; the admin portal isn't accepted at all.
            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == admin.Id)).GoogleSubject = google.Subject;
                await db.SaveChangesAsync();
            });
            var before = await SessionCountAsync(admin.Id);
            var signIn = await GoogleLoginAsync(Mint(google), "Customer", "login");
            Assert.Equal(HttpStatusCode.Forbidden, signIn.StatusCode);
            Assert.Equal(before, await SessionCountAsync(admin.Id));
            Assert.Equal(HttpStatusCode.BadRequest, (await GoogleLoginAsync(Mint(google), "Admin", "login")).StatusCode);
        }

        [Fact]
        public async Task T_GG_07_linking_connects_google_rotates_the_stamp_and_ends_other_sessions()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var other = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_client, account.Email, Password, "Customer"));
            var google = new GoogleToken { Email = account.Email };

            var link = await LinkAsync(account.Token, Mint(google), Password);

            Assert.Equal(HttpStatusCode.OK, link.StatusCode);
            var fresh = (await CookieClient.Json(link)).GetProperty("accessToken").GetString();
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", fresh)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", account.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, "/api/Auth/me", other)).StatusCode);
            Assert.Equal(google.Subject, (await UserByEmailAsync(account.Email))!.GoogleSubject);

            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal(1, await db.AuthSessions.CountAsync(s => s.UserId == account.Id && s.Status == AuthSessionStatus.Active));
                Assert.Contains(await db.AuthSessions.Where(s => s.UserId == account.Id).Select(s => s.RevokeReason).ToListAsync(), r => r == "GoogleLinked");
                Assert.True(await db.SecurityEvents.AnyAsync(e => e.UserId == account.Id && e.EventType == "Auth.GoogleLinked" && e.Outcome == "Success"));
            });

            // Google now signs in to the same account.
            var signIn = await GoogleLoginAsync(Mint(google), mode: "login");
            Assert.Equal(account.Id, (await CookieClient.Json(signIn)).GetProperty("userId").GetInt32());

            // Linking the same Google account again is harmless.
            Assert.Equal(HttpStatusCode.OK, (await LinkAsync(fresh, Mint(google), Password)).StatusCode);

            await WaitForEmailAsync(account.Email);
        }

        private async Task WaitForEmailAsync(string email)
        {
            for (var i = 0; i < 50 && !_factory.Emails.To(email).Any(); i++)
            {
                await Task.Delay(100);
            }

            Assert.Contains(_factory.Emails.To(email), m => m.Subject.Contains("Google sign-in was connected"));
        }

        [Fact]
        public async Task T_GG_08_linking_needs_the_password_the_same_email_and_a_free_subject()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Programmer");
            var owner = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var taken = new GoogleToken { Email = owner.Email };
            Assert.Equal(HttpStatusCode.OK, (await LinkAsync(owner.Token, Mint(taken), Password)).StatusCode);

            var wrongPassword = await LinkAsync(account.Token, Mint(new GoogleToken { Email = account.Email }), "Not-The-Password-1");
            Assert.Equal(HttpStatusCode.BadRequest, wrongPassword.StatusCode);
            Assert.Equal("INVALID_CREDENTIALS", await CookieClient.ErrorCode(wrongPassword));
            Assert.Equal(1, (await UserByEmailAsync(account.Email))!.FailedLoginCount);

            var mismatch = await LinkAsync(account.Token, Mint(new GoogleToken()), Password);
            Assert.Equal(HttpStatusCode.Conflict, mismatch.StatusCode);
            Assert.Equal("GOOGLE_EMAIL_MISMATCH", await CookieClient.ErrorCode(mismatch));

            var duplicate = await LinkAsync(account.Token, Mint(taken with { Email = account.Email }), Password);
            Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
            Assert.Equal("GOOGLE_ALREADY_LINKED", await CookieClient.ErrorCode(duplicate));

            var unverified = await LinkAsync(account.Token, Mint(new GoogleToken { Email = account.Email, EmailVerified = false }), Password);
            Assert.Equal(HttpStatusCode.BadRequest, unverified.StatusCode);
            Assert.Equal("GOOGLE_TOKEN_INVALID", await CookieClient.ErrorCode(unverified));

            Assert.Null((await UserByEmailAsync(account.Email))!.GoogleSubject);
            Assert.Equal(HttpStatusCode.Unauthorized, (await LinkAsync(null, Mint(new GoogleToken { Email = account.Email }), Password)).StatusCode);

            // An account already holding another Google subject can't take a second one.
            var mine = new GoogleToken { Email = account.Email };
            var linked = await LinkAsync(account.Token, Mint(mine), Password);
            var token = (await CookieClient.Json(linked)).GetProperty("accessToken").GetString();
            var second = await LinkAsync(token, Mint(new GoogleToken { Email = account.Email }), Password);
            Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
            Assert.Equal(mine.Subject, (await UserByEmailAsync(account.Email))!.GoogleSubject);
        }

        [Fact]
        public async Task T_GG_09_the_wrong_portal_is_refused()
        {
            var google = new GoogleToken();
            Assert.Equal(HttpStatusCode.OK, (await GoogleLoginAsync(Mint(google), "Customer")).StatusCode);

            var response = await GoogleLoginAsync(Mint(google), "Programmer", "login");

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Equal("INVALID_CREDENTIALS", await CookieClient.ErrorCode(response));
        }

        [Fact]
        public async Task T_GG_10_web_and_mobile_get_the_same_session_as_a_password_login()
        {
            var web = await GoogleLoginAsync(Mint(new GoogleToken()), client: "web");
            Assert.Equal(HttpStatusCode.OK, web.StatusCode);
            var cookies = web.Headers.GetValues("Set-Cookie").ToList();
            Assert.Contains(cookies, c => c.StartsWith("devlink_rt=", StringComparison.Ordinal));
            Assert.Contains(cookies, c => c.StartsWith(DownloadBindingCookie.Name + "=", StringComparison.Ordinal));
            Assert.Equal(JsonValueKind.Null, (await CookieClient.Json(web)).GetProperty("refreshToken").ValueKind);

            var mobile = await GoogleLoginAsync(Mint(new GoogleToken()), client: "mobile");
            Assert.False(mobile.Headers.Contains("Set-Cookie"));
            Assert.False(string.IsNullOrEmpty((await CookieClient.Json(mobile)).GetProperty("refreshToken").GetString()));

            var legacy = await GoogleLoginAsync(Mint(new GoogleToken()));
            Assert.False(legacy.Headers.Contains("Set-Cookie"));
            Assert.Equal(JsonValueKind.Null, (await CookieClient.Json(legacy)).GetProperty("refreshTokenExpiresAt").ValueKind);
        }

        [Fact]
        public async Task T_GG_11_a_suspended_account_gets_a_restricted_session_and_a_locked_one_is_refused()
        {
            var google = new GoogleToken();
            var created = await CookieClient.Json(await GoogleLoginAsync(Mint(google)));
            var id = created.GetProperty("userId").GetInt32();

            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == id)).Status = UserStatus.Suspended;
                await db.SaveChangesAsync();
            });
            var suspended = await GoogleLoginAsync(Mint(google), mode: "login");
            Assert.Equal(HttpStatusCode.OK, suspended.StatusCode);
            Assert.Equal("Suspended", (await CookieClient.Json(suspended)).GetProperty("status").GetString());

            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.SingleAsync(u => u.Id == id);
                user.Status = UserStatus.Active;
                user.LockoutEndAt = DateTime.UtcNow.AddMinutes(10);
                await db.SaveChangesAsync();
            });
            var locked = await GoogleLoginAsync(Mint(google), mode: "login");
            Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
            Assert.Equal("ACCOUNT_LOCKED", await CookieClient.ErrorCode(locked));
        }

        [Fact]
        public async Task T_GG_12_tokens_are_never_logged_or_stored_and_events_are_written()
        {
            var good = new GoogleToken();
            var goodToken = Mint(good);
            var badToken = Mint(new GoogleToken { Audience = "other" });

            Assert.Equal(HttpStatusCode.OK, (await GoogleLoginAsync(goodToken)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await GoogleLoginAsync(badToken)).StatusCode);

            foreach (var token in new[] { goodToken, badToken })
            {
                Assert.DoesNotContain(token, _factory.Logs.AllText);
                Assert.DoesNotContain(token.Split('.')[2], _factory.Logs.AllText);
            }

            await _factory.WithDbAsync(async db =>
            {
                var events = await db.SecurityEvents.AsNoTracking().Where(e => e.EventType.StartsWith("Auth.Google")).ToListAsync();
                Assert.Contains(events, e => e.Outcome == "Success");
                Assert.Contains(events, e => e.Outcome == "Failure" && (e.Details ?? "").Contains("WrongAudience"));
                Assert.All(events, e => Assert.DoesNotContain(goodToken.Split('.')[1], e.Details ?? ""));
                Assert.All(events, e => Assert.DoesNotContain(good.Email, (e.Details ?? "") + e.EmailKey));
            });
        }

        [Fact]
        public async Task T_GG_13_unreachable_google_keys_give_503_not_a_sign_in()
        {
            _factory.GoogleKeys.Fail = true;

            var response = await GoogleLoginAsync(Mint(new GoogleToken()));

            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            Assert.Equal("SERVICE_UNAVAILABLE", await CookieClient.ErrorCode(response));
        }

        [Fact]
        public void T_GG_14_both_google_routes_are_rate_limited_and_linking_needs_a_token()
        {
            var controller = typeof(Program).Assembly.GetTypes().Single(t => t.Name == "AuthController");
            foreach (var name in new[] { "GoogleLogin", "GoogleLink" })
            {
                Assert.NotNull(controller.GetMethod(name)!.GetCustomAttribute<EnableRateLimitingAttribute>());
            }

            Assert.Null(controller.GetMethod("GoogleLink")!.GetCustomAttribute<Microsoft.AspNetCore.Authorization.AllowAnonymousAttribute>());
        }
    }

    // The validator on its own: configuration and clock.
    public class GoogleTokenValidatorTests
    {
        private static GoogleTokenValidator Validator(Dictionary<string, string?> settings, TestGoogleKeys keys, TimeProvider? time = null) =>
            new(new GoogleOptions(new ConfigurationBuilder().AddInMemoryCollection(settings).Build()), keys, time ?? TimeProvider.System, NullLoggerFactory.Instance);

        [Fact]
        public async Task T_GG_15_without_a_client_id_google_is_not_configured()
        {
            var keys = new TestGoogleKeys();
            var result = await Validator(new() { ["Google:ClientId"] = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" }, keys)
                .ValidateAsync(new GoogleToken().Mint(keys.Key), CancellationToken.None);

            Assert.Equal(GoogleTokenOutcome.NotConfigured, result.Outcome);
        }

        [Fact]
        public async Task T_GG_16_any_of_several_client_ids_is_accepted()
        {
            var keys = new TestGoogleKeys();
            var validator = Validator(new() { ["Google:ClientIds:0"] = "web-id", ["Google:ClientIds:1"] = "android-id" }, keys);

            Assert.Equal(GoogleTokenOutcome.Valid, (await validator.ValidateAsync(new GoogleToken { Audience = "android-id" }.Mint(keys.Key), CancellationToken.None)).Outcome);
            Assert.Equal(GoogleTokenOutcome.Valid, (await validator.ValidateAsync(new GoogleToken { Audience = "web-id", Issuer = "accounts.google.com" }.Mint(keys.Key), CancellationToken.None)).Outcome);
            Assert.Equal(GoogleTokenOutcome.Invalid, (await validator.ValidateAsync(new GoogleToken { Audience = "ios-id" }.Mint(keys.Key), CancellationToken.None)).Outcome);
        }

        [Fact]
        public async Task T_GG_17_the_email_is_normalised_and_the_reason_names_no_secret()
        {
            var keys = new TestGoogleKeys();
            var validator = Validator(new() { ["Google:ClientId"] = GoogleToken.ClientId }, keys);

            var valid = await validator.ValidateAsync(new GoogleToken { Email = " Mixed.Case@Example.TEST " }.Mint(keys.Key), CancellationToken.None);
            Assert.Equal("mixed.case@example.test", valid.Identity!.Email);

            var expired = await validator.ValidateAsync(new GoogleToken { IssuedAt = DateTime.UtcNow.AddHours(-2) }.Mint(keys.Key), CancellationToken.None);
            Assert.Equal("Expired", expired.Reason);
        }
    }
}
