using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using DataBase;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;

namespace Services.Files
{
    public static class DocumentKinds
    {
        public const string Cv = "cv";
        public const string Certificate = "certificate";
    }

    public sealed record DownloadLink(
        int ProgrammerUserId,
        string Kind,
        byte[] ContentSha256,
        int RecipientUserId,
        Guid RecipientSessionId,
        DateTime IssuedAt,
        DateTime ExpiresAt);

    // ============================================================
    // CV and certificate links (M2_AUTH_DESIGN §5.1): 256-bit, single
    // use, 60 seconds. Kept in memory under SHA-256(token), so the raw
    // token is never stored. Single instance only (§3.7).
    // ============================================================
    public class DownloadLinkStore
    {
        public static readonly TimeSpan Lifetime = TimeSpan.FromSeconds(60);
        public const int MaxPerTenMinutes = 20;
        public const int MaxPerDay = 100;

        private readonly ConcurrentDictionary<string, DownloadLink> _links = new();
        private readonly ConcurrentDictionary<int, List<DateTime>> _issues = new();

        public string Add(DownloadLink link)
        {
            foreach (var expired in _links.Where(kv => kv.Value.ExpiresAt <= link.IssuedAt).Select(kv => kv.Key).ToList())
            {
                _links.TryRemove(expired, out _);
            }

            var token = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
            _links[KeyOf(token)] = link;
            return token;
        }

        // Atomic: of two parallel requests, exactly one gets the record.
        public DownloadLink? Take(string token) =>
            _links.TryRemove(KeyOf(token), out var link) ? link : null;

        // Counts one issuance; false when the user is over 20 per 10 minutes or 100 per day.
        public bool TryCountIssue(int userId, DateTime now)
        {
            var issues = _issues.GetOrAdd(userId, _ => new List<DateTime>());
            lock (issues)
            {
                issues.RemoveAll(at => at <= now - TimeSpan.FromDays(1));
                if (issues.Count >= MaxPerDay || issues.Count(at => at > now - TimeSpan.FromMinutes(10)) >= MaxPerTenMinutes)
                {
                    return false;
                }

                issues.Add(now);
                return true;
            }
        }

        private static string KeyOf(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    }

    // Created when a web session starts; only its hash is stored (AuthSessions.DownloadBindingHash). The browser sends it
    // only to /api/Files, so a link copied to another browser fails even within its 60 seconds (§5.1 check 5).
    public static class DownloadBindingCookie
    {
        public const string Name = "devlink_fb";
        public const string Path = "/api/Files";

        public static string NewValue() => WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));

        public static byte[] Hash(string value) => SHA256.HashData(Encoding.UTF8.GetBytes(value));

        public static void Append(HttpResponse response, string value, TimeSpan lifetime)
        {
            response.Cookies.Append(Name, value, new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Path = Path,
                MaxAge = lifetime,
                IsEssential = true
            });
        }

        public static void Delete(HttpResponse response)
        {
            response.Cookies.Delete(Name, new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Path = Path
            });
        }
    }

    public static class ProgrammerDocuments
    {
        // Design 8 #27: the programmer, an admin, or a customer whose post the programmer applied to.
        public static async Task<bool> CanReadAsync(AppDbContext db, int programmerId, int userId, string? role, CancellationToken cancellationToken = default)
        {
            return userId == programmerId || role == "Admin" ||
                   (role == "Customer" && await db.PostApplications.AnyAsync(
                       a => a.ProgrammerId == programmerId && a.Post!.UserId == userId, cancellationToken));
        }

        public static async Task<(byte[]? Data, string? Name)> LoadAsync(AppDbContext db, int programmerId, string kind, CancellationToken cancellationToken = default)
        {
            var query = db.ProgrammerProfiles.AsNoTracking().Where(p => p.UserId == programmerId);
            if (kind == DocumentKinds.Cv)
            {
                var cv = await query.Select(p => new { p.CV, p.CVName }).FirstOrDefaultAsync(cancellationToken);
                return (cv?.CV, cv?.CVName);
            }

            var certificate = await query.Select(p => new { p.Certificate, p.CertificateName }).FirstOrDefaultAsync(cancellationToken);
            return (certificate?.Certificate, certificate?.CertificateName);
        }

        // Always a download, never rendered, so a stored HTML or SVG "document" can't run script. Type from the bytes (§5.1).
        public static IActionResult Respond(ControllerBase controller, string kind, byte[] data, string? storedName)
        {
            var type = kind == DocumentKinds.Cv
                ? UploadValidator.Pdf
                : UploadValidator.SniffCertificate(data) ?? "application/octet-stream";

            var headers = controller.Response.Headers;
            headers.CacheControl = "no-store, private";
            headers.Pragma = "no-cache";
            headers.Expires = "0";

            return controller.File(data, type, UploadValidator.DownloadName(storedName, type));
        }
    }

    public static class FilesSetup
    {
        public static IServiceCollection AddDevLinkFiles(this IServiceCollection services)
        {
            services.AddSingleton<DownloadLinkStore>();
            services.AddSingleton<MediaUrlSigner>();
            services.AddScoped<MediaUrls>();
            return services;
        }
    }
}
