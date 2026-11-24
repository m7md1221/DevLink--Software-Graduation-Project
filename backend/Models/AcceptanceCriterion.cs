using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DataBase.Models
{
    public class AcceptanceCriterion
    {
        [Key]
        public int Id { get; set; }

        public int PostId { get; set; }

        [ForeignKey(nameof(PostId))]
        public Post? Post { get; set; }

        // 1-based position shown to the customer and the programmer.
        public int SortOrder { get; set; }

        [Required]
        [MaxLength(300)]
        public string Text { get; set; } = "";
    }
}
