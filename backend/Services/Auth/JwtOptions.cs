using Microsoft.Extensions.Options;

namespace Services.Auth
{
    public enum SigningKeyStatus
    {
        Active,
        ValidateOnly
    }

    public class JwtSigningKey
    {
        // Non-secret key id, written to the token's "kid" header.
        public string Id { get; set; } = "";

        // Base64 of at least 64 random bytes. Provided by user-secrets or the environment, never by a committed file.
        public string Key { get; set; } = "";

        public SigningKeyStatus Status { get; set; } = SigningKeyStatus.Active;
    }

    // ============================================================
    // "Jwt" configuration section (M2_AUTH_DESIGN §3.2).
    // ============================================================
    public class JwtOptions
    {
        public const string SectionName = "Jwt";
        public const int MinKeyBytes = 64;
        public const int MaxAccessTokenMinutes = 15;
        public const string AccessTokenType = "at+jwt";

        // The value shipped in appsettings.example.json; never a usable key.
        public const string KeyPlaceholder = "SET-WITH-DOTNET-USER-SECRETS";

        public static readonly TimeSpan ClockSkew = TimeSpan.FromSeconds(30);

        public string Issuer { get; set; } = "DevLink.Api";
        public string Audience { get; set; } = "DevLink.Clients";

        // 15 everywhere; Development may shorten it (1–15) for refresh testing.
        public int AccessTokenMinutes { get; set; } = MaxAccessTokenMinutes;

        public List<JwtSigningKey> SigningKeys { get; set; } = new();
    }

    // Fails host start-up with a clear message. Messages name key ids and sizes, never key material.
    public class JwtOptionsValidator : IValidateOptions<JwtOptions>
    {
        private const string Help =
            "Generate a key with `dotnet user-secrets` as described in README.md (\"JWT signing key\").";

        private readonly IHostEnvironment _environment;

        public JwtOptionsValidator(IHostEnvironment environment)
        {
            _environment = environment;
        }

        public ValidateOptionsResult Validate(string? name, JwtOptions options)
        {
            var errors = new List<string>();

            if (string.IsNullOrWhiteSpace(options.Issuer)) errors.Add("Jwt:Issuer must not be empty.");
            if (string.IsNullOrWhiteSpace(options.Audience)) errors.Add("Jwt:Audience must not be empty.");

            if (_environment.IsDevelopment())
            {
                if (options.AccessTokenMinutes < 1 || options.AccessTokenMinutes > JwtOptions.MaxAccessTokenMinutes)
                {
                    errors.Add($"Jwt:AccessTokenMinutes must be between 1 and {JwtOptions.MaxAccessTokenMinutes} in Development.");
                }
            }
            else if (options.AccessTokenMinutes != JwtOptions.MaxAccessTokenMinutes)
            {
                errors.Add($"Jwt:AccessTokenMinutes can only be changed in Development (must be {JwtOptions.MaxAccessTokenMinutes}).");
            }

            if (options.SigningKeys.Count == 0)
            {
                errors.Add($"No JWT signing key is configured (Jwt:SigningKeys is empty). {Help}");
                return ValidateOptionsResult.Fail(errors);
            }

            for (var i = 0; i < options.SigningKeys.Count; i++)
            {
                var key = options.SigningKeys[i];
                var label = string.IsNullOrWhiteSpace(key.Id) ? $"Jwt:SigningKeys:{i}" : $"JWT signing key '{key.Id}'";

                if (string.IsNullOrWhiteSpace(key.Id))
                {
                    errors.Add($"Jwt:SigningKeys:{i}:Id must not be empty.");
                }

                if (string.IsNullOrWhiteSpace(key.Key))
                {
                    errors.Add($"{label} has no key value. {Help}");
                    continue;
                }

                if (key.Key.Trim() == JwtOptions.KeyPlaceholder)
                {
                    errors.Add($"{label} still contains the placeholder from appsettings.example.json. {Help}");
                    continue;
                }

                var decodedLength = DecodedLength(key.Key);
                if (decodedLength < 0)
                {
                    errors.Add($"{label} is not valid base64. {Help}");
                }
                else if (decodedLength < JwtOptions.MinKeyBytes)
                {
                    errors.Add($"{label} is too short: {decodedLength} bytes, at least {JwtOptions.MinKeyBytes} bytes are required. {Help}");
                }
            }

            var duplicateIds = options.SigningKeys
                .Where(k => !string.IsNullOrWhiteSpace(k.Id))
                .GroupBy(k => k.Id, StringComparer.Ordinal)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key)
                .ToList();
            if (duplicateIds.Count > 0)
            {
                errors.Add($"Duplicate JWT signing key id(s): {string.Join(", ", duplicateIds)}.");
            }

            var activeCount = options.SigningKeys.Count(k => k.Status == SigningKeyStatus.Active);
            if (activeCount != 1)
            {
                errors.Add($"Exactly one JWT signing key must have Status=Active (found {activeCount}).");
            }

            return errors.Count == 0 ? ValidateOptionsResult.Success : ValidateOptionsResult.Fail(errors);
        }

        // Decoded byte length, or -1 if the value isn't base64.
        public static int DecodedLength(string value)
        {
            var buffer = new byte[value.Length];
            return Convert.TryFromBase64String(value.Trim(), buffer, out var written) ? written : -1;
        }
    }
}
