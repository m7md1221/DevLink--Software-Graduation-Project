using DataBase.Models;
using Microsoft.EntityFrameworkCore;

namespace DataBase
{
    public class AppDbContext : DbContext
    {
        public DbSet<User> Users { get; set; }

        public DbSet<CustomerProfile> CustomerProfiles { get; set; }

        public DbSet<ProgrammerProfile> ProgrammerProfiles { get; set; }

        // ===== NEW: Social Feature =====
        public DbSet<Post> Posts { get; set; }
        public DbSet<PostImage> PostImages { get; set; }
        public DbSet<PostLike> PostLikes { get; set; }
        public DbSet<PostComment> PostComments { get; set; }
        public DbSet<SupportMessage> SupportMessages { get; set; }

        public AppDbContext(
            DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }

        protected override void OnModelCreating(
            ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // ============================================================
            // USER
            // ============================================================
            modelBuilder.Entity<User>()
                .ToTable("Users");

            modelBuilder.Entity<User>()
                .HasIndex(u => u.Email)
                .IsUnique();

            modelBuilder.Entity<User>()
                .Property(u => u.Email)
                .IsRequired();

            modelBuilder.Entity<User>()
                .Property(u => u.PasswordHash)
                .IsRequired();

            modelBuilder.Entity<User>()
                .Property(u => u.UserType)
                .IsRequired();

            // ============================================================
            // CUSTOMER PROFILE
            // ============================================================
            modelBuilder.Entity<CustomerProfile>()
                .ToTable("CustomerProfiles");

            modelBuilder.Entity<CustomerProfile>()
                .HasIndex(cp => cp.UserId)
                .IsUnique();

            modelBuilder.Entity<CustomerProfile>()
                .Property(cp => cp.Nickname)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<CustomerProfile>()
                .Property(cp => cp.Country)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<CustomerProfile>()
                .Property(cp => cp.City)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<CustomerProfile>()
                .Property(cp => cp.PhoneNumber)
                .IsRequired()
                .HasMaxLength(20);

            modelBuilder.Entity<CustomerProfile>()
                .Property(cp => cp.ImageContentType)
                .HasMaxLength(50);

            modelBuilder.Entity<CustomerProfile>()
                .HasOne(cp => cp.User)
                .WithOne(u => u.CustomerProfile)
                .HasForeignKey<CustomerProfile>(cp => cp.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // ============================================================
            // PROGRAMMER PROFILE
            // ============================================================
            modelBuilder.Entity<ProgrammerProfile>()
                .ToTable("ProgrammerProfiles");

            modelBuilder.Entity<ProgrammerProfile>()
                .HasIndex(pp => pp.UserId)
                .IsUnique();

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.Nickname)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.PhoneNumber)
                .IsRequired()
                .HasMaxLength(20);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.Country)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.City)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.Specialty)
                .IsRequired()
                .HasMaxLength(100);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.University)
                .IsRequired()
                .HasMaxLength(150);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.CertificateType)
                .HasMaxLength(50);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.CertificateName)
                .HasMaxLength(200);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.CVName)
                .HasMaxLength(200);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.LinkedInUrl)
                .HasMaxLength(300);

            modelBuilder.Entity<ProgrammerProfile>()
                .Property(pp => pp.ImageContentType)
                .HasMaxLength(50);

            modelBuilder.Entity<ProgrammerProfile>()
                .HasOne(pp => pp.User)
                .WithOne(u => u.ProgrammerProfile)
                .HasForeignKey<ProgrammerProfile>(pp => pp.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // ============================================================
            // POST
            // ============================================================
            modelBuilder.Entity<Post>()
                .ToTable("Posts");

            modelBuilder.Entity<Post>()
                .HasIndex(p => p.UserId);

            modelBuilder.Entity<Post>()
                .HasIndex(p => p.CreatedAt);

            modelBuilder.Entity<Post>()
                .HasIndex(p => p.IsDeleted);

            modelBuilder.Entity<Post>()
                .HasOne(p => p.User)
                .WithMany(u => u.Posts)
                .HasForeignKey(p => p.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // ============================================================
            // POST IMAGE
            // ============================================================
            modelBuilder.Entity<PostImage>()
                .ToTable("PostImages");

            modelBuilder.Entity<PostImage>()
                .HasIndex(i => i.PostId);

            modelBuilder.Entity<PostImage>()
                .HasOne(i => i.Post)
                .WithMany(p => p.Images)
                .HasForeignKey(i => i.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            // ============================================================
            // POST LIKE
            // ============================================================
            modelBuilder.Entity<PostLike>()
                .ToTable("PostLikes");

            modelBuilder.Entity<PostLike>()
                .HasIndex(l => new { l.PostId, l.UserId })
                .IsUnique();

            modelBuilder.Entity<PostLike>()
                .HasOne(l => l.Post)
                .WithMany(p => p.Likes)
                .HasForeignKey(l => l.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PostLike>()
                .HasOne(l => l.User)
                .WithMany(u => u.Likes)
                .HasForeignKey(l => l.UserId)
                .OnDelete(DeleteBehavior.NoAction);

            // ============================================================
            // POST COMMENT
            // ============================================================
            modelBuilder.Entity<PostComment>()
                .ToTable("PostComments");

            modelBuilder.Entity<PostComment>()
                .HasIndex(c => c.PostId);

            modelBuilder.Entity<PostComment>()
                .HasOne(c => c.Post)
                .WithMany(p => p.Comments)
                .HasForeignKey(c => c.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PostComment>()
                .HasOne(c => c.User)
                .WithMany(u => u.Comments)
                .HasForeignKey(c => c.UserId)
                .OnDelete(DeleteBehavior.NoAction);

            // ============================================================
            // SUPPORT MESSAGE
            // ============================================================
            modelBuilder.Entity<SupportMessage>()
                .ToTable("SupportMessages");

            modelBuilder.Entity<SupportMessage>()
                .HasIndex(sm => sm.UserId);

            modelBuilder.Entity<SupportMessage>()
                .HasIndex(sm => sm.Status);

            modelBuilder.Entity<SupportMessage>()
                .HasOne(sm => sm.User)
                .WithMany()
                .HasForeignKey(sm => sm.UserId)
                .OnDelete(DeleteBehavior.SetNull);
        }
    }
}