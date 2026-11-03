using System.Security.Cryptography;
using DataBase.Models;

namespace DataBase
{
    public static class UserStatus
    {
        public const string Active = "Active";
        public const string Suspended = "Suspended";
    }

    public class User
    {
        public int Id { get; set; }

        public string Email { get; set; }

        public string PasswordHash { get; set; }

        public string UserType { get; set; }

        // ===== M2 (migration AddAuthSecurity): session security and account state =====

        // Random per user; rotating it invalidates every access token (M2_AUTH_DESIGN §3.6).
        public string SecurityStamp { get; set; } = NewSecurityStamp();

        public string Status { get; set; } = UserStatus.Active;

        public string? SuspendedReason { get; set; }

        public DateTime? SuspendedAt { get; set; }

        public int FailedLoginCount { get; set; }

        public DateTime? LockoutEndAt { get; set; }

        // Google account id ("sub"); accounts are matched on this, never on email (Q11).
        public string? GoogleSubject { get; set; }

        public DateTime? LastLoginAt { get; set; }

        public static string NewSecurityStamp() =>
            Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();

        public CustomerProfile? CustomerProfile { get; set; }

        public ProgrammerProfile? ProgrammerProfile { get; set; }

        public ICollection<Post> Posts { get; set; } = new List<Post>();
        public ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
        public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
        public ICollection<PostApplication> Applications { get; set; } = new List<PostApplication>();
    }
}