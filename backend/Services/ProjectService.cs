using System.Text.RegularExpressions;
using DataBase;
using DataBase.Models;
using Microsoft.EntityFrameworkCore;
using Services.Files;

namespace Services
{
    public sealed class ProjectInput
    {
        public string? Title { get; set; }
        public string? ProblemStatement { get; set; }
        public string? TargetUsers { get; set; }
        public decimal? BudgetMin { get; set; }
        public decimal? BudgetMax { get; set; }
        public int? DeadlineDays { get; set; }
        public List<string>? Criteria { get; set; }
    }

    public sealed record ReadinessIssue(string Code, string Field, string Message);

    public sealed record ReadinessReport(bool Ready, int Score, IReadOnlyList<ReadinessIssue> Blocking, IReadOnlyList<ReadinessIssue> Warnings);

    public enum ProjectResult
    {
        Ok,
        Invalid,
        NotReady,
        NotFound,
        Forbidden,
        Locked
    }

    public class ProjectService
    {
        public const int TitleMax = 120;
        public const int ProblemMax = 2000;
        public const int TargetUsersMax = 1000;
        public const int CriteriaMin = 1;
        public const int CriteriaMax = 20;
        public const int CriterionMinLength = 10;
        public const int CriterionMaxLength = 300;
        public const int DeadlineMaxDays = 365;
        public const decimal BudgetLimit = 1_000_000m;

        public const int ReadyTitleMin = 10;
        public const int ReadyProblemMin = 50;
        public const int ReadyCriteriaMin = 3;

