namespace DataBase
{
    public static class AuthSessionStatus
    {
        public const string Active = "Active";
        public const string Revoked = "Revoked";
        public const string Expired = "Expired";
    }

    public static class AuthClientType
    {
        public const string Web = "web";
        public const string Mobile = "mobile";
    }

    // One sign-in on one browser or device: a refresh-token family. Id is the "sid" claim (M2_AUTH_DESIGN §3.4).
    public class AuthSession
    {
        public Guid Id { get; set; }

        public int UserId { get; set; }

        public User? User { get; set; }

        public string ClientType { get; set; } = AuthClientType.Web;

        public string Status { get; set; } = AuthSessionStatus.Active;

        public DateTime CreatedAt { get; set; }

        public DateTime LastRefreshedAt { get; set; }

        public DateTime AbsoluteExpiresAt { get; set; }

        public DateTime? RevokedAt { get; set; }

        public string? RevokeReason { get; set; }

        // SHA-256 of the web download-binding cookie (§5.1); null for mobile sessions.
        public byte[]? DownloadBindingHash { get; set; }

        public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    }
}
