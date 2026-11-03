using Microsoft.EntityFrameworkCore;

namespace DataBase
{
    // ============================================================
    // M2 security schema (migration AddAuthSecurity, M2_AUTH_DESIGN §3.4,
    // §6.2, §6.4). Kept apart from the partner's model configuration.
    // Security records are never cascade-deleted: every foreign key is
    // NO ACTION, so they must be revoked/cleaned up explicitly.
    // ============================================================
    public partial class AppDbContext
    {
        public DbSet<AuthSession> AuthSessions { get; set; }
        public DbSet<RefreshToken> RefreshTokens { get; set; }
        public DbSet<OneTimeCode> OneTimeCodes { get; set; }
        public DbSet<SecurityEvent> SecurityEvents { get; set; }

        // SQL Server default for SecurityStamp: a different random 32-hex value for every row,
        // including rows that already exist when the column is added.
        public const string SecurityStampDefaultSql = "lower(replace(convert(nvarchar(36), newid()), '-', ''))";

        private static void ConfigureAuthSecurity(ModelBuilder modelBuilder)
        {
            // ----- Users: new columns -----
            modelBuilder.Entity<User>(user =>
            {
                user.ToTable("Users", t => t.HasCheckConstraint(
                    "CK_Users_Status",
                    "[Status]='Suspended' OR [Status]='Active'"));

                user.Property(u => u.SecurityStamp)
                    .IsRequired()
                    .IsUnicode(false)
                    .HasMaxLength(64)
                    .HasDefaultValueSql(SecurityStampDefaultSql);

                user.HasIndex(u => u.SecurityStamp)
                    .IsUnique()
                    .HasDatabaseName("IX_Users_SecurityStamp");

                user.Property(u => u.Status)
                    .IsRequired()
                    .IsUnicode(false)
                    .HasMaxLength(16)
                    .HasDefaultValue(UserStatus.Active);

                user.Property(u => u.SuspendedReason)
                    .HasMaxLength(500);

                user.Property(u => u.FailedLoginCount)
                    .HasDefaultValue(0);

                user.Property(u => u.GoogleSubject)
                    .HasMaxLength(255);

                user.HasIndex(u => u.GoogleSubject)
                    .IsUnique()
                    .HasFilter("[GoogleSubject] IS NOT NULL")
                    .HasDatabaseName("IX_Users_GoogleSubject");
            });

            // ----- AuthSessions -----
            modelBuilder.Entity<AuthSession>(session =>
            {
                session.ToTable("AuthSessions", t =>
                {
                    t.HasCheckConstraint("CK_AuthSessions_ClientType", "[ClientType]='mobile' OR [ClientType]='web'");
                    t.HasCheckConstraint("CK_AuthSessions_Status", "[Status]='Expired' OR [Status]='Revoked' OR [Status]='Active'");
                });

                session.Property(s => s.Id).ValueGeneratedNever();
                session.Property(s => s.ClientType).IsRequired().IsUnicode(false).HasMaxLength(16);
                session.Property(s => s.Status).IsRequired().IsUnicode(false).HasMaxLength(16);
                session.Property(s => s.RevokeReason).IsUnicode(false).HasMaxLength(32);
                session.Property(s => s.DownloadBindingHash).HasMaxLength(32).IsFixedLength();

                session.HasIndex(s => new { s.UserId, s.Status })
                    .HasDatabaseName("IX_AuthSessions_User_Status");

                session.HasOne(s => s.User)
                    .WithMany()
                    .HasForeignKey(s => s.UserId)
                    .OnDelete(DeleteBehavior.NoAction)
                    .HasConstraintName("FK_AuthSessions_Users");
            });

            // ----- RefreshTokens -----
            modelBuilder.Entity<RefreshToken>(token =>
            {
                token.ToTable("RefreshTokens", t => t.HasCheckConstraint(
                    "CK_RefreshTokens_Status",
                    "[Status]='Revoked' OR [Status]='Rotated' OR [Status]='Active'"));

                token.Property(t => t.TokenHash).IsRequired().HasMaxLength(32).IsFixedLength();
                token.Property(t => t.Status).IsRequired().IsUnicode(false).HasMaxLength(16);

                token.HasIndex(t => t.TokenHash)
                    .IsUnique()
                    .HasDatabaseName("IX_RefreshTokens_TokenHash");

                token.HasIndex(t => new { t.SessionId, t.Status })
                    .HasDatabaseName("IX_RefreshTokens_Session_Status");

                // At most one active token per session, enforced by the database (§3.4).
                token.HasIndex(t => t.SessionId)
                    .IsUnique()
                    .HasFilter("[Status] = 'Active'")
                    .HasDatabaseName("IX_RefreshTokens_OneActivePerSession");

                token.HasOne(t => t.Session)
                    .WithMany(s => s.RefreshTokens)
                    .HasForeignKey(t => t.SessionId)
                    .OnDelete(DeleteBehavior.NoAction)
                    .HasConstraintName("FK_RefreshTokens_AuthSessions");

                token.HasOne<RefreshToken>()
                    .WithMany()
                    .HasForeignKey(t => t.ParentTokenId)
                    .OnDelete(DeleteBehavior.NoAction)
                    .HasConstraintName("FK_RefreshTokens_Parent");

                token.HasOne<RefreshToken>()
                    .WithMany()
                    .HasForeignKey(t => t.ReplacedByTokenId)
                    .OnDelete(DeleteBehavior.NoAction)
                    .HasConstraintName("FK_RefreshTokens_ReplacedBy");
            });

            // ----- OneTimeCodes -----
            modelBuilder.Entity<OneTimeCode>(code =>
            {
                code.ToTable("OneTimeCodes", t =>
                {
                    t.HasCheckConstraint("CK_OneTimeCodes_Purpose", "[Purpose]='Reset' OR [Purpose]='Signup'");
                    t.HasCheckConstraint("CK_OneTimeCodes_FailedAttempts", "[FailedAttempts]>=0");
                });

                code.Property(c => c.Purpose).IsRequired().IsUnicode(false).HasMaxLength(16);
                code.Property(c => c.EmailKey).IsRequired().HasMaxLength(32).IsFixedLength();
                code.Property(c => c.CodeHash).IsRequired().HasMaxLength(32).IsFixedLength();
                code.Property(c => c.ProofTokenHash).HasMaxLength(32).IsFixedLength();
                code.Property(c => c.FailedAttempts).HasDefaultValue(0);

                code.HasIndex(c => new { c.EmailKey, c.Purpose, c.CreatedAt })
                    .HasDatabaseName("IX_OneTimeCodes_Email_Purpose_Created");

                code.HasIndex(c => c.ProofTokenHash)
                    .IsUnique()
                    .HasFilter("[ProofTokenHash] IS NOT NULL")
                    .HasDatabaseName("IX_OneTimeCodes_ProofTokenHash");
            });

            // ----- SecurityEvents -----
            modelBuilder.Entity<SecurityEvent>(evt =>
            {
                evt.ToTable("SecurityEvents", t => t.HasCheckConstraint(
                    "CK_SecurityEvents_Outcome",
                    "[Outcome]='Blocked' OR [Outcome]='Failure' OR [Outcome]='Success'"));

                evt.Property(e => e.EventType).IsRequired().IsUnicode(false).HasMaxLength(64);
                evt.Property(e => e.Outcome).IsRequired().IsUnicode(false).HasMaxLength(16);
                evt.Property(e => e.TargetType).IsUnicode(false).HasMaxLength(32);
                evt.Property(e => e.TargetId).IsUnicode(false).HasMaxLength(64);
                evt.Property(e => e.EmailKey).IsUnicode(false).HasMaxLength(12).IsFixedLength();
                evt.Property(e => e.IpPrefix).IsUnicode(false).HasMaxLength(49);
                evt.Property(e => e.ClientType).IsUnicode(false).HasMaxLength(16);
                evt.Property(e => e.TraceId).IsUnicode(false).HasMaxLength(64);
                evt.Property(e => e.Details).HasMaxLength(1000);

                evt.HasIndex(e => e.OccurredAt)
                    .HasDatabaseName("IX_SecurityEvents_OccurredAt");

                evt.HasIndex(e => new { e.UserId, e.OccurredAt })
                    .HasDatabaseName("IX_SecurityEvents_User_OccurredAt");
            });
        }
    }
}
