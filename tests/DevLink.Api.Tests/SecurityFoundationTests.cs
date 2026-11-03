using System.Net;
using System.Net.Http.Headers;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Logging;
using Microsoft.IdentityModel.Tokens;

namespace DevLink.Api.Tests
{
    // T-SC-06 (topology guard), T-LOG-01 (no URLs/tokens in logs), CORS allowlist (T-CS-06, CORS part)
    // and response hardening headers (§4.3).
    public class SecurityFoundationTests
    {
        // ---------- T-SC-06 ----------

        [Fact]
        public void T_SC_06_multi_instance_topology_stops_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Deployment:Topology"] = "MultiInstance" });

            Assert.Contains("MultiInstance is not supported", factory.StartupFailure());
        }

        [Fact]
        public void T_SC_06_unknown_topology_stops_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Deployment:Topology"] = "Cluster" });

            Assert.Contains("Deployment:Topology must be 'SingleInstance'", factory.StartupFailure());
        }

        [Fact]
        public async Task T_SC_06_default_topology_is_single_instance()
        {
            using var factory = new HostOnlyApiFactory();

            Assert.True((await factory.CreateClient().GetAsync("/__tests/auth/ping")).IsSuccessStatusCode);
        }

        // ---------- T-LOG-01 ----------

        [Fact]
        public void T_LOG_01_url_logging_categories_stay_at_warning_whatever_the_configuration_says()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?>
            {
                ["Logging:LogLevel:Default"] = "Trace",
                ["Logging:LogLevel:Microsoft.AspNetCore.Hosting.Diagnostics"] = "Trace",
                ["Logging:LogLevel:Microsoft.AspNetCore.Routing.EndpointMiddleware"] = "Debug",
                ["Logging:Console:LogLevel:Microsoft.AspNetCore"] = "Debug",
                ["Logging:Debug:LogLevel:Microsoft.AspNetCore.Hosting"] = "Trace"
            });
            factory.CreateClient();
            var loggers = factory.Services.GetRequiredService<ILoggerFactory>();

            foreach (var category in new[] { "Microsoft.AspNetCore.Hosting.Diagnostics", "Microsoft.AspNetCore.Routing.EndpointMiddleware" })
            {
                var logger = loggers.CreateLogger(category);
                Assert.False(logger.IsEnabled(LogLevel.Information), category);
                Assert.True(logger.IsEnabled(LogLevel.Warning), category);
            }

            // The guard is targeted: other categories still follow the configuration.
            Assert.True(loggers.CreateLogger("Microsoft.AspNetCore.Authentication").IsEnabled(LogLevel.Debug));
        }

        [Fact]
        public void T_LOG_01_identity_model_never_logs_personal_data_or_complete_tokens()
        {
            using var factory = new HostOnlyApiFactory();
            factory.CreateClient();

            Assert.False(IdentityModelEventSource.ShowPII);
            Assert.False(IdentityModelEventSource.LogCompleteSecurityArtifact);
        }

        [Fact]
        public async Task T_LOG_01_rejected_and_accepted_tokens_never_appear_in_logs()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Logging:LogLevel:Default"] = "Trace" });
            var client = factory.CreateClient();
            var minter = new TokenMinter { KeyBase64 = factory.SigningKey };

            var tokens = new[]
            {
                minter.Mint(),
                (minter with { IssuedAgo = TimeSpan.FromMinutes(30) }).Mint(),
                (minter with { KeyBase64 = TestSecuritySettings.NewSigningKey() }).Mint(),
                (minter with { Algorithm = SecurityAlgorithms.HmacSha384 }).Mint(),
                (minter with { TokenType = "JWT" }).Mint(),
                minter.MintUnsigned(),
                "not-even-a-jwt"
            };

            foreach (var token in tokens)
            {
                var request = new HttpRequestMessage(HttpMethod.Get, "/__tests/auth/me");
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                await client.SendAsync(request);
            }

            var logs = factory.Logs.AllText;
            Assert.Contains("Auth.TokenRejected", logs);
            foreach (var token in tokens)
            {
                Assert.DoesNotContain(token, logs);
                foreach (var part in token.Split('.').Where(p => p.Length > 16))
                {
                    Assert.DoesNotContain(part, logs);
                }
            }

            Assert.DoesNotContain(factory.SigningKey, logs);
        }

        // ---------- CORS (T-CS-06, CORS part) ----------

        private static HttpRequestMessage Preflight(string origin)
        {
            var request = new HttpRequestMessage(HttpMethod.Options, "/__tests/auth/ping");
            request.Headers.Add("Origin", origin);
            request.Headers.Add("Access-Control-Request-Method", "POST");
            request.Headers.Add("Access-Control-Request-Headers", "content-type,x-devlink-client,authorization");
            return request;
        }

        [Fact]
        public async Task T_CS_06_listed_origin_gets_credentialed_cors_headers()
        {
            using var factory = new HostOnlyApiFactory();
            var client = factory.CreateClient();

            var response = await client.SendAsync(Preflight(TestSecuritySettings.Origin));

            Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
            Assert.Equal(TestSecuritySettings.Origin, response.Headers.GetValues("Access-Control-Allow-Origin").Single());
            Assert.Equal("true", response.Headers.GetValues("Access-Control-Allow-Credentials").Single());
            Assert.Contains("x-devlink-client", response.Headers.GetValues("Access-Control-Allow-Headers").Single(), StringComparison.OrdinalIgnoreCase);
        }

        [Theory]
        [InlineData("https://evil.example")]
        [InlineData("http://app.devlink.test")]
        [InlineData("https://app.devlink.test.evil.example")]
        public async Task T_CS_06_unlisted_origin_gets_no_cors_headers(string origin)
        {
            using var factory = new HostOnlyApiFactory();
            var client = factory.CreateClient();

            var preflight = await client.SendAsync(Preflight(origin));
            var simple = new HttpRequestMessage(HttpMethod.Get, "/__tests/auth/ping");
            simple.Headers.Add("Origin", origin);
            var get = await client.SendAsync(simple);

            Assert.False(preflight.Headers.Contains("Access-Control-Allow-Origin"));
            Assert.False(get.Headers.Contains("Access-Control-Allow-Origin"));
        }

        [Theory]
        [InlineData("*", "must not contain wildcards")]
        [InlineData("https://*.devlink.test", "must not contain wildcards")]
        [InlineData(" ", "empty entry")]
        [InlineData("localhost:5200", "absolute http(s) origin")]
        [InlineData("https://app.devlink.test/path", "origin only")]
        [InlineData("http://app.devlink.test", "must use https outside Development")]
        public void T_CS_06_invalid_origins_stop_startup(string origin, string expected)
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Cors:AllowedOrigins:0"] = origin });

            Assert.Contains(expected, factory.StartupFailure());
        }

        [Fact]
        public void T_CS_06_missing_origins_stop_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Cors:AllowedOrigins:0"] = null });

            Assert.Contains("Cors:AllowedOrigins is empty", factory.StartupFailure());
        }

        [Fact]
        public async Task T_CS_06_development_accepts_the_local_http_origin()
        {
            using var factory = new HostOnlyApiFactory("Development", new Dictionary<string, string?> { ["Cors:AllowedOrigins:0"] = "http://localhost:5200" });
            var client = factory.CreateClient();

            var response = await client.SendAsync(Preflight("http://localhost:5200"));

            Assert.Equal("http://localhost:5200", response.Headers.GetValues("Access-Control-Allow-Origin").Single());
        }

        // ---------- Response hardening (§4.3) ----------

        [Fact]
        public async Task Security_headers_are_set_and_auth_routes_are_not_cached()
        {
            using var factory = new HostOnlyApiFactory();
            var client = factory.CreateClient();

            var ping = await client.GetAsync("/__tests/auth/ping");
            var auth = await client.GetAsync("/api/Auth/does-not-exist");

            foreach (var response in new[] { ping, auth })
            {
                Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
                Assert.Equal("no-referrer", response.Headers.GetValues("Referrer-Policy").Single());
                Assert.Equal("DENY", response.Headers.GetValues("X-Frame-Options").Single());
                Assert.False(response.Headers.Contains("X-DevLink-Auth"));
            }

            Assert.True(auth.Headers.CacheControl?.NoStore);
        }
    }
}
