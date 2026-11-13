using System.Threading.RateLimiting;
using DataBase;
using Microsoft.AspNetCore.RateLimiting;
using Services.Auth;

namespace Services.Security
{
    // ============================================================
    // Per-IP request limits on the sign-in and account-recovery endpoints
    // (M2.5a; M2_AUTH_DESIGN §6.2 — mitigation for targeted lockout, KI-43).
    // Fixed windows, in memory (single instance, §3.7). Values are
    // configurable under RateLimits:<Policy>:PermitLimit / WindowSeconds.
    // Rejections: 429 + Retry-After + RATE_LIMITED, audited with the IP prefix.
    // ============================================================
    public static class RateLimitPolicies
    {
        public const string Login = "auth-login";
        public const string CodeSend = "auth-code-send";
        public const string CodeVerify = "auth-code-verify";
        public const string PasswordSet = "auth-password-set";
        public const string GoogleLogin = "auth-google";
        public const string PasswordChange = "auth-password-change";

        // name → (config key, default permits, default window)
        public static readonly IReadOnlyDictionary<string, (string Key, int Permits, TimeSpan Window)> Defaults =
            new Dictionary<string, (string, int, TimeSpan)>
            {
                [Login] = ("Login", 10, TimeSpan.FromMinutes(1)),
                [CodeSend] = ("CodeSend", 10, TimeSpan.FromHours(1)),
                [CodeVerify] = ("CodeVerify", 30, TimeSpan.FromMinutes(15)),
                [PasswordSet] = ("PasswordSet", 10, TimeSpan.FromHours(1)),
                [GoogleLogin] = ("GoogleLogin", 20, TimeSpan.FromMinutes(1)),
                [PasswordChange] = ("PasswordChange", 10, TimeSpan.FromMinutes(15))
            };
    }

    public static class RateLimitingSetup
    {
        public static IServiceCollection AddDevLinkRateLimiting(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

                foreach (var (policy, (key, permits, window)) in RateLimitPolicies.Defaults)
                {
                    var limit = Math.Max(1, configuration.GetValue($"RateLimits:{key}:PermitLimit", permits));
                    var seconds = Math.Max(1, configuration.GetValue($"RateLimits:{key}:WindowSeconds", (int)window.TotalSeconds));

                    options.AddPolicy(policy, http => RateLimitPartition.GetFixedWindowLimiter(
                        $"{policy}|{http.Connection.RemoteIpAddress?.ToString() ?? "unknown"}",
                        _ => new FixedWindowRateLimiterOptions
                        {
                            PermitLimit = limit,
                            Window = TimeSpan.FromSeconds(seconds),
                            QueueLimit = 0,
                            AutoReplenishment = true
                        }));
                }

                options.OnRejected = async (context, cancellationToken) =>
                {
                    var http = context.HttpContext;
                    var retryAfter = context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var wait) ? wait : TimeSpan.FromMinutes(1);
                    http.Response.Headers.RetryAfter = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds)).ToString();

                    var db = http.RequestServices.GetRequiredService<AppDbContext>();
                    var events = http.RequestServices.GetRequiredService<SecurityEventFactory>();
                    var time = http.RequestServices.GetRequiredService<TimeProvider>();
                    var route = (http.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText ?? "(no route)";
                    db.SecurityEvents.Add(events.Create(http, SecurityEventTypes.RateLimited, SecurityEventOutcome.Blocked,
                        time.GetUtcNow().UtcDateTime, reason: route));
                    await db.SaveChangesAsync(cancellationToken);
                    http.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("DevLink.Security")
                        .LogWarning("Auth.RateLimited {Route}", route);

                    var minutes = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalMinutes));
                    await AuthProblem.WriteAsync(http, StatusCodes.Status429TooManyRequests, AuthErrorCodes.RateLimited,
                        $"Too many requests. Please wait {minutes} minute{(minutes == 1 ? "" : "s")} and try again.");
                };
            });

            return services;
        }
    }
}
