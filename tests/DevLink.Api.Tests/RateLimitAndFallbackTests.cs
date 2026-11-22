using System.Net;
using System.Net.Http.Json;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // ---------------- specialised hosts ----------------

    // Low per-IP request limits (the production defaults are higher; values only need to be reachable in a test).
    public class RateLimitApiFactory : SessionApiFactory
    {
        protected override IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?>
        {
            ["RateLimits:Login:PermitLimit"] = "3",
            ["RateLimits:CodeSend:PermitLimit"] = "2",
            ["RateLimits:CodeVerify:PermitLimit"] = "3",
            ["RateLimits:PasswordSet:PermitLimit"] = "2"
        };
    }

    // The production per-IP failure budget for code verification (20 per rolling hour, C6).
    public class IpFailureApiFactory : SessionApiFactory
    {
        protected override IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?>
        {
            ["Auth:CodeFailuresPerIpPerHour"] = "20"
        };
    }

    // Development + switch explicitly disabled + loopback client: the fallback is allowed (C1).
    public class DevFallbackApiFactory : SessionApiFactory
    {
        protected override string? Environment => "Development";
        protected override string RemoteIp => "127.0.0.1";
        protected override IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?> { ["Auth:EnforceAuthorization"] = "false" };
    }

    // Same, but the client is not on loopback: refused.
    public class DevFallbackRemoteApiFactory : DevFallbackApiFactory
    {
        protected override string RemoteIp => ClientIp;
    }

    // Development on loopback, but the switch is not set (the default): enforced.
    public class DevDefaultApiFactory : SessionApiFactory
    {
        protected override string? Environment => "Development";
        protected override string RemoteIp => "127.0.0.1";
    }

    // ---------------- T-RL-01…04: per-IP request limits ----------------

    public class RateLimitTests : IClassFixture<RateLimitApiFactory>
    {
        private readonly RateLimitApiFactory _factory;
        private readonly HttpClient _client;

        public RateLimitTests(RateLimitApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task AssertLimited(Func<Task<HttpResponseMessage>> call, int allowed)
        {
            for (var i = 0; i < allowed; i++)
            {
                Assert.NotEqual(HttpStatusCode.TooManyRequests, (await call()).StatusCode);
            }

            var limited = await call();
            Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
            Assert.Equal("RATE_LIMITED", await SessionApiFactory.ErrorCode(limited));
            Assert.InRange(int.Parse(limited.Headers.GetValues("Retry-After").Single()), 1, 3600);
        }

        [Fact]
        public async Task T_RL_01_login_is_limited_per_ip_and_audited()
        {
            await AssertLimited(() => SessionApiFactory.LoginAsync(_client, ApiTestHelpers.UniqueEmail("rl"), "Wrong-pass1", "Customer"), 3);

            await _factory.WithDbAsync(async db =>
                Assert.Contains(await db.SecurityEvents.AsNoTracking().Where(e => e.EventType == "Auth.RateLimited").ToListAsync(),
                    e => e.IpPrefix == SessionApiFactory.ClientIpPrefix && e.Details!.Contains("api/Auth/login")));
        }

        [Fact]
        public async Task T_RL_02_code_requests_are_limited_per_ip_across_emails()
        {
            await AssertLimited(() => _client.PostAsJsonAsync("/api/Auth/send-code", new { email = ApiTestHelpers.UniqueEmail("rl-send") }), 2);
        }

        [Fact]
        public async Task T_RL_03_code_verification_is_limited_per_ip()
        {
            await AssertLimited(() => _client.PostAsJsonAsync("/api/Auth/verify-reset-code", new { email = ApiTestHelpers.UniqueEmail("rl-verify"), code = "000000" }), 3);
        }

        [Fact]
        public async Task T_RL_04_signup_and_password_reset_are_limited_per_ip()
        {
            await AssertLimited(() => _client.PostAsJsonAsync("/api/Auth/reset-password", new { email = ApiTestHelpers.UniqueEmail("rl-reset"), newPassword = "Kq7#mzpw-ok" }), 2);
        }
    }

    // ---------------- T-CD-10: per-IP failure budget (C6) ----------------

    public class IpFailureBudgetTests : IClassFixture<IpFailureApiFactory>
    {
        private readonly IpFailureApiFactory _factory;

        public IpFailureBudgetTests(IpFailureApiFactory factory)
        {
            _factory = factory;
        }

        [Fact]
        public async Task T_CD_10_twenty_failures_from_one_ip_block_verification_for_every_email()
        {
            var client = _factory.CreateClient();
            for (var i = 0; i < 20; i++)
            {
                var r = await client.PostAsJsonAsync("/api/Auth/verify-code", new { email = ApiTestHelpers.UniqueEmail("ipfail"), code = "000000" });
                Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
            }

            var blocked = await client.PostAsJsonAsync("/api/Auth/verify-code", new { email = ApiTestHelpers.UniqueEmail("ipfail-new"), code = "000000" });
            Assert.Equal(HttpStatusCode.TooManyRequests, blocked.StatusCode);
            Assert.Equal("RATE_LIMITED", await SessionApiFactory.ErrorCode(blocked));

            _factory.Time.Advance(TimeSpan.FromMinutes(61));
            try
            {
                var later = await client.PostAsJsonAsync("/api/Auth/verify-code", new { email = ApiTestHelpers.UniqueEmail("ipfail-later"), code = "000000" });
                Assert.Equal(HttpStatusCode.BadRequest, later.StatusCode);
            }
            finally
            {
                _factory.Time.Advance(TimeSpan.FromMinutes(-61));
            }
        }
    }

    // ---------------- T-SW-07: development fallback for sign-up / reset without proof tokens (C1 case 2) ----------------

    public class DevFallbackTests : IClassFixture<DevFallbackApiFactory>
    {
        private readonly DevFallbackApiFactory _factory;
        private readonly HttpClient _client;

        public DevFallbackTests(DevFallbackApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        // Exactly the unchanged Flutter app's requests: the proof tokens are ignored.
        internal static async Task<HttpStatusCode> UnchangedAppSignupAsync(HttpClient client, CapturingEmailSender emails, string email, string password)
        {
            await ApiTestHelpers.VerifyEmailAsync(client, emails, email);
            return (await client.PostAsJsonAsync("/api/Auth/signup", new { email, password, userType = "Customer" })).StatusCode;
        }

        [Fact]
        public async Task T_SW_07_dev_fallback_lets_the_unchanged_app_sign_up_and_reset_and_logs_each_use()
        {
            var email = ApiTestHelpers.UniqueEmail("devflow");
            Assert.Equal(HttpStatusCode.OK, await UnchangedAppSignupAsync(_client, _factory.Emails, email, "Kq7#mzpw-ok"));

            await ApiTestHelpers.VerifyResetAsync(_client, _factory.Emails, email);
            var reset = await _client.PostAsJsonAsync("/api/Auth/reset-password", new { email, newPassword = "Brand-New-Pass-42" });
            Assert.Equal(HttpStatusCode.OK, reset.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, email, "Brand-New-Pass-42", "Customer")).StatusCode);

            var logs = _factory.Logs.Entries.Where(e => e.Message.Contains("Auth.DevFallbackUsed")).Select(e => e.Message).ToList();
            Assert.Contains(logs, m => m.Contains("SignupResetWithoutProof") && m.Contains("api/Auth/signup"));
            Assert.Contains(logs, m => m.Contains("SignupResetWithoutProof") && m.Contains("api/Auth/reset-password"));
            Assert.All(logs, m =>
            {
                Assert.DoesNotContain(email, m);
                Assert.DoesNotContain("Brand-New-Pass-42", m);
                Assert.DoesNotContain("127.0.0.1", m);
            });
        }

        [Fact]
        public async Task T_SW_07_dev_fallback_still_requires_a_verified_code()
        {
            var email = ApiTestHelpers.UniqueEmail("devflow-unverified");
            var signup = await _client.PostAsJsonAsync("/api/Auth/signup", new { email, password = "Kq7#mzpw-ok", userType = "Customer" });
            Assert.Equal("VERIFICATION_REQUIRED", await SessionApiFactory.ErrorCode(signup));
        }
    }

    public class DevFallbackRemoteTests : IClassFixture<DevFallbackRemoteApiFactory>
    {
        private readonly DevFallbackRemoteApiFactory _factory;

        public DevFallbackRemoteTests(DevFallbackRemoteApiFactory factory)
        {
            _factory = factory;
        }

        [Fact]
        public async Task T_SW_07_dev_fallback_is_refused_for_a_non_loopback_client()
        {
            var client = _factory.CreateClient();
            Assert.Equal(HttpStatusCode.BadRequest,
                await DevFallbackTests.UnchangedAppSignupAsync(client, _factory.Emails, ApiTestHelpers.UniqueEmail("devflow-remote"), "Kq7#mzpw-ok"));
            Assert.Contains(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackRefused"));
        }
    }

    public class DevDefaultTests : IClassFixture<DevDefaultApiFactory>
    {
        private readonly DevDefaultApiFactory _factory;

        public DevDefaultTests(DevDefaultApiFactory factory)
        {
            _factory = factory;
        }

        [Fact]
        public async Task T_SW_07_dev_fallback_is_off_by_default_even_in_development_on_loopback()
        {
            var client = _factory.CreateClient();
            Assert.Equal(HttpStatusCode.BadRequest,
                await DevFallbackTests.UnchangedAppSignupAsync(client, _factory.Emails, ApiTestHelpers.UniqueEmail("devflow-default"), "Kq7#mzpw-ok"));
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }
    }

    // ---------------- T-KEY-01: Security:CodeHmacKey start-up validation ----------------

    public class CodeKeyStartupTests
    {
        [Theory]
        [InlineData(null, "Security:CodeHmacKey is not configured")]
        [InlineData("SET-WITH-DOTNET-USER-SECRETS", "placeholder")]
        [InlineData("not base64 !", "not valid base64")]
        [InlineData("AAAAAAAAAAAAAAAAAAAAAA==", "too short: 16 bytes")]
        public void T_KEY_01_missing_or_weak_code_key_stops_startup_without_revealing_it(string? key, string expected)
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Security:CodeHmacKey"] = key });

            var failure = factory.StartupFailure();

            Assert.Contains(expected, failure);
            if (key != null) Assert.DoesNotContain(key, failure);
        }
    }
}
