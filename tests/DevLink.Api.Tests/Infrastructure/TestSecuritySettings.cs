using System.Security.Cryptography;

namespace DevLink.Api.Tests.Infrastructure
{
    // Security settings every test host needs (M2.2+). Keys are random per run and never written anywhere.
    public static class TestSecuritySettings
    {
        public const string Origin = "https://app.devlink.test";
        public const string KeyId = "test-key-1";

        public static string NewSigningKey(int bytes = 64) =>
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(bytes));

        public static Dictionary<string, string?> Defaults(string signingKey)
        {
            var settings = new Dictionary<string, string?>
            {
                ["Jwt:SigningKeys:0:Id"] = KeyId,
                ["Jwt:SigningKeys:0:Key"] = signingKey,
                ["Jwt:SigningKeys:0:Status"] = "Active",
                ["Cors:AllowedOrigins:0"] = Origin,
                ["Security:CodeHmacKey"] = NewSigningKey(32),
                ["Security:MediaUrlKey"] = NewSigningKey(32),

                // M2.5a limits are per client IP; the test server has one, so ordinary tests get
                // effectively unlimited budgets. Rate-limit tests lower them explicitly.
                ["Auth:CodeFailuresPerIpPerHour"] = "100000"
            };

            foreach (var key in new[] { "Login", "CodeSend", "CodeVerify", "PasswordSet", "GoogleLogin" })
            {
                settings[$"RateLimits:{key}:PermitLimit"] = "100000";
            }

            return settings;
        }
    }
}
