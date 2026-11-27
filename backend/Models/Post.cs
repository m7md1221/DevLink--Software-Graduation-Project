using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using DataBase.Models;

namespace DataBase
{
    public class Post
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        public User? User { get; set; }

        public string? Content { get; set; }

        [MaxLength(50)]
        public string? Framework { get; set; }   // ✅ جديد

        // Customer projects have a title; social posts don't.
        [MaxLength(120)]
        public string? Title { get; set; }

        [MaxLength(2000)]
        public string? ProblemStatement { get; set; }

        [MaxLength(1000)]
        public string? TargetUsers { get; set; }

        [Column(TypeName = "decimal(12,2)")]
        public decimal? BudgetMin { get; set; }

        [Column(TypeName = "decimal(12,2)")]
        public decimal? BudgetMax { get; set; }

        public int? DeadlineDays { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? UpdatedAt { get; set; }

        // Set when the engagement for this project is completed.
        public DateTime? CompletedAt { get; set; }

        public bool IsDeleted { get; set; } = false;

        public bool IsClosed { get; set; } = false;

        public string Status { get; set; } = "Pending";

        [MaxLength(500)]
        public string? RejectionReason { get; set; }

        public ICollection<PostImage> Images { get; set; } = new List<PostImage>();
        public ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
        public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
        public ICollection<PostApplication> Applications { get; set; } = new List<PostApplication>();
        public ICollection<AcceptanceCriterion> Criteria { get; set; } = new List<AcceptanceCriterion>();
    }
}