using System.Net;
using Microsoft.Extensions.Options;

namespace Services.Auth
{
    public enum LegacyFallbackCase
    {
        IdentityFromClient,
        // Owner decision D-1 (M2.7): a tokenless request to a role-protected route behaves as before.
        TokenlessRequest,
        SignupResetWithoutProof,
        FileWithoutToken,
        ImageWithoutSignature
    }

    // ============================================================
    // The temporary development fallback (binding condition C1, §7.3):
    // allowed only when ALL hold — Development environment, the switch
    // explicitly disabled (Auth:EnforceAuthorization=false), and a
    // loopback client. Every use is logged with the case and route
    // template only. Deleted in M2.13 together with the switch.
    // ============================================================
    public class LegacyFallback
    {
        private readonly AuthEnforcementOptions _options;
        private readonly IHostEnvironment _environment;
        private readonly ILogger _logger;

        public LegacyFallback(IOptions<AuthEnforcementOptions> options, IHostEnvironment environment, ILoggerFactory loggers)
        {
            _options = options.Value;
            _environment = environment;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        public bool TryUse(HttpContext context, LegacyFallbackCase fallbackCase)
        {
            if (_options.Enforced || !_environment.IsDevelopment())
            {
                return false;
            }

            var route = (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText ?? "(no route)";
            var remote = context.Connection.RemoteIpAddress;
            if (remote?.IsIPv4MappedToIPv6 == true)
            {
                remote = remote.MapToIPv4();
            }

            if (remote == null || !IPAddress.IsLoopback(remote))
            {
                _logger.LogWarning("Auth.DevFallbackRefused {Case} {Route} (non-loopback client)", fallbackCase, route);
                return false;
            }

            // The policy and ICurrentUser both ask: one log line per request and case.
            var logged = $"DevLink.DevFallbackLogged.{fallbackCase}";
            if (!context.Items.ContainsKey(logged))
            {
                context.Items[logged] = true;
                _logger.LogWarning("Auth.DevFallbackUsed {Case} {Route}", fallbackCase, route);
            }

            return true;
        }
    }
}
