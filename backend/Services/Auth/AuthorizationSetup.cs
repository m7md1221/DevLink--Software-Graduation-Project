using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;

namespace Services.Auth
{
    public static class AuthPolicies
    {
        // Strict: an Admin access token, never the development fallback (M2.5b routes).
        public const string AdminOnly = "AdminOnly";

        // An Admin access token; a request WITHOUT a token may still pass through the
        // development fallback (owner decision D-1, removed in M2.13).
        public const string AdminOrDevFallback = "AdminOrDevFallback";
    }

    // ============================================================
    // Role policies (M2.7, M2_AUTH_DESIGN §7.1). The role always comes
    // from the access token; client-sent ids and `isAdmin` are never
    // consulted. A tokenless request passes a fallback-enabled policy
    // only through LegacyFallback (Development + switch off + loopback,
    // logged); a request that carries a token never falls back.
    // ============================================================
    public sealed class RoleOrDevFallbackRequirement : IAuthorizationRequirement
    {
        public RoleOrDevFallbackRequirement(string role)
        {
            Role = role;
        }

        public string Role { get; }
    }

    public sealed class RoleOrDevFallbackHandler : AuthorizationHandler<RoleOrDevFallbackRequirement>
    {
        private readonly LegacyFallback _fallback;

        public RoleOrDevFallbackHandler(LegacyFallback fallback)
        {
            _fallback = fallback;
        }

        protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, RoleOrDevFallbackRequirement requirement)
        {
            if (context.User.Identity?.IsAuthenticated == true)
            {
                if (context.User.IsInRole(requirement.Role))
                {
                    context.Succeed(requirement);
                }
            }
            else if (context.Resource is HttpContext http &&
                     CurrentUser.IsTokenless(http) &&
                     // A route that also has a strict policy (suspend/unsuspend) refuses the request: not a fallback use.
                     !context.Requirements.OfType<DenyAnonymousAuthorizationRequirement>().Any() &&
                     _fallback.TryUse(http, LegacyFallbackCase.TokenlessRequest))
            {
                context.Succeed(requirement);
            }

            return Task.CompletedTask;
        }
    }

    public static class AuthorizationSetup
    {
        public static IServiceCollection AddDevLinkAuthorization(this IServiceCollection services)
        {
            services.AddHttpContextAccessor();
            services.AddScoped<ICurrentUser, CurrentUser>();
            services.AddSingleton<IAuthorizationHandler, RoleOrDevFallbackHandler>();

            // Only routes that carry these attributes are protected before M2.7d adds the fail-closed default.
            services.AddAuthorization(options =>
            {
                options.AddPolicy(AuthPolicies.AdminOnly, policy => policy.RequireAuthenticatedUser().RequireRole("Admin"));
                options.AddPolicy(AuthPolicies.AdminOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement("Admin")));
            });

            return services;
        }
    }
}
