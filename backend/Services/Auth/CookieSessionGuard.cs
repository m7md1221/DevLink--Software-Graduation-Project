using DataBase;
using Microsoft.Extensions.Options;
using Services.Security;

namespace Services.Auth
{
    public enum ClientMode
    {
        // No X-DevLink-Client header: today's Flutter app. Never receives or sends the refresh cookie.
        Legacy,
        Web,
        Mobile
    }

    public sealed record CsrfCheckResult(bool Allowed, ClientMode Mode, string? Reason = null);

    // ============================================================
    // CSRF guard for every request that reads or sets the refresh cookie
    // (M2_AUTH_DESIGN §4.2). Web mode requires, all together:
    //   1. Origin (or, if absent, the Referer's origin) exactly in Cors:AllowedOrigins;
    //   2. X-DevLink-Client: web (a custom header forces a CORS preflight);
    //   3. Content-Type: application/json (also non-simple);
    //   4. Sec-Fetch-Site, when sent, is same-origin or same-site.
    // SameSite=Strict on the cookie is the fifth layer.
    // Mobile mode never touches the cookie.
    // ============================================================
    public class CookieSessionGuard
    {
        private readonly HashSet<string> _allowedOrigins;

        public CookieSessionGuard(IOptions<CorsSettings> cors)
        {
            _allowedOrigins = cors.Value.AllowedOrigins
                .Select(CorsSettingsValidator.Normalize)
                .ToHashSet(StringComparer.Ordinal);
        }

        public static ClientMode ModeOf(HttpRequest request)
        {
            var header = request.Headers[CorsSetup.ClientHeader].ToString();
            return header switch
            {
                AuthClientType.Web => ClientMode.Web,
                AuthClientType.Mobile => ClientMode.Mobile,
                "" => ClientMode.Legacy,
                _ => (ClientMode)(-1)
            };
        }

        public CsrfCheckResult Check(HttpRequest request)
        {
            var mode = ModeOf(request);
            if (mode is ClientMode.Mobile or ClientMode.Legacy)
            {
                return new CsrfCheckResult(true, mode);
            }

            if (mode != ClientMode.Web)
            {
                return new CsrfCheckResult(false, mode, "UnknownClientHeader");
            }

            var origin = request.Headers.Origin.ToString();
            if (string.IsNullOrEmpty(origin) || origin == "null")
            {
                var referer = request.Headers.Referer.ToString();
                if (!Uri.TryCreate(referer, UriKind.Absolute, out var refererUri))
                {
                    return new CsrfCheckResult(false, mode, origin == "null" ? "NullOrigin" : "MissingOrigin");
                }

                origin = refererUri.GetLeftPart(UriPartial.Authority);
            }

            string normalized;
            try
            {
                normalized = CorsSettingsValidator.Normalize(origin);
            }
            catch (UriFormatException)
            {
                return new CsrfCheckResult(false, mode, "InvalidOrigin");
            }

            if (!_allowedOrigins.Contains(normalized))
            {
                return new CsrfCheckResult(false, mode, "OriginNotAllowed");
            }

            if (!string.Equals(request.ContentType?.Split(';')[0].Trim(), "application/json", StringComparison.OrdinalIgnoreCase))
            {
                return new CsrfCheckResult(false, mode, "ContentType");
            }

            var fetchSite = request.Headers["Sec-Fetch-Site"].ToString();
            if (fetchSite.Length > 0 && fetchSite is not ("same-origin" or "same-site"))
            {
                return new CsrfCheckResult(false, mode, "FetchSite");
            }

            return new CsrfCheckResult(true, mode);
        }
    }
}
