using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Policy;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using Services.Auth;
using Services.Security;

namespace Services.Files
{
    // ============================================================
    // Signed image URLs (M2_AUTH_DESIGN §5.2, C5). The signature names
    // one image and one expiry. Expiry falls on 10-minute buckets, so
    // every URL for an image is identical within a window and browser
    // caches keep working; a URL stays valid for 10 to 20 minutes.
    // ============================================================
    public class MediaUrlSigner
    {
        private const string Avatar = "avatar";
        private const string PostImage = "postimage";
        private const long BucketSeconds = 600;
        private const long ValiditySeconds = 1200;

        private readonly byte[] _key;
        private readonly TimeProvider _time;

        public MediaUrlSigner(IOptions<SecurityKeysOptions> options, TimeProvider time)
        {
            _key = Convert.FromBase64String(options.Value.MediaUrlKey.Trim());
            _time = time;
        }

        public string AvatarPath(int userId) => Path($"/api/Posts/user/{userId}/avatar", Avatar, userId);

        public string PostImagePath(int imageId) => Path($"/api/Posts/image/{imageId}", PostImage, imageId);

        public bool VerifyAvatar(int userId, string? exp, string? sig) => Verify(Avatar, userId, exp, sig);

        public bool VerifyPostImage(int imageId, string? exp, string? sig) => Verify(PostImage, imageId, exp, sig);

        private string Path(string path, string kind, int id)
        {
            var now = _time.GetUtcNow().ToUnixTimeSeconds();
            var exp = now / BucketSeconds * BucketSeconds + ValiditySeconds;
            return $"{path}?exp={exp.ToString(CultureInfo.InvariantCulture)}&sig={WebEncoders.Base64UrlEncode(Sign(kind, id, exp))}";
        }

        private byte[] Sign(string kind, int id, long exp) =>
            HMACSHA256.HashData(_key, Encoding.UTF8.GetBytes(string.Create(CultureInfo.InvariantCulture, $"{kind}|{id}|{exp}")));

        private bool Verify(string kind, int id, string? exp, string? sig)
        {
            if (string.IsNullOrEmpty(sig) || !long.TryParse(exp, NumberStyles.None, CultureInfo.InvariantCulture, out var expiry))
            {
                return false;
            }

            byte[] given;
            try
            {
                given = WebEncoders.Base64UrlDecode(sig);
            }
            catch (FormatException)
            {
                return false;
            }

            // The signature is checked first, and in fixed time, so a forged expiry reveals nothing.
            return CryptographicOperations.FixedTimeEquals(given, Sign(kind, id, expiry)) &&
                   _time.GetUtcNow().ToUnixTimeSeconds() < expiry;
        }
    }

    // The image URLs an API response carries. Signed for a signed-in caller; the unsigned path only reaches
    // a tokenless caller, which can use it only through the development fallback (design 7.3 case 4).
    public class MediaUrls
    {
        private readonly MediaUrlSigner _signer;
        private readonly ICurrentUser _currentUser;

        public MediaUrls(MediaUrlSigner signer, ICurrentUser currentUser)
        {
            _signer = signer;
            _currentUser = currentUser;
        }

        public string AvatarUrl(int userId) =>
            _currentUser.IsAuthenticated ? _signer.AvatarPath(userId) : $"/api/Posts/user/{userId}/avatar";

        public string PostImageUrl(int imageId) =>
            _currentUser.IsAuthenticated ? _signer.PostImagePath(imageId) : $"/api/Posts/image/{imageId}";
    }

    public sealed class SignedImageRequirement : IAuthorizationRequirement
    {
    }

    // A signature decides on its own when one is present. Otherwise: an access token, or a tokenless request on the
    // development fallback. What each kind of caller may see is checked in the action.
    public sealed class SignedImageHandler : AuthorizationHandler<SignedImageRequirement>
    {
        public const string VerifiedItem = "DevLink.SignedImage.Verified";
        public const string RefusedItem = "DevLink.SignedImage.Refused";

        private readonly MediaUrlSigner _signer;
        private readonly LegacyFallback _fallback;

        public SignedImageHandler(MediaUrlSigner signer, LegacyFallback fallback)
        {
            _signer = signer;
            _fallback = fallback;
        }

        protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, SignedImageRequirement requirement)
        {
            if (context.Resource is not HttpContext http)
            {
                return Task.CompletedTask;
            }

            var query = http.Request.Query;
            if (query.ContainsKey("sig") || query.ContainsKey("exp"))
            {
                if (IsValid(http, query["exp"], query["sig"]))
                {
                    http.Items[VerifiedItem] = true;
                    context.Succeed(requirement);
                }
                else
                {
                    http.Items[RefusedItem] = true;
                }
            }
            else if (context.User.Identity?.IsAuthenticated == true ||
                     (CurrentUser.IsTokenless(http) && _fallback.TryUse(http, LegacyFallbackCase.ImageWithoutSignature)))
            {
                context.Succeed(requirement);
            }

            return Task.CompletedTask;
        }

        private bool IsValid(HttpContext http, string? exp, string? sig)
        {
            var route = http.Request.RouteValues;
            if (int.TryParse(route["imageId"]?.ToString(), out var imageId))
            {
                return _signer.VerifyPostImage(imageId, exp, sig);
            }

            return int.TryParse(route["userId"]?.ToString(), out var userId) && _signer.VerifyAvatar(userId, exp, sig);
        }
    }

    // An expired or tampered signature is a refusal, not a request to sign in (T-IM-03, T-IM-04).
    public sealed class SignedImageResultHandler : IAuthorizationMiddlewareResultHandler
    {
        private readonly AuthorizationMiddlewareResultHandler _default = new();

        public Task HandleAsync(RequestDelegate next, HttpContext context, AuthorizationPolicy policy, PolicyAuthorizationResult authorizeResult)
        {
            if (!authorizeResult.Succeeded && context.Items.ContainsKey(SignedImageHandler.RefusedItem))
            {
                return AuthProblem.WriteAsync(context, StatusCodes.Status403Forbidden, AuthErrorCodes.Forbidden, "This image link is no longer valid.");
            }

            return _default.HandleAsync(next, context, policy, authorizeResult);
        }
    }

    public static class ImageResponse
    {
        // Served only as an allowed image type, from the stored bytes; never public, never sniffable.
        public static IActionResult From(ControllerBase controller, byte[]? data, string notFoundMessage)
        {
            var type = data == null ? null : UploadValidator.SniffImage(data);
            if (type == null)
            {
                return controller.NotFound(new { message = notFoundMessage });
            }

            controller.Response.Headers.CacheControl = "private, max-age=3600";
            return controller.File(data!, type);
        }
    }
}
