namespace DataBase
{
    public static class OneTimeCodePurpose
    {
        public const string Signup = "Signup";
        public const string Reset = "Reset";
    }

    // A sign-up or reset code, stored only as keyed hashes; the email itself is not stored (M2_AUTH_DESIGN §6.2, Q7).
    public class OneTimeCode
    {
        public long Id { get; set; }

        public string Purpose { get; set; } = OneTimeCodePurpose.Signup;

        // HMAC-SHA256 of the normalized email.
        public byte[] EmailKey { get; set; } = Array.Empty<byte>();

        // HMAC-SHA256 of purpose, email key and code.
        public byte[] CodeHash { get; set; } = Array.Empty<byte>();

        public DateTime CreatedAt { get; set; }

        public DateTime ExpiresAt { get; set; }

        public int FailedAttempts { get; set; }

        public DateTime? ConsumedAt { get; set; }

        public DateTime? InvalidatedAt { get; set; }

        public byte[]? ProofTokenHash { get; set; }

        public DateTime? ProofExpiresAt { get; set; }

        public DateTime? ProofConsumedAt { get; set; }
    }
}
