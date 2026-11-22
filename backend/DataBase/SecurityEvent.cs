namespace DataBase
{
    public static class SecurityEventOutcome
    {
        public const string Success = "Success";
        public const string Failure = "Failure";
        public const string Blocked = "Blocked";
    }

    // Append-only security audit record (M2_AUTH_DESIGN §6.4, Q8, R3). Never holds passwords, tokens,
    // token hashes, codes, keys or full emails. No FK to Users, so events outlive deleted accounts.
    public class SecurityEvent
    {
        public long Id { get; set; }

        public DateTime OccurredAt { get; set; }

        public string EventType { get; set; } = "";

        public string Outcome { get; set; } = SecurityEventOutcome.Success;

        public int? UserId { get; set; }

        public int? ActorUserId { get; set; }

        public Guid? SessionId { get; set; }

        public string? TargetType { get; set; }

        public string? TargetId { get; set; }

        // First 12 hex characters of a salted SHA-256 of the normalized email.
        public string? EmailKey { get; set; }

        // Truncated network prefix (IPv4 /24, IPv6 /48), only for abuse-relevant events; nulled after 14 days (R3).
        public string? IpPrefix { get; set; }

        public string? ClientType { get; set; }

        public string? TraceId { get; set; }

        public string? Details { get; set; }
    }
}
