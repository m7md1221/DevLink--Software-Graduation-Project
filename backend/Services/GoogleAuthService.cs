using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace Services
{
    public enum GoogleTokenOutcome
    {
        Valid,
        Invalid,
        EmailNotVerified,
        Unavailable,
        NotConfigured
    }

    public sealed record GoogleIdentity(string Subject, string Email);

    // Reason: a short, fixed code for logs and security events. Never the token or anything taken from it.
    public sealed record GoogleTokenResult(GoogleTokenOutcome Outcome, GoogleIdentity? Identity = null, string? Reason = null);

    public interface IGoogleTokenValidator
    {
        Task<GoogleTokenResult> ValidateAsync(string idToken, CancellationToken cancellationToken);
    }

    // Google's public signing keys. Production reads Google's OpenID metadata; tests supply their own keys.
    public interface IGoogleSigningKeys
    {
        Task<IReadOnlyCollection<SecurityKey>> GetAsync(bool refresh, CancellationToken cancellationToken);
    }

    // "Google:ClientIds" (list), plus the older single "Google:ClientId", so existing settings keep working.
    public class GoogleOptions
    {
        public IReadOnlyList<string> ClientIds { get; }

        public GoogleOptions(IConfiguration configuration)
        {
            ClientIds = (configuration.GetSection("Google:ClientIds").Get<string[]>() ?? Array.Empty<string>())
                .Concat(new[] { configuration["Google:ClientId"] })
                .Where(id => !string.IsNullOrWhiteSpace(id) && !id!.StartsWith("YOUR_", StringComparison.Ordinal))
                .Select(id => id!.Trim())
                .Distinct(StringComparer.Ordinal)
                .ToList();
        }
    }

    public class GoogleSigningKeys : IGoogleSigningKeys
    {
        public const string MetadataAddress = "https://accounts.google.com/.well-known/openid-configuration";

        private readonly ConfigurationManager<OpenIdConnectConfiguration> _configuration = new(
            MetadataAddress, new OpenIdConnectConfigurationRetriever(), new HttpDocumentRetriever { RequireHttps = true });

        public async Task<IReadOnlyCollection<SecurityKey>> GetAsync(bool refresh, CancellationToken cancellationToken)
        {
            if (refresh)
            {
                _configuration.RequestRefresh();
            }

            return (await _configuration.GetConfigurationAsync(cancellationToken)).SigningKeys.ToList();
        }
    }

    // ============================================================
    // Google ID-token validation (M2_AUTH_DESIGN §6.3, Q11): RS256 signature
    // with Google's keys, issuer, audience = a configured client id, expiry
    // (from the injected clock), a subject, and email_verified = true.
    // Built on Microsoft.IdentityModel (already referenced through JwtBearer),
    // so every rule can be tested with keys the tests control.
    // ============================================================
    public class GoogleTokenValidator : IGoogleTokenValidator
    {
        public static readonly string[] Issuers = { "https://accounts.google.com", "accounts.google.com" };
        public static readonly TimeSpan ClockSkew = TimeSpan.FromMinutes(1);

        private readonly GoogleOptions _options;
        private readonly IGoogleSigningKeys _keys;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;
        private readonly JsonWebTokenHandler _handler = new();

        public GoogleTokenValidator(GoogleOptions options, IGoogleSigningKeys keys, TimeProvider time, ILoggerFactory loggers)
        {
            _options = options;
            _keys = keys;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        public async Task<GoogleTokenResult> ValidateAsync(string idToken, CancellationToken cancellationToken)
        {
            if (_options.ClientIds.Count == 0)
            {
                return new GoogleTokenResult(GoogleTokenOutcome.NotConfigured, Reason: "NotConfigured");
            }

            if (string.IsNullOrWhiteSpace(idToken) || idToken.Length > 8192 || !_handler.CanReadToken(idToken))
            {
                return new GoogleTokenResult(GoogleTokenOutcome.Invalid, Reason: "Malformed");
            }

            // Google rotates its keys: one refresh when the token names a key we don't have yet.
            for (var attempt = 0; attempt < 2; attempt++)
            {
                IReadOnlyCollection<SecurityKey> keys;
                try
                {
                    keys = await _keys.GetAsync(refresh: attempt > 0, cancellationToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    _logger.LogWarning("Auth.GoogleKeysUnavailable {FailureType}", ex.GetType().Name);
                    return new GoogleTokenResult(GoogleTokenOutcome.Unavailable, Reason: "KeysUnavailable");
                }

                var result = await _handler.ValidateTokenAsync(idToken, Parameters(keys));
                if (result.IsValid)
                {
                    return Identity(result.Claims);
                }

                if (result.Exception is SecurityTokenSignatureKeyNotFoundException && attempt == 0)
                {
                    continue;
                }

                return new GoogleTokenResult(GoogleTokenOutcome.Invalid, Reason: Classify(result.Exception));
            }

            return new GoogleTokenResult(GoogleTokenOutcome.Invalid, Reason: "UnknownKey");
        }

        private TokenValidationParameters Parameters(IReadOnlyCollection<SecurityKey> keys) => new()
        {
            ValidIssuers = Issuers,
            ValidAudiences = _options.ClientIds,
            IssuerSigningKeys = keys,
            ValidAlgorithms = new[] { SecurityAlgorithms.RsaSha256 },
            RequireSignedTokens = true,
            RequireExpirationTime = true,
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            // The injected clock, so expiry is testable and consistent with the rest of the API.
            LifetimeValidator = (notBefore, expires, _, _) =>
            {
                var now = _time.GetUtcNow().UtcDateTime;
                return expires.HasValue && now < expires.Value + ClockSkew && (notBefore == null || notBefore.Value <= now + ClockSkew);
            },
        };

        private static GoogleTokenResult Identity(IDictionary<string, object> claims)
        {
            var subject = claims.TryGetValue("sub", out var sub) ? sub?.ToString() : null;
            var email = claims.TryGetValue("email", out var mail) ? mail?.ToString() : null;
            if (string.IsNullOrWhiteSpace(subject) || string.IsNullOrWhiteSpace(email))
            {
                return new GoogleTokenResult(GoogleTokenOutcome.Invalid, Reason: "MissingClaims");
            }

            var verified = claims.TryGetValue("email_verified", out var flag) &&
                           (flag is true || string.Equals(flag?.ToString(), "true", StringComparison.OrdinalIgnoreCase));
            if (!verified)
            {
                return new GoogleTokenResult(GoogleTokenOutcome.EmailNotVerified, Reason: "EmailNotVerified");
            }

            return new GoogleTokenResult(GoogleTokenOutcome.Valid, new GoogleIdentity(subject, email.Trim().ToLowerInvariant()));
        }

        private static string Classify(Exception? exception) => exception switch
        {
            SecurityTokenInvalidAudienceException => "WrongAudience",
            SecurityTokenInvalidIssuerException => "WrongIssuer",
            SecurityTokenInvalidLifetimeException or SecurityTokenExpiredException => "Expired",
            SecurityTokenSignatureKeyNotFoundException => "UnknownKey",
            SecurityTokenInvalidSignatureException => "BadSignature",
            SecurityTokenInvalidAlgorithmException => "WrongAlgorithm",
            _ => "Invalid"
        };
    }

    public static class GoogleSetup
    {
        public static IServiceCollection AddDevLinkGoogle(this IServiceCollection services)
        {
            services.AddSingleton<GoogleOptions>();
            services.AddSingleton<IGoogleSigningKeys, GoogleSigningKeys>();
            services.AddSingleton<IGoogleTokenValidator, GoogleTokenValidator>();
            services.AddScoped<Services.Auth.GoogleSignInService>();
            return services;
        }
    }
}
