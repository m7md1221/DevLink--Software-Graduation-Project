using System.Text;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace DevLink.Api.Tests.Infrastructure
{
    // Builds valid and deliberately broken access tokens for validation tests (T-JWT-*).
    public record TokenMinter
    {
        private readonly JsonWebTokenHandler _handler = new() { SetDefaultTimesOnTokenCreation = false };

        public string KeyBase64 { get; init; } = "";
        public string KeyId { get; init; } = TestSecuritySettings.KeyId;
        public string Algorithm { get; init; } = SecurityAlgorithms.HmacSha256;
        public string TokenType { get; init; } = "at+jwt";
        public string Issuer { get; init; } = "DevLink.Api";
        public string Audience { get; init; } = "DevLink.Clients";
        public TimeSpan IssuedAgo { get; init; } = TimeSpan.Zero;
        public TimeSpan Lifetime { get; init; } = TimeSpan.FromMinutes(15);
        public bool IncludeIssuedAt { get; init; } = true;
        public string Role { get; init; } = "Customer";

        public string Mint(int userId = 42)
        {
            var issuedAt = DateTime.UtcNow - IssuedAgo;
            var descriptor = new SecurityTokenDescriptor
            {
                Issuer = Issuer,
                Audience = Audience,
                NotBefore = issuedAt,
                Expires = issuedAt + Lifetime,
                TokenType = TokenType,
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(Convert.FromBase64String(KeyBase64)) { KeyId = KeyId }, Algorithm),
                Claims = new Dictionary<string, object>
                {
                    ["sub"] = userId.ToString(),
                    ["role"] = Role,
                    ["sstamp"] = "stamp",
                    ["sid"] = Guid.NewGuid().ToString(),
                    ["jti"] = Guid.NewGuid().ToString("N")
                }
            };

            if (IncludeIssuedAt)
            {
                descriptor.IssuedAt = issuedAt;
            }

            return _handler.CreateToken(descriptor);
        }

        // An unsigned token ("alg": "none") with otherwise valid content.
        public string MintUnsigned(int userId = 42)
        {
            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var header = $"{{\"alg\":\"none\",\"typ\":\"{TokenType}\"}}";
            var payload =
                $"{{\"sub\":\"{userId}\",\"role\":\"{Role}\",\"iss\":\"{Issuer}\",\"aud\":\"{Audience}\",\"iat\":{now},\"nbf\":{now},\"exp\":{now + 600}}}";
            return $"{Base64Url(header)}.{Base64Url(payload)}.";
        }

        private static string Base64Url(string json) => Base64UrlEncoder.Encode(Encoding.UTF8.GetBytes(json));
    }
}
