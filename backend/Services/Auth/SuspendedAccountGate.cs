using DataBase;

namespace Services.Auth
{
    // Marks endpoints a suspended account may still use: the suspension notice, support/appeal, sign-out (§7.4, Q5).
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public sealed class AllowSuspendedAttribute : Attribute
    {
    }

    // ============================================================
    // Restricted mode (M2_AUTH_DESIGN §7.4). A request whose token is
    // valid but whose account is Suspended may only reach [AllowSuspended]
    // endpoints; everything else gets 403 ACCOUNT_SUSPENDED. Requests
    // without a token are not affected (existing endpoints stay anonymous
    // until M2.7).
    // ============================================================
    public static class SuspendedAccountGate
    {
        public static IApplicationBuilder UseDevLinkSuspendedAccountGate(this IApplicationBuilder app)
        {
            return app.Use(async (context, next) =>
            {
                if (context.User.Identity?.IsAuthenticated == true &&
                    context.Items[AuthHttpItems.UserStatus] as string == UserStatus.Suspended &&
                    context.GetEndpoint()?.Metadata.GetMetadata<AllowSuspendedAttribute>() == null)
                {
                    context.RequestServices.GetRequiredService<ILoggerFactory>()
                        .CreateLogger("DevLink.Security")
                        .LogInformation("Authz.SuspendedBlocked {Route}",
                            (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText ?? "(no route)");

                    await AuthProblem.WriteAsync(
                        context,
                        StatusCodes.Status403Forbidden,
                        AuthErrorCodes.AccountSuspended,
                        "Your account is suspended. You can contact support or sign out.");
                    return;
                }

                await next();
            });
        }
    }
}
