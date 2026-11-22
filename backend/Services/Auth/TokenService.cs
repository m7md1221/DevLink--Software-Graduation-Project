using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Services.Auth
{
    // The decoded signing keys: one Active key signs, every configured key validates (rotation, §3.2).
    public class JwtKeyRing
    {
        public JwtKeyRing(IOptions<JwtOptions> options)
        {
            var keys = new List<SymmetricSecurityKey>();

            foreach (var configured in options.Value.SigningKeys)
            {
                var key = new SymmetricSecurityKey(Convert.FromBase64String(configured.Key.Trim()))
                {
                    KeyId = configured.Id
                };
                keys.Add(key);

                if (configured.Status == SigningKeyStatus.Active)
                {
                    ActiveKey = key;
                }
            }

            ValidationKeys = keys;
            ActiveKey ??= keys[0];
        }

        public SymmetricSecurityKey ActiveKey { get; }

        public IReadOnlyList<SecurityKey> ValidationKeys { get; }
    }

    public record AccessTokenRequest(int UserId, string Role, string SecurityStamp, Guid SessionId);

    public record AccessToken(string Token, DateTime ExpiresAtUtc);

    // ============================================================
    // Issues 15-minute access tokens (HS256, typ "at+jwt").
    // Claims: sub, role, sstamp, sid, jti, iat/nbf/exp, iss, aud.
    // No email or other personal data: a JWT is signed, not encrypted.
    // ============================================================
    public class TokenService
    {
        private readonly JsonWebTokenHandler _handler = new();
        private readonly JwtKeyRing _keys;
        private readonly JwtOptions _options;
        private readonly TimeProvider _time;

        public TokenService(JwtKeyRing keys, IOptions<JwtOptions> options, TimeProvider time)
        {
            _keys = keys;
            _options = options.Value;
            _time = time;
        }

        public AccessToken CreateAccessToken(AccessTokenRequest request)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var expires = now.AddMinutes(_options.AccessTokenMinutes);

            var descriptor = new SecurityTokenDescriptor
            {
                Issuer = _options.Issuer,
                Audience = _options.Audience,
                IssuedAt = now,
                NotBefore = now,
                Expires = expires,
                TokenType = JwtOptions.AccessTokenType,
                SigningCredentials = new SigningCredentials(_keys.ActiveKey, SecurityAlgorithms.HmacSha256),
                Claims = new Dictionary<string, object>
                {
                    [JwtRegisteredClaimNames.Sub] = request.UserId.ToString(),
                    [AuthClaims.Role] = request.Role,
                    [AuthClaims.SecurityStamp] = request.SecurityStamp,
                    [AuthClaims.SessionId] = request.SessionId.ToString(),
                    [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString("N")
                }
            };

            return new AccessToken(_handler.CreateToken(descriptor), expires);
        }
    }

    public static class AuthClaims
    {
        public const string Role = "role";
        public const string SecurityStamp = "sstamp";
        public const string SessionId = "sid";
    }
}
