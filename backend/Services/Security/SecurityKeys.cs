using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace Services.Security
{
    // "Security" configuration section: keys other than the JWT signing keys (M2_AUTH_DESIGN §3.2).
    public class SecurityKeysOptions
    {
        public const string SectionName = "Security";
        public const int MinKeyBytes = 32;
        public const string KeyPlaceholder = "SET-WITH-DOTNET-USER-SECRETS";

        // HMAC key for one-time codes, proof tokens and email keys (M2.5a). User-secrets / environment only.
        public string CodeHmacKey { get; set; } = "";
    }

    public class SecurityKeysOptionsValidator : IValidateOptions<SecurityKeysOptions>
    {
        private const string Help = "Generate it as described in README.md (\"Code HMAC key\").";

        public ValidateOptionsResult Validate(string? name, SecurityKeysOptions options)
        {
            var key = options.CodeHmacKey?.Trim() ?? "";
            if (key.Length == 0)
            {
                return ValidateOptionsResult.Fail($"Security:CodeHmacKey is not configured. {Help}");
            }

            if (key == SecurityKeysOptions.KeyPlaceholder)
            {
                return ValidateOptionsResult.Fail($"Security:CodeHmacKey still contains the placeholder from appsettings.example.json. {Help}");
            }

            var buffer = new byte[key.Length];
            if (!Convert.TryFromBase64String(key, buffer, out var length))
            {
                return ValidateOptionsResult.Fail($"Security:CodeHmacKey is not valid base64. {Help}");
            }

            if (length < SecurityKeysOptions.MinKeyBytes)
            {
                return ValidateOptionsResult.Fail(
                    $"Security:CodeHmacKey is too short: {length} bytes, at least {SecurityKeysOptions.MinKeyBytes} bytes are required. {Help}");
            }

            return ValidateOptionsResult.Success;
        }
    }

    // ============================================================
    // Keyed hashes derived from Security:CodeHmacKey. Each use has its
    // own label, so a value computed for one purpose is useless for another.
    // ============================================================
    public class SecurityKeys
    {
        private readonly byte[] _codeKey;

        public SecurityKeys(IOptions<SecurityKeysOptions> options)
        {
            _codeKey = Convert.FromBase64String(options.Value.CodeHmacKey.Trim());
        }

        public static string NormalizeEmail(string? email) => (email ?? string.Empty).Trim().ToLowerInvariant();

        public byte[] Hmac(string label, string value) =>
            HMACSHA256.HashData(_codeKey, Encoding.UTF8.GetBytes(label + "|" + value));

        // OneTimeCodes.EmailKey: the email itself is never stored there.
        public byte[] CodeEmailKey(string normalizedEmail) => Hmac("email", normalizedEmail);

        // SecurityEvents.EmailKey: 12 hex characters, enough to correlate events, not to recover the address.
        public string LogEmailKey(string normalizedEmail) =>
            Convert.ToHexString(Hmac("log", normalizedEmail), 0, 6).ToLowerInvariant();
    }
}
