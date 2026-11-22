using System.Security.Cryptography;
using DataBase;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Services.Auth;
using Services.Files;
using Services.Security;

namespace Controllers
{
    // ============================================================
    // Consumes a download link (M2_AUTH_DESIGN §5.1). The credential is
    // the single-use link plus the session's binding cookie, not an
    // access token, because the browser opens this as a plain URL.
    // Every failure gives the same answer, which reveals nothing.
    // ============================================================
    [Route("api/[controller]")]
    [ApiController]
    public class FilesController : ControllerBase
    {
        private const string ExpiredMessage = "This download link has expired. Please open the file again from DevLink.";

        private readonly AppDbContext _context;
        private readonly DownloadLinkStore _links;
        private readonly SecurityEventFactory _events;
        private readonly TimeProvider _time;

        public FilesController(AppDbContext context, DownloadLinkStore links, SecurityEventFactory events, TimeProvider time)
        {
            _context = context;
            _links = links;
            _events = events;
            _time = time;
        }

        [HttpGet("download")]
        [AllowAnonymous]
        public async Task<IActionResult> Download([FromQuery] string? t, CancellationToken cancellationToken)
        {
            // 1. Removed before any other check, so a link works at most once, even for two parallel requests.
            var link = string.IsNullOrEmpty(t) ? null : _links.Take(t);
            if (link == null)
            {
                return Expired();
            }

            // 2. Expiry from the record, never from the URL.
            var now = _time.GetUtcNow().UtcDateTime;
            if (now >= link.ExpiresAt)
            {
                return Expired();
            }

            // 3. The session is still active: a direct database read, not the cache.
            var session = await _context.AuthSessions.AsNoTracking()
                .Where(s => s.Id == link.RecipientSessionId && s.UserId == link.RecipientUserId && s.Status == AuthSessionStatus.Active)
                .Select(s => new { s.DownloadBindingHash })
                .FirstOrDefaultAsync(cancellationToken);
            if (session == null)
            {
                return Expired();
            }

            // 4. The recipient is still active and still allowed.
            var role = await _context.Users.AsNoTracking()
                .Where(u => u.Id == link.RecipientUserId && u.Status == UserStatus.Active)
                .Select(u => u.UserType)
                .FirstOrDefaultAsync(cancellationToken);
            if (role == null || !await ProgrammerDocuments.CanReadAsync(_context, link.ProgrammerUserId, link.RecipientUserId, role, cancellationToken))
            {
                return Expired();
            }

            // 5. The same browser that holds the session.
            var cookie = Request.Cookies[DownloadBindingCookie.Name];
            if (string.IsNullOrEmpty(cookie) || session.DownloadBindingHash == null ||
                !CryptographicOperations.FixedTimeEquals(DownloadBindingCookie.Hash(cookie), session.DownloadBindingHash))
            {
                return Expired();
            }

            // 6. The same version of the file.
            var (data, name) = await ProgrammerDocuments.LoadAsync(_context, link.ProgrammerUserId, link.Kind, cancellationToken);
            if (data == null || !CryptographicOperations.FixedTimeEquals(SHA256.HashData(data), link.ContentSha256))
            {
                return Expired();
            }

            _context.SecurityEvents.Add(_events.Create(HttpContext, SecurityEventTypes.FileDownloaded, SecurityEventOutcome.Success, now,
                link.RecipientUserId, link.RecipientSessionId, reason: $"{link.Kind}:{link.ProgrammerUserId}"));
            await _context.SaveChangesAsync(cancellationToken);

            return ProgrammerDocuments.Respond(this, link.Kind, data, name);
        }

        private ObjectResult Expired()
        {
            Response.Headers.CacheControl = "no-store, private";
            return AuthProblem.Result(HttpContext, StatusCodes.Status410Gone, AuthErrorCodes.LinkExpired, ExpiredMessage);
        }
    }
}
