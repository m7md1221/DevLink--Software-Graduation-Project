using System.Text;

namespace Services.Files
{
    // ============================================================
    // What may be stored and served (M2.8). The type always comes from
    // the file's first bytes; the name and type the client sends are
    // never trusted. SVG, HTML and anything else without an allowed
    // signature is refused.
    // ============================================================
    public static class UploadValidator
    {
        public const long MaxAvatarBytes = 2 * 1024 * 1024;
        public const long MaxPostImageBytes = 5 * 1024 * 1024;
        public const long MaxDocumentBytes = 5 * 1024 * 1024;
        public const int MaxFileNameLength = 100;

        public const string Jpeg = "image/jpeg";
        public const string Png = "image/png";
        public const string Webp = "image/webp";
        public const string Pdf = "application/pdf";

        private static readonly string[] ImageExtensions = { ".jpg", ".jpeg", ".png", ".webp" };

        public static string? SniffImage(ReadOnlySpan<byte> data)
        {
            if (data.StartsWith(new byte[] { 0xFF, 0xD8, 0xFF })) return Jpeg;
            if (data.StartsWith(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })) return Png;
            if (data.Length >= 12 && data.StartsWith("RIFF"u8) && data.Slice(8, 4).SequenceEqual("WEBP"u8)) return Webp;
            return null;
        }

        public static bool IsPdf(ReadOnlySpan<byte> data) => data.StartsWith("%PDF-"u8);

        // PDF, PNG or JPEG; null for anything else.
        public static string? SniffCertificate(ReadOnlySpan<byte> data)
        {
            if (IsPdf(data)) return Pdf;
            var image = SniffImage(data);
            return image == Webp ? null : image;
        }

        // Avatars and post images. A name without an extension is fine (web pickers send "blob"); any other extension is not.
        public static async Task<(byte[] Data, string ContentType)?> ReadImageAsync(IFormFile file)
        {
            var extension = Path.GetExtension(file.FileName ?? "").ToLowerInvariant();
            if (extension.Length > 0 && !ImageExtensions.Contains(extension))
            {
                return null;
            }

            var data = await ReadAsync(file);
            var type = SniffImage(data);
            return type == null ? null : (data, type);
        }

        public static async Task<byte[]?> ReadCvAsync(IFormFile file)
        {
            if (!string.Equals(Path.GetExtension(file.FileName ?? ""), ".pdf", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            var data = await ReadAsync(file);
            return IsPdf(data) ? data : null;
        }

        // The extension and the bytes must agree.
        public static async Task<(byte[] Data, string ContentType)?> ReadCertificateAsync(IFormFile file)
        {
            var expected = Path.GetExtension(file.FileName ?? "").ToLowerInvariant() switch
            {
                ".pdf" => Pdf,
                ".png" => Png,
                ".jpg" or ".jpeg" => Jpeg,
                _ => null
            };
            if (expected == null)
            {
                return null;
            }

            var data = await ReadAsync(file);
            return SniffCertificate(data) == expected ? (data, expected) : null;
        }

        // Only the last path segment, without control characters or characters that are unsafe in a header or a file system.
        public static string SafeFileName(string? name, string fallback)
        {
            var last = (name ?? "").Replace('\\', '/').Split('/').Last();
            var safe = new StringBuilder(last.Length);
            foreach (var c in last)
            {
                if (!char.IsControl(c) && !"\"<>:|?*;%".Contains(c) && char.GetUnicodeCategory(c) != System.Globalization.UnicodeCategory.Format)
                {
                    safe.Append(c);
                }
            }

            var cleaned = safe.ToString().Trim().Trim('.').Trim();
            if (cleaned.Length == 0)
            {
                return fallback;
            }

            if (cleaned.Length <= MaxFileNameLength)
            {
                return cleaned;
            }

            var extension = Path.GetExtension(cleaned);
            if (extension.Length > 10)
            {
                extension = "";
            }

            return cleaned[..(MaxFileNameLength - extension.Length)].TrimEnd() + extension;
        }

        // The served name always ends with the extension of the type actually served.
        public static string DownloadName(string? stored, string contentType)
        {
            var extension = contentType switch
            {
                Pdf => ".pdf",
                Png => ".png",
                Jpeg => ".jpg",
                _ => ".bin"
            };

            var name = SafeFileName(stored, "document" + extension);
            var current = Path.GetExtension(name).ToLowerInvariant();
            if (current == extension || (extension == ".jpg" && current == ".jpeg"))
            {
                return name;
            }

            var stem = Path.GetFileNameWithoutExtension(name);
            if (stem.Length + extension.Length > MaxFileNameLength)
            {
                stem = stem[..(MaxFileNameLength - extension.Length)];
            }

            return (stem.Length == 0 ? "document" : stem) + extension;
        }

        private static async Task<byte[]> ReadAsync(IFormFile file)
        {
            using var stream = new MemoryStream();
            await file.CopyToAsync(stream);
            return stream.ToArray();
        }
    }
}
