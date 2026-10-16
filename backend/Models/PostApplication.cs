using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using DataBase.Models;

namespace DataBase
{
    public class PostApplication
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int PostId { get; set; }

        [ForeignKey(nameof(PostId))]
        public Post? Post { get; set; }

        [Required]
        public int ProgrammerId { get; set; }

        [ForeignKey(nameof(ProgrammerId))]
        public User? Programmer { get; set; }

        [Required]
        [MaxLength(2000)]
        public string Proposal { get; set; } = string.Empty;

        public decimal? Price { get; set; }

        [MaxLength(100)]
        public string? Duration { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "Pending";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? UpdatedAt { get; set; }
    }
}