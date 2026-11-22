using System.Net;
using System.Net.Http.Headers;
using DevLink.Api.Tests.Infrastructure;

namespace DevLink.Api.Tests
{
    // T-JWT-06 (start-up key validation) and T-JWT-07 (key rotation), M2_AUTH_DESIGN §3.2.
    public class JwtStartupValidationTests
    {
        private static Dictionary<string, string?> NoKeys() => new()
        {
            ["Jwt:SigningKeys:0:Id"] = null,
            ["Jwt:SigningKeys:0:Key"] = null,
            ["Jwt:SigningKeys:0:Status"] = null
        };

        [Fact]
        public void T_JWT_06_missing_signing_key_stops_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: NoKeys());

            Assert.Contains("No JWT signing key is configured", factory.StartupFailure());
        }

        [Fact]
        public void T_JWT_06_key_entry_without_a_value_stops_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Jwt:SigningKeys:0:Key"] = null });

            Assert.Contains("has no key value", factory.StartupFailure());
        }

        [Theory]
        [InlineData(32)]
        [InlineData(63)]
        public void T_JWT_06_key_shorter_than_64_bytes_stops_startup_without_revealing_it(int bytes)
        {
            var shortKey = TestSecuritySettings.NewSigningKey(bytes);
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Jwt:SigningKeys:0:Key"] = shortKey });

            var failure = factory.StartupFailure();

            Assert.Contains($"too short: {bytes} bytes, at least 64", failure);
            Assert.DoesNotContain(shortKey, failure);
        }

        [Fact]
        public void T_JWT_06_key_that_is_not_base64_stops_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Jwt:SigningKeys:0:Key"] = "not base64 at all!" });

            Assert.Contains("is not valid base64", factory.StartupFailure());
        }

        [Fact]
        public void T_JWT_06_placeholder_key_from_the_example_file_stops_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Jwt:SigningKeys:0:Key"] = "SET-WITH-DOTNET-USER-SECRETS" });

            Assert.Contains("placeholder", factory.StartupFailure());
        }

        [Fact]
        public void T_JWT_06_duplicate_key_ids_stop_startup()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?>
            {
                ["Jwt:SigningKeys:1:Id"] = TestSecuritySettings.KeyId,
                ["Jwt:SigningKeys:1:Key"] = TestSecuritySettings.NewSigningKey(),
                ["Jwt:SigningKeys:1:Status"] = "ValidateOnly"
            });

            Assert.Contains("Duplicate JWT signing key id", factory.StartupFailure());
        }

        [Fact]
        public void T_JWT_06_exactly_one_active_key_is_required()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?>
            {
                ["Jwt:SigningKeys:1:Id"] = "second",
                ["Jwt:SigningKeys:1:Key"] = TestSecuritySettings.NewSigningKey(),
                ["Jwt:SigningKeys:1:Status"] = "Active"
            });

            Assert.Contains("Exactly one JWT signing key must have Status=Active (found 2)", factory.StartupFailure());
        }

        [Fact]
        public void T_JWT_06_access_token_lifetime_can_only_change_in_development()
        {
            using var testing = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Jwt:AccessTokenMinutes"] = "5" });
            Assert.Contains("can only be changed in Development", testing.StartupFailure());

            using var development = new HostOnlyApiFactory("Development", new Dictionary<string, string?> { ["Jwt:AccessTokenMinutes"] = "1" });
            development.CreateClient();
        }

        [Fact]
        public async Task T_JWT_07_validate_only_key_still_validates_and_removed_key_fails()
        {
            var previousKey = TestSecuritySettings.NewSigningKey();
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?>
            {
                ["Jwt:SigningKeys:1:Id"] = "previous",
                ["Jwt:SigningKeys:1:Key"] = previousKey,
                ["Jwt:SigningKeys:1:Status"] = "ValidateOnly"
            });
            var client = factory.CreateClient();

            var signedWithPrevious = new TokenMinter { KeyBase64 = previousKey, KeyId = "previous" }.Mint();
            var signedWithRemoved = new TokenMinter { KeyBase64 = TestSecuritySettings.NewSigningKey(), KeyId = "removed" }.Mint();

            Assert.Equal(HttpStatusCode.OK, (await Send(client, signedWithPrevious)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(client, signedWithRemoved)).StatusCode);
        }

        private static Task<HttpResponseMessage> Send(HttpClient client, string token)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, "/__tests/auth/me");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return client.SendAsync(request);
        }
    }
}
