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

        // M2.7b: a token with the role; a tokenless request may pass through the development fallback with a
        // client-supplied id (design 7.3 case 1). Ownership is checked in the action.
        public const string MemberOrDevFallback = "MemberOrDevFallback";
        public const string NonAdminOrDevFallback = "NonAdminOrDevFallback";
        public const string CustomerOrDevFallback = "CustomerOrDevFallback";
        public const string ProgrammerOrDevFallback = "ProgrammerOrDevFallback";

        // Same, for routes that only name a resource (no client id to act as): case TokenlessRequest.
        public const string MemberResourceOrDevFallback = "MemberResourceOrDevFallback";
        public const string NonAdminResourceOrDevFallback = "NonAdminResourceOrDevFallback";
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
        public RoleOrDevFallbackRequirement(LegacyFallbackCase fallbackCase, params string[] roles)
        {
            FallbackCase = fallbackCase;
            Roles = roles;
        }

        public LegacyFallbackCase FallbackCase { get; }

        // Empty: any signed-in role.
        public IReadOnlyList<string> Roles { get; }
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
                if (requirement.Roles.Count == 0 || requirement.Roles.Any(context.User.IsInRole))
                {
                    context.Succeed(requirement);
                }
            }
            else if (context.Resource is HttpContext http &&
                     CurrentUser.IsTokenless(http) &&
                     // A route that also has a strict policy (suspend/unsuspend) refuses the request: not a fallback use.
                     !context.Requirements.OfType<DenyAnonymousAuthorizationRequirement>().Any() &&
                     _fallback.TryUse(http, requirement.FallbackCase))
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
                options.AddPolicy(AuthPolicies.AdminOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.TokenlessRequest, "Admin")));
                options.AddPolicy(AuthPolicies.MemberOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.IdentityFromClient)));
                options.AddPolicy(AuthPolicies.NonAdminOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.IdentityFromClient, "Customer", "Programmer")));
                options.AddPolicy(AuthPolicies.CustomerOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.IdentityFromClient, "Customer")));
                options.AddPolicy(AuthPolicies.ProgrammerOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.IdentityFromClient, "Programmer")));
                options.AddPolicy(AuthPolicies.MemberResourceOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.TokenlessRequest)));
                options.AddPolicy(AuthPolicies.NonAdminResourceOrDevFallback, policy => policy.AddRequirements(new RoleOrDevFallbackRequirement(LegacyFallbackCase.TokenlessRequest, "Customer", "Programmer")));
            });

            return services;
        }
    }
}
