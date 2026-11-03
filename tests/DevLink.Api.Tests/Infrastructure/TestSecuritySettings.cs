using System.Security.Cryptography;

namespace DevLink.Api.Tests.Infrastructure
{
    // Security settings every test host needs (M2.2). Keys are random per run and never written anywhere.
    public static class TestSecuritySettings
    {
        public const string Origin = "https://app.devlink.test";
        public const string KeyId = "test-key-1";

        public static string NewSigningKey(int bytes = 64) =>
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(bytes));

        public static Dictionary<string, string?> Defaults(string signingKey) => new()
        {
            ["Jwt:SigningKeys:0:Id"] = KeyId,
            ["Jwt:SigningKeys:0:Key"] = signingKey,
            ["Jwt:SigningKeys:0:Status"] = "Active",
            ["Cors:AllowedOrigins:0"] = Origin
        };
    }
}
