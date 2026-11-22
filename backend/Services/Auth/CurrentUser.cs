using Microsoft.IdentityModel.JsonWebTokens;

namespace Services.Auth
{
    // The signed-in caller, taken only from a validated access token (M2_AUTH_DESIGN §7.1–7.2).
    public interface ICurrentUser
    {
        bool IsAuthenticated { get; }

        int? UserId { get; }

        string? Role { get; }

        bool IsAdmin { get; }

        // The caller's id from the token; a client-supplied id is used ONLY for a tokenless
        // request on the development fallback (C1, case IdentityFromClient). Otherwise null.
        int? ResolveUserId(int? clientSuppliedId);
    }

    public class CurrentUser : ICurrentUser
    {
        private readonly IHttpContextAccessor _accessor;
        private readonly LegacyFallback _fallback;

        public CurrentUser(IHttpContextAccessor accessor, LegacyFallback fallback)
        {
            _accessor = accessor;
            _fallback = fallback;
        }

        private HttpContext? Http => _accessor.HttpContext;

        public bool IsAuthenticated => Http?.User.Identity?.IsAuthenticated == true;

        public int? UserId => IsAuthenticated && int.TryParse(Http!.User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id) ? id : null;

        public string? Role => IsAuthenticated ? Http!.User.FindFirst(AuthClaims.Role)?.Value : null;

        public bool IsAdmin => Role == "Admin";

        public int? ResolveUserId(int? clientSuppliedId)
        {
            if (IsAuthenticated)
            {
                return UserId;
            }

            return Http != null && IsTokenless(Http) && clientSuppliedId != null &&
                   _fallback.TryUse(Http, LegacyFallbackCase.IdentityFromClient)
                ? clientSuppliedId
                : null;
        }

        // No Authorization header at all. A request with an invalid or revoked token is NOT tokenless:
        // it never reaches a fallback path.
        public static bool IsTokenless(HttpContext http) => http.Request.Headers.Authorization.Count == 0;
    }
}
