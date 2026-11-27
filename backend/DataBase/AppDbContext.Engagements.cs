using DataBase.Models;
using Microsoft.EntityFrameworkCore;

namespace DataBase
{
    public partial class AppDbContext
    {
        public DbSet<Engagement> Engagements { get; set; }
        public DbSet<EngagementCriterion> EngagementCriteria { get; set; }
        public DbSet<EngagementDelivery> EngagementDeliveries { get; set; }
        public DbSet<EngagementDeliveryItem> EngagementDeliveryItems { get; set; }
        public DbSet<EngagementEvent> EngagementEvents { get; set; }

        private static void ConfigureEngagements(ModelBuilder modelBuilder)
        {
            var engagement = modelBuilder.Entity<Engagement>();
            engagement.ToTable("Engagements");
            engagement.HasIndex(e => e.PostId).IsUnique();
            engagement.HasIndex(e => e.ApplicationId).IsUnique();
            engagement.HasIndex(e => e.CustomerId);
            engagement.HasIndex(e => e.ProgrammerId);
            engagement.HasOne(e => e.Post).WithMany().HasForeignKey(e => e.PostId)
                .OnDelete(DeleteBehavior.Cascade).HasConstraintName("FK_Engagements_Posts");
            // No cascade on the rest: SQL Server allows one cascade path, and a user delete removes engagements first.
            engagement.HasOne(e => e.Application).WithMany().HasForeignKey(e => e.ApplicationId)
                .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Engagements_PostApplications");
            engagement.HasOne<User>().WithMany().HasForeignKey(e => e.CustomerId)
                .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Engagements_Users_Customer");
            engagement.HasOne<User>().WithMany().HasForeignKey(e => e.ProgrammerId)
                .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Engagements_Users_Programmer");

            var criterion = modelBuilder.Entity<EngagementCriterion>();
            criterion.ToTable("EngagementCriteria");
            criterion.HasIndex(c => new { c.EngagementId, c.SortOrder }).IsUnique();
            criterion.HasOne(c => c.Engagement).WithMany(e => e.Criteria).HasForeignKey(c => c.EngagementId)
                .OnDelete(DeleteBehavior.Cascade).HasConstraintName("FK_EngagementCriteria_Engagements");

            var delivery = modelBuilder.Entity<EngagementDelivery>();
            delivery.ToTable("EngagementDeliveries");
            delivery.HasIndex(d => new { d.EngagementId, d.Round }).IsUnique();
            delivery.HasOne(d => d.Engagement).WithMany(e => e.Deliveries).HasForeignKey(d => d.EngagementId)
                .OnDelete(DeleteBehavior.Cascade).HasConstraintName("FK_EngagementDeliveries_Engagements");

            var item = modelBuilder.Entity<EngagementDeliveryItem>();
            item.ToTable("EngagementDeliveryItems");
            item.HasKey(i => new { i.DeliveryId, i.CriterionId });
            item.HasIndex(i => i.CriterionId);
            item.HasOne(i => i.Delivery).WithMany(d => d.Items).HasForeignKey(i => i.DeliveryId)
                .OnDelete(DeleteBehavior.Cascade).HasConstraintName("FK_EngagementDeliveryItems_EngagementDeliveries");
            item.HasOne(i => i.Criterion).WithMany().HasForeignKey(i => i.CriterionId)
                .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_EngagementDeliveryItems_EngagementCriteria");

            var evt = modelBuilder.Entity<EngagementEvent>();
            evt.ToTable("EngagementEvents");
            evt.HasIndex(e => e.EngagementId);
            evt.HasOne(e => e.Engagement).WithMany(e => e.Events).HasForeignKey(e => e.EngagementId)
                .OnDelete(DeleteBehavior.Cascade).HasConstraintName("FK_EngagementEvents_Engagements");
        }
    }
}
