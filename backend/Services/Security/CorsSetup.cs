using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.Extensions.Options;

namespace Services.Security
{
    // "Cors" configuration section: the exact browser origins allowed to call the API.
    public class CorsSettings
    {
        public const string SectionName = "Cors";

        public List<string> AllowedOrigins { get; set; } = new();
    }

    // Credentials are allowed, so origins must be explicit (M2_AUTH_DESIGN §4.2).
    public class CorsSettingsValidator : IValidateOptions<CorsSettings>
    {
        private readonly IHostEnvironment _environment;

        public CorsSettingsValidator(IHostEnvironment environment)
        {
            _environment = environment;
        }

        public ValidateOptionsResult Validate(string? name, CorsSettings settings)
        {
            if (settings.AllowedOrigins.Count == 0)
            {
                return ValidateOptionsResult.Fail(
                    "Cors:AllowedOrigins is empty. Credentials are enabled, so list the exact web-app origins " +
                    "(Development: \"http://localhost:5200\"). See README.md.");
            }

            var errors = new List<string>();
            foreach (var origin in settings.AllowedOrigins)
            {
                var error = ValidateOrigin(origin, _environment.IsDevelopment());
                if (error != null)
                {
                    errors.Add(error);
                }
            }

            return errors.Count == 0 ? ValidateOptionsResult.Success : ValidateOptionsResult.Fail(errors);
        }

        private static string? ValidateOrigin(string? origin, bool isDevelopment)
        {
            if (string.IsNullOrWhiteSpace(origin))
            {
                return "Cors:AllowedOrigins contains an empty entry.";
            }

            if (origin.Contains('*'))
            {
                return $"Cors:AllowedOrigins must not contain wildcards ('{origin}'): credentials are enabled.";
            }

            if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri) ||
                (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps) ||
                !origin.StartsWith(uri.Scheme + "://", StringComparison.OrdinalIgnoreCase))
            {
                return $"Cors:AllowedOrigins entry '{origin}' must be an absolute http(s) origin, e.g. https://app.example.com.";
            }

            if (uri.AbsolutePath != "/" || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment) ||
                !string.IsNullOrEmpty(uri.UserInfo))
            {
                return $"Cors:AllowedOrigins entry '{origin}' must be an origin only (scheme, host, port) — no path or query.";
            }

            if (!isDevelopment && uri.Scheme != Uri.UriSchemeHttps)
            {
                return $"Cors:AllowedOrigins entry '{origin}' must use https outside Development.";
            }

            return null;
        }

        public static string Normalize(string origin) =>
            new Uri(origin.Trim(), UriKind.Absolute).GetLeftPart(UriPartial.Authority);
    }

    public static class CorsSetup
    {
        public const string PolicyName = "Frontend";
        public const string ClientHeader = "X-DevLink-Client";

        public static IServiceCollection AddDevLinkCors(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddOptions<CorsSettings>()
                .Bind(configuration.GetSection(CorsSettings.SectionName))
                .ValidateOnStart();
            services.AddSingleton<IValidateOptions<CorsSettings>, CorsSettingsValidator>();

            services.AddCors();
            services.AddOptions<CorsOptions>()
                .Configure<IOptions<CorsSettings>>((cors, settings) =>
                    cors.AddPolicy(PolicyName, policy => policy
                        .WithOrigins(settings.Value.AllowedOrigins.Select(CorsSettingsValidator.Normalize).ToArray())
                        .AllowCredentials()
                        .WithHeaders("Authorization", "Content-Type", ClientHeader)
                        .WithMethods("GET", "POST", "PUT", "DELETE")
                        .SetPreflightMaxAge(TimeSpan.FromMinutes(10))));

            return services;
        }
    }
}