        private static readonly Regex VagueWords =
            new(@"\b(nice|fast|modern|good|beautiful)\b", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        private readonly AppDbContext _context;
        private readonly PostService _posts;
        private readonly MediaUrls _media;

        public ProjectService(AppDbContext context, PostService posts, MediaUrls media)
        {
            _context = context;
            _posts = posts;
            _media = media;
        }

        private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

        private static List<string> CleanCriteria(ProjectInput input) =>
            (input.Criteria ?? new List<string>()).Select(c => c?.Trim() ?? "").ToList();

        /// <summary>Field limits. Anything that fails here is a 400 and never reaches readiness.</summary>
        public static Dictionary<string, string> Validate(ProjectInput input)
        {
            var errors = new Dictionary<string, string>();
            var criteria = CleanCriteria(input);

            if ((Clean(input.Title)?.Length ?? 0) > TitleMax) errors["title"] = $"At most {TitleMax} characters.";
            if ((Clean(input.ProblemStatement)?.Length ?? 0) > ProblemMax) errors["problemStatement"] = $"At most {ProblemMax} characters.";
            if ((Clean(input.TargetUsers)?.Length ?? 0) > TargetUsersMax) errors["targetUsers"] = $"At most {TargetUsersMax} characters.";

            if (criteria.Count < CriteriaMin || criteria.Count > CriteriaMax)
                errors["criteria"] = $"Add between {CriteriaMin} and {CriteriaMax} acceptance criteria.";

            for (var i = 0; i < criteria.Count; i++)
            {
                if (criteria[i].Length < CriterionMinLength || criteria[i].Length > CriterionMaxLength)
                    errors[$"criteria[{i}]"] = $"Each criterion needs {CriterionMinLength}–{CriterionMaxLength} characters.";
            }

            if (input.BudgetMin is < 0 or > BudgetLimit) errors["budgetMin"] = "Enter an amount between 0 and 1,000,000.";
            if (input.BudgetMax is < 0 or > BudgetLimit) errors["budgetMax"] = "Enter an amount between 0 and 1,000,000.";
            if (input.DeadlineDays is < 1 or > DeadlineMaxDays) errors["deadlineDays"] = $"Enter 1–{DeadlineMaxDays} days.";

            return errors;
        }

        /// <summary>Rule-based readiness. Only blocking issues stop a submission; the score is informational.</summary>
        public static ReadinessReport Readiness(ProjectInput input)
        {
            var blocking = new List<ReadinessIssue>();
            var warnings = new List<ReadinessIssue>();
            var criteria = CleanCriteria(input).Where(c => c.Length > 0).ToList();

            if ((Clean(input.Title)?.Length ?? 0) < ReadyTitleMin)
                blocking.Add(new("TITLE_TOO_SHORT", "title", $"Give the project a title of at least {ReadyTitleMin} characters."));

            if ((Clean(input.ProblemStatement)?.Length ?? 0) < ReadyProblemMin)
                blocking.Add(new("PROBLEM_TOO_SHORT", "problemStatement", $"Describe the problem in at least {ReadyProblemMin} characters."));

            if (criteria.Count < ReadyCriteriaMin)
                blocking.Add(new("TOO_FEW_CRITERIA", "criteria", $"Add at least {ReadyCriteriaMin} acceptance criteria."));

            if (input.BudgetMin is not > 0 || input.BudgetMax is not > 0 || input.BudgetMax < input.BudgetMin)
                blocking.Add(new("BUDGET_INVALID", "budget", "Enter a budget above 0, with the maximum not below the minimum."));

            for (var i = 0; i < criteria.Count; i++)
            {
                var match = VagueWords.Match(criteria[i]);
                if (match.Success)
                    warnings.Add(new("VAGUE_CRITERION", $"criteria[{i}]",
                        $"Criterion {i + 1} uses \"{match.Value.ToLowerInvariant()}\", which is hard to check. Describe what you will test."));
            }

            var score = Math.Max(0, 100 - 10 * blocking.Count - 4 * warnings.Count);
            return new ReadinessReport(blocking.Count == 0, score, blocking, warnings);
        }

        private void Apply(Post post, ProjectInput input)
        {
            post.Title = Clean(input.Title);
            post.ProblemStatement = Clean(input.ProblemStatement);
            post.TargetUsers = Clean(input.TargetUsers);
            post.BudgetMin = input.BudgetMin;
            post.BudgetMax = input.BudgetMax;
            post.DeadlineDays = input.DeadlineDays;
            // Older screens show Content, so it carries the problem statement.
            post.Content = post.ProblemStatement;
        }

        private static List<AcceptanceCriterion> ToCriteria(ProjectInput input) =>
            CleanCriteria(input).Select((text, i) => new AcceptanceCriterion { SortOrder = i + 1, Text = text }).ToList();

        public async Task<(ProjectResult result, int? id, Dictionary<string, string>? errors, ReadinessReport? readiness)> Create(int customerId, ProjectInput input)
        {
            var errors = Validate(input);
            if (errors.Count > 0) return (ProjectResult.Invalid, null, errors, null);

            var readiness = Readiness(input);
            if (!readiness.Ready) return (ProjectResult.NotReady, null, null, readiness);

            var post = new Post { UserId = customerId, Status = "Pending", CreatedAt = DateTime.UtcNow };
            Apply(post, input);
            foreach (var criterion in ToCriteria(input)) post.Criteria.Add(criterion);

            _context.Posts.Add(post);
            await _context.SaveChangesAsync();
            return (ProjectResult.Ok, post.Id, null, readiness);
        }

        public async Task<(ProjectResult result, Dictionary<string, string>? errors, ReadinessReport? readiness)> Update(int projectId, int callerId, ProjectInput input)
        {
            var post = await _context.Posts.Include(p => p.Criteria)
                .FirstOrDefaultAsync(p => p.Id == projectId && !p.IsDeleted && p.Title != null);
            if (post == null) return (ProjectResult.NotFound, null, null);
            if (post.UserId != callerId) return (ProjectResult.Forbidden, null, null);
            if (post.Status != "Pending" && post.Status != "Rejected") return (ProjectResult.Locked, null, null);

            var errors = Validate(input);
            if (errors.Count > 0) return (ProjectResult.Invalid, errors, null);

            var readiness = Readiness(input);
            if (!readiness.Ready) return (ProjectResult.NotReady, null, readiness);

            await using var transaction = await _context.Database.BeginTransactionAsync();

            Apply(post, input);
            // Old rows go first: the new list reuses their (PostId, SortOrder) keys.
            _context.AcceptanceCriteria.RemoveRange(post.Criteria);
            await _context.SaveChangesAsync();

            foreach (var criterion in ToCriteria(input)) post.Criteria.Add(criterion);
            post.Status = "Pending";
            post.RejectionReason = null;
            post.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return (ProjectResult.Ok, null, readiness);
        }

        public async Task<(ProjectResult result, object? project)> Details(int projectId, int callerId, bool callerIsAdmin)
        {
            var post = await _context.Posts.AsNoTracking()
                .Include(p => p.Criteria)
                .FirstOrDefaultAsync(p => p.Id == projectId && !p.IsDeleted && p.Title != null);
            if (post == null) return (ProjectResult.NotFound, null);

            var isMine = post.UserId == callerId;
            // Unapproved projects stay invisible to everyone but their owner and admins.
            if (post.Status != "Approved" && !isMine && !callerIsAdmin) return (ProjectResult.NotFound, null);

            var author = await _posts.GetAuthorInfo(post.UserId);
            var criteria = post.Criteria.OrderBy(c => c.SortOrder).Select(c => new { order = c.SortOrder, text = c.Text }).ToList();
            var canSeeReview = isMine || callerIsAdmin;
            var input = new ProjectInput
            {
                Title = post.Title, ProblemStatement = post.ProblemStatement, BudgetMin = post.BudgetMin, BudgetMax = post.BudgetMax,
                Criteria = post.Criteria.OrderBy(c => c.SortOrder).Select(c => c.Text).ToList()
            };

            return (ProjectResult.Ok, new
            {
                id = post.Id,
                userId = post.UserId,
                authorName = author?.nickname ?? "User",
                avatarUrl = author?.hasImage == true ? _media.AvatarUrl(post.UserId) : null,
                title = post.Title,
                problemStatement = post.ProblemStatement,
                targetUsers = post.TargetUsers,
                budgetMin = post.BudgetMin,
                budgetMax = post.BudgetMax,
                deadlineDays = post.DeadlineDays,
                status = post.Status,
                rejectionReason = canSeeReview ? post.RejectionReason : null,
                isClosed = post.IsClosed,
                isMine,
                createdAt = post.CreatedAt,
                updatedAt = post.UpdatedAt,
                criteriaCount = criteria.Count,
                criteria,
                applicationsCount = await _context.PostApplications.CountAsync(a => a.PostId == post.Id),
                readiness = canSeeReview ? Readiness(input) : null
            });
        }
    }
}
