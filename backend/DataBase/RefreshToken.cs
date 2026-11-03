namespace DataBase
{
    public static class RefreshTokenStatus
    {
        public const string Active = "Active";
        public const string Rotated = "Rotated";
        public const string Revoked = "Revoked";
    }

    // One row per refresh token ever issued. Rotation marks the old row Rotated and inserts a new one;
    // hashes are never overwritten, so a replayed old token is always recognised (M2_AUTH_DESIGN §3.4).
    public class RefreshToken
    {
        public long Id { get; set; }

        public Guid SessionId { get; set; }

        public AuthSession? Session { get; set; }

        // SHA-256 of the raw token; the raw token is never stored.
        public byte[] TokenHash { get; set; } = Array.Empty<byte>();

        public string Status { get; set; } = RefreshTokenStatus.Active;

        public DateTime CreatedAt { get; set; }

        public DateTime ExpiresAt { get; set; }

        public DateTime? ConsumedAt { get; set; }

        public DateTime? RevokedAt { get; set; }

        public long? ParentTokenId { get; set; }

        public long? ReplacedByTokenId { get; set; }
    }
}
