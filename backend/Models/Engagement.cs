using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DataBase.Models
{
    public static class EngagementStatuses
    {
        public const string Active = "Active";
        public const string Delivered = "Delivered";
        public const string Completed = "Completed";
        public const string Cancelled = "Cancelled";
    }

    public static class EngagementCriterionStatuses
    {
        public const string Open = "Open";
        public const string InReview = "InReview";
        public const string NeedsRevision = "NeedsRevision";
        public const string Accepted = "Accepted";
    }

    public static class DeliveryClaims
    {
        public const string Met = "Met";
        public const string NotMet = "NotMet";
        public static readonly string[] All = { Met, NotMet };
    }

    public static class ReviewDecisions
    {
        public const string Accept = "Accept";
        public const string Revise = "Revise";
        public static readonly string[] All = { Accept, Revise };
    }

    /// <summary>The agreement made when a customer accepts an application. Amount, deadline and criteria are copied and never change.</summary>
    public class Engagement
    {
        [Key]
        public int Id { get; set; }

        public int PostId { get; set; }

        [ForeignKey(nameof(PostId))]
        public Post? Post { get; set; }

        public int ApplicationId { get; set; }

        [ForeignKey(nameof(ApplicationId))]
        public PostApplication? Application { get; set; }

        public int CustomerId { get; set; }

        public int ProgrammerId { get; set; }

        [Required]
        [MaxLength(120)]
        public string ProjectTitle { get; set; } = "";

        [Column(TypeName = "decimal(12,2)")]
        public decimal? AgreedAmount { get; set; }

        public int? DurationDays { get; set; }

        public DateTime? DeadlineAt { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = EngagementStatuses.Active;

        public int RevisionsUsed { get; set; }

        public int CriteriaTotal { get; set; }

        public int? CriteriaMet { get; set; }

        public int? CancellationRequestedBy { get; set; }

        [MaxLength(500)]
        public string? CancellationReason { get; set; }

        public DateTime? CancellationRequestedAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? UpdatedAt { get; set; }

        public DateTime? CompletedAt { get; set; }

        public DateTime? CancelledAt { get; set; }

        // Two requests that read the same version cannot both change the engagement.
        [Timestamp]
        public byte[] RowVersion { get; set; } = Array.Empty<byte>();

        public ICollection<EngagementCriterion> Criteria { get; set; } = new List<EngagementCriterion>();
        public ICollection<EngagementDelivery> Deliveries { get; set; } = new List<EngagementDelivery>();
        public ICollection<EngagementEvent> Events { get; set; } = new List<EngagementEvent>();
    }

    public class EngagementCriterion
    {
        [Key]
        public int Id { get; set; }

        public int EngagementId { get; set; }

        [ForeignKey(nameof(EngagementId))]
        public Engagement? Engagement { get; set; }

        public int SortOrder { get; set; }

        [Required]
        [MaxLength(300)]
        public string Text { get; set; } = "";

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = EngagementCriterionStatuses.Open;

        public bool Waived { get; set; }

        public DateTime? AcceptedAt { get; set; }
    }

    public class EngagementDelivery
    {
        [Key]
        public int Id { get; set; }

        public int EngagementId { get; set; }

        [ForeignKey(nameof(EngagementId))]
        public Engagement? Engagement { get; set; }

        public int Round { get; set; }

        [Required]
        [MaxLength(1000)]
        public string Note { get; set; } = "";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? ReviewedAt { get; set; }

        public ICollection<EngagementDeliveryItem> Items { get; set; } = new List<EngagementDeliveryItem>();
    }

    public class EngagementDeliveryItem
    {
        public int DeliveryId { get; set; }

        [ForeignKey(nameof(DeliveryId))]
        public EngagementDelivery? Delivery { get; set; }

        public int CriterionId { get; set; }

        [ForeignKey(nameof(CriterionId))]
        public EngagementCriterion? Criterion { get; set; }

        [Required]
        [MaxLength(10)]
        public string Claim { get; set; } = DeliveryClaims.Met;

        [Required]
        [MaxLength(500)]
        public string Evidence { get; set; } = "";

        [MaxLength(10)]
        public string? Decision { get; set; }

        [MaxLength(500)]
        public string? ReviewNote { get; set; }

        public bool Waived { get; set; }
    }

    public class EngagementEvent
    {
        [Key]
        public int Id { get; set; }

        public int EngagementId { get; set; }

        [ForeignKey(nameof(EngagementId))]
        public Engagement? Engagement { get; set; }

        // Null for events no person caused.
        public int? ActorId { get; set; }

        [Required]
        [MaxLength(40)]
        public string Type { get; set; } = "";

        [Required]
        [MaxLength(500)]
        public string Message { get; set; } = "";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
