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

    public sealed class CriterionAnswerInput
    {
        public int CriterionId { get; set; }
        public string? Response { get; set; }
        public string? Note { get; set; }
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

        public const int ApproachMin = 100;
        public const int ApproachMax = 1500;
        public const int NoteMin = 5;
        public const int NoteMax = 300;

        /// <summary>Rules for an application to a project: every criterion answered once, plus amount, duration and approach.</summary>
        public static string? ValidateApplication(IReadOnlyList<AcceptanceCriterion> criteria, string? approach, decimal? amount,
            int? durationDays, IReadOnlyList<CriterionAnswerInput>? answers)
        {
            var text = approach?.Trim() ?? "";
            if (text.Length < ApproachMin || text.Length > ApproachMax)
                return $"Describe your approach in {ApproachMin}–{ApproachMax} characters.";
            if (amount is not > 0 || amount > BudgetLimit) return "Enter a proposed amount above 0.";
            if (durationDays is not (>= 1 and <= DeadlineMaxDays)) return $"Enter a duration of 1–{DeadlineMaxDays} days.";

            var given = answers ?? new List<CriterionAnswerInput>();
            var known = criteria.ToDictionary(c => c.Id);
            if (given.Any(a => !known.ContainsKey(a.CriterionId))) return "An answer refers to a requirement that isn't on this project.";
            if (given.GroupBy(a => a.CriterionId).Any(g => g.Count() > 1)) return "Answer each requirement once.";

            foreach (var criterion in criteria.OrderBy(c => c.SortOrder))
            {
                var answer = given.FirstOrDefault(a => a.CriterionId == criterion.Id);
                if (answer == null) return $"Answer requirement {criterion.SortOrder}.";
                if (!CriterionResponses.All.Contains(answer.Response))
                    return $"Requirement {criterion.SortOrder}: choose Will meet, Needs clarification or Propose change.";
                var note = answer.Note?.Trim() ?? "";
                if (note.Length > NoteMax) return $"Requirement {criterion.SortOrder}: the note can have at most {NoteMax} characters.";
                if (answer.Response != CriterionResponses.WillMeet && note.Length < NoteMin)
                    return $"Requirement {criterion.SortOrder}: add a note of at least {NoteMin} characters.";
            }

            return null;
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
            var criteria = post.Criteria.OrderBy(c => c.SortOrder).Select(c => new { id = c.Id, order = c.SortOrder, text = c.Text }).ToList();
            var canSeeReview = isMine || callerIsAdmin;
            var engagement = await _context.Engagements.AsNoTracking()
                .Where(e => e.PostId == post.Id)
                .Select(e => new { e.Id, e.Status, e.CustomerId, e.ProgrammerId })
                .FirstOrDefaultAsync();
            var seesEngagement = engagement != null && (callerIsAdmin || engagement.CustomerId == callerId || engagement.ProgrammerId == callerId);
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
                completedAt = post.CompletedAt,
                engagementId = seesEngagement ? engagement!.Id : (int?)null,
                engagementStatus = seesEngagement ? engagement!.Status : null,
                isMine,
                createdAt = post.CreatedAt,
                updatedAt = post.UpdatedAt,
                criteriaCount = criteria.Count,
                criteria,
                applicationsCount = await _context.PostApplications.CountAsync(a => a.PostId == post.Id),
                framework = post.Framework,
                myApplicationId = await _context.PostApplications
                    .Where(a => a.PostId == post.Id && a.ProgrammerId == callerId)
                    .Select(a => (int?)a.Id)
                    .FirstOrDefaultAsync(),
                readiness = canSeeReview ? Readiness(input) : null
            });
        }

        // ---------------- applications ----------------

        public static readonly string[] ApplicantSorts = { "submitted", "coverage", "amount", "duration", "rating", "verified" };

        private sealed record Coverage(int WillMeet, int NeedsClarification, int ProposeChange);

        private async Task<Dictionary<int, Coverage>> CoverageAsync(IReadOnlyCollection<int> applicationIds)
        {
            var rows = await _context.ApplicationCriterionResponses
                .Where(r => applicationIds.Contains(r.ApplicationId))
                .GroupBy(r => new { r.ApplicationId, r.Response })
                .Select(g => new { g.Key.ApplicationId, g.Key.Response, Count = g.Count() })
                .ToListAsync();
            return applicationIds.ToDictionary(id => id, id => new Coverage(
                rows.Where(r => r.ApplicationId == id && r.Response == CriterionResponses.WillMeet).Sum(r => r.Count),
                rows.Where(r => r.ApplicationId == id && r.Response == CriterionResponses.NeedsClarification).Sum(r => r.Count),
                rows.Where(r => r.ApplicationId == id && r.Response == CriterionResponses.ProposeChange).Sum(r => r.Count)));
        }

        private static object CoverageJson(Coverage c, int total) => new
        {
            willMeet = c.WillMeet,
            needsClarification = c.NeedsClarification,
            proposeChange = c.ProposeChange,
            total
        };

        /// <summary>The owner's applicants with coverage, amount, duration, rating and verification. Default order: oldest first.</summary>
        public async Task<(ProjectResult result, List<object>? applicants)> Applicants(int projectId, int ownerId, string? sort, string? dir)
        {
            var post = await _context.Posts.AsNoTracking().FirstOrDefaultAsync(p => p.Id == projectId && !p.IsDeleted && p.Title != null);
            if (post == null) return (ProjectResult.NotFound, null);
            if (post.UserId != ownerId) return (ProjectResult.Forbidden, null);

            var total = await _context.AcceptanceCriteria.CountAsync(c => c.PostId == projectId);
            var applications = await _context.PostApplications.AsNoTracking().Where(a => a.PostId == projectId).ToListAsync();
            var coverage = await CoverageAsync(applications.Select(a => a.Id).ToList());
            var programmerIds = applications.Select(a => a.ProgrammerId).ToList();
            var profiles = await _context.ProgrammerProfiles.AsNoTracking()
                .Where(p => programmerIds.Contains(p.UserId))
                .ToDictionaryAsync(p => p.UserId);

            var rows = applications.Select(a =>
            {
                profiles.TryGetValue(a.ProgrammerId, out var profile);
                return new
                {
                    Application = a,
                    Coverage = coverage[a.Id],
                    Rating = profile?.Rating > 0 ? profile.Rating : (int?)null,
                    Verified = profile?.IsVerified == true,
                    Name = profile?.Nickname ?? "Programmer",
                    HasImage = profile?.ProfileImage != null
                };
            }).ToList();

            var descending = string.Equals(dir, "desc", StringComparison.OrdinalIgnoreCase);
            var ascending = string.Equals(dir, "asc", StringComparison.OrdinalIgnoreCase);
            // Ties always fall back to submission time, oldest first.
            var ordered = (sort?.ToLowerInvariant()) switch
            {
                "coverage" => ascending
                    ? rows.OrderBy(r => r.Coverage.WillMeet)
                    : rows.OrderByDescending(r => r.Coverage.WillMeet),
                "amount" => descending ? rows.OrderByDescending(r => r.Application.Price ?? decimal.MaxValue) : rows.OrderBy(r => r.Application.Price ?? decimal.MaxValue),
                "duration" => descending ? rows.OrderByDescending(r => r.Application.DurationDays ?? int.MaxValue) : rows.OrderBy(r => r.Application.DurationDays ?? int.MaxValue),
                "rating" => ascending ? rows.OrderBy(r => r.Rating ?? -1) : rows.OrderByDescending(r => r.Rating ?? -1),
                "verified" => ascending ? rows.OrderBy(r => r.Verified) : rows.OrderByDescending(r => r.Verified),
                _ => descending ? rows.OrderByDescending(r => r.Application.CreatedAt) : rows.OrderBy(r => r.Application.CreatedAt)
            };
            if (sort != null && sort.ToLowerInvariant() != "submitted") ordered = ordered.ThenBy(r => r.Application.CreatedAt);

            return (ProjectResult.Ok, ordered.Select(r => (object)new
            {
                applicationId = r.Application.Id,
                programmerId = r.Application.ProgrammerId,
                programmerName = r.Name,
                avatarUrl = r.HasImage ? _media.AvatarUrl(r.Application.ProgrammerId) : null,
                status = r.Application.Status,
                submittedAt = r.Application.CreatedAt,
                amount = r.Application.Price,
                durationDays = r.Application.DurationDays,
                coverage = CoverageJson(r.Coverage, total),
                rating = r.Rating,
                isVerified = r.Verified
            }).ToList());
        }

        /// <summary>One application with every criterion and its answer. Only the project owner and the applicant may read it.</summary>
        public async Task<(ProjectResult result, object? application)> Application(int projectId, int applicationId, int callerId)
        {
            var application = await _context.PostApplications.AsNoTracking()
                .Include(a => a.Responses)
                .Include(a => a.Post)
                .FirstOrDefaultAsync(a => a.Id == applicationId && a.PostId == projectId && a.Post!.Title != null && !a.Post.IsDeleted);
            if (application == null) return (ProjectResult.NotFound, null);
            if (application.ProgrammerId != callerId && application.Post!.UserId != callerId) return (ProjectResult.Forbidden, null);

            var criteria = await _context.AcceptanceCriteria.AsNoTracking().Where(c => c.PostId == projectId).OrderBy(c => c.SortOrder).ToListAsync();
            var profile = await _context.ProgrammerProfiles.AsNoTracking().FirstOrDefaultAsync(p => p.UserId == application.ProgrammerId);
            var coverage = (await CoverageAsync(new[] { application.Id }))[application.Id];

            return (ProjectResult.Ok, new
            {
                applicationId = application.Id,
                projectId,
                projectTitle = application.Post!.Title,
                programmerId = application.ProgrammerId,
                programmerName = profile?.Nickname ?? "Programmer",
                avatarUrl = profile?.ProfileImage != null ? _media.AvatarUrl(application.ProgrammerId) : null,
                isVerified = profile?.IsVerified == true,
                rating = profile?.Rating > 0 ? profile.Rating : (int?)null,
                status = application.Status,
                submittedAt = application.CreatedAt,
                amount = application.Price,
                durationDays = application.DurationDays,
                approach = application.Proposal,
                framework = application.Framework,
                isMine = application.ProgrammerId == callerId,
                coverage = CoverageJson(coverage, criteria.Count),
                answers = criteria.Select(c =>
                {
                    var answer = application.Responses.FirstOrDefault(r => r.CriterionId == c.Id);
                    return new { criterionId = c.Id, order = c.SortOrder, text = c.Text, response = answer?.Response, note = answer?.Note };
                }).ToList()
            });
        }

        /// <summary>The caller's own applications to customer projects, newest first.</summary>
        public async Task<List<object>> MyApplications(int programmerId)
        {
            var applications = await _context.PostApplications.AsNoTracking()
                .Include(a => a.Post)
                .Where(a => a.ProgrammerId == programmerId && a.Post!.Title != null && !a.Post.IsDeleted)
                .OrderByDescending(a => a.CreatedAt)
                .ToListAsync();
            var coverage = await CoverageAsync(applications.Select(a => a.Id).ToList());
            var postIds = applications.Select(a => a.PostId).ToList();
            var totals = await _context.AcceptanceCriteria.Where(c => postIds.Contains(c.PostId))
                .GroupBy(c => c.PostId).Select(g => new { g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Key, x => x.Count);
            var engagements = await _context.Engagements.AsNoTracking()
                .Where(e => e.ProgrammerId == programmerId)
                .ToDictionaryAsync(e => e.ApplicationId, e => e.Id);

            return applications.Select(a => (object)new
            {
                applicationId = a.Id,
                projectId = a.PostId,
                projectTitle = a.Post!.Title,
                status = a.Status,
                isClosed = a.Post.IsClosed,
                submittedAt = a.CreatedAt,
                amount = a.Price,
                durationDays = a.DurationDays,
                coverage = CoverageJson(coverage[a.Id], totals.GetValueOrDefault(a.PostId)),
                engagementId = engagements.TryGetValue(a.Id, out var engagementId) ? engagementId : (int?)null
            }).ToList();
        }
    }
}
