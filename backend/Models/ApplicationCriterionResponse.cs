using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DataBase.Models
{
    public static class CriterionResponses
    {
        public const string WillMeet = "WillMeet";
        public const string NeedsClarification = "NeedsClarification";
        public const string ProposeChange = "ProposeChange";

        public static readonly string[] All = { WillMeet, NeedsClarification, ProposeChange };
    }

    public class ApplicationCriterionResponse
    {
        public int ApplicationId { get; set; }

        [ForeignKey(nameof(ApplicationId))]
        public PostApplication? Application { get; set; }

        public int CriterionId { get; set; }

        [ForeignKey(nameof(CriterionId))]
        public AcceptanceCriterion? Criterion { get; set; }

        [Required]
        [MaxLength(20)]
        public string Response { get; set; } = CriterionResponses.WillMeet;

        [MaxLength(300)]
        public string? Note { get; set; }
    }
}
