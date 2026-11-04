using Microsoft.Extensions.Options;
using Services.Auth;

namespace Services.Security
{
    // ============================================================
    // "Deployment:Topology" guard (M2_AUTH_DESIGN §3.7). M2 keeps
    // session state, download links and rate limits in process memory,
    // so only a single API instance is supported.
    // ============================================================
    public class DeploymentOptions
    {
        public const string SectionName = "Deployment";
        public const string SingleInstance = "SingleInstance";
        public const string MultiInstance = "MultiInstance";

        public string Topology { get; set; } = SingleInstance;
    }

    public class DeploymentOptionsValidator : IValidateOptions<DeploymentOptions>
    {
        public ValidateOptionsResult Validate(string? name, DeploymentOptions options)
        {
            if (string.Equals(options.Topology, DeploymentOptions.SingleInstance, StringComparison.OrdinalIgnoreCase))
            {
                return ValidateOptionsResult.Success;
            }

            if (string.Equals(options.Topology, DeploymentOptions.MultiInstance, StringComparison.OrdinalIgnoreCase))
            {
                return ValidateOptionsResult.Fail(
                    "Deployment:Topology=MultiInstance is not supported: session revocation, download links and rate limits " +
                    "are kept in process memory. Run exactly one API instance (M2_AUTH_DESIGN §3.7).");
            }

            return ValidateOptionsResult.Fail(
                $"Deployment:Topology must be '{DeploymentOptions.SingleInstance}' (got '{options.Topology}').");
        }
    }

    // ============================================================
    // Request URLs can carry download-link tokens and image signatures,
    // and these categories log full URLs at Information. They are held
    // at Warning for every provider, whatever the configuration says (§3.2).
    // ============================================================
    public static class LogLevelGuard
    {
        public static readonly string[] GuardedCategories =
        {
            "Microsoft.AspNetCore.Hosting.Diagnostics",
            "Microsoft.AspNetCore.Routing"
        };

        public static void Apply(LoggerFilterOptions options)
        {
            for (var i = 0; i < options.Rules.Count; i++)
            {
                var rule = options.Rules[i];
                if (IsGuarded(rule.CategoryName) && (rule.LogLevel ?? LogLevel.Trace) < LogLevel.Warning)
                {
                    options.Rules[i] = new LoggerFilterRule(rule.ProviderName, rule.CategoryName, LogLevel.Warning, rule.Filter);
                }
            }

            // Provider-specific rules beat generic ones, so the guard is repeated for each provider that has rules.
            var providers = options.Rules.Select(r => r.ProviderName).Distinct().ToList();
            if (!providers.Contains(null))
            {
                providers.Add(null);
            }

            foreach (var provider in providers)
            {
                foreach (var category in GuardedCategories)
                {
                    options.Rules.Add(new LoggerFilterRule(provider, category, LogLevel.Warning, null));
                }
            }
        }

        private static bool IsGuarded(string? category) =>
            category != null && GuardedCategories.Any(g => category.StartsWith(g, StringComparison.Ordinal));
    }

    public static class SecurityFoundation
    {
        public static IServiceCollection AddDevLinkSecurityFoundation(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddSingleton(TimeProvider.System);
            services.PostConfigure<LoggerFilterOptions>(LogLevelGuard.Apply);

            services.AddOptions<DeploymentOptions>()
                .Bind(configuration.GetSection(DeploymentOptions.SectionName))
                .ValidateOnStart();
            services.AddSingleton<IValidateOptions<DeploymentOptions>, DeploymentOptionsValidator>();

            services.AddOptions<SecurityKeysOptions>()
                .Bind(configuration.GetSection(SecurityKeysOptions.SectionName))
                .ValidateOnStart();
            services.AddSingleton<IValidateOptions<SecurityKeysOptions>, SecurityKeysOptionsValidator>();
            services.AddSingleton<SecurityKeys>();

            services.AddDevLinkCors(configuration);
            services.AddDevLinkAuthEnforcement();

            return services;
        }

        // nosniff / no-referrer / DENY on every response; no-store on /api/Auth/*; the switch header while it is off.
        public static IApplicationBuilder UseDevLinkSecurityHeaders(this IApplicationBuilder app)
        {
            return app.Use(async (context, next) =>
            {
                var enforcement = context.RequestServices.GetRequiredService<IOptions<AuthEnforcementOptions>>().Value;

                context.Response.OnStarting(() =>
                {
                    var headers = context.Response.Headers;
                    headers.XContentTypeOptions = "nosniff";
                    headers["Referrer-Policy"] = "no-referrer";
                    headers.XFrameOptions = "DENY";

                    if (context.Request.Path.StartsWithSegments("/api/Auth", StringComparison.OrdinalIgnoreCase))
                    {
                        headers.CacheControl = "no-store";
                    }

                    if (!enforcement.Enforced)
                    {
                        headers[AuthEnforcementOptions.ResponseHeader] = "NOT-ENFORCED";
                    }

                    return Task.CompletedTask;
                });

                await next();
            });
        }
    }
}
