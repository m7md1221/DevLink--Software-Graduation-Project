using DataBase;
using DataBase.Models;
using Microsoft.EntityFrameworkCore;

namespace Services
{
    public sealed class DeliveryItemInput
    {
        public int CriterionId { get; set; }
        public string? Claim { get; set; }
        public string? Evidence { get; set; }
    }

    public sealed class DeliveryInput
    {
        public string? Note { get; set; }
        public List<DeliveryItemInput>? Items { get; set; }
    }

    public sealed class ReviewItemInput
    {
        public int CriterionId { get; set; }
        public string? Decision { get; set; }
        public string? Note { get; set; }
        public bool Waive { get; set; }
    }

    public sealed class ReviewInput
    {
        public List<ReviewItemInput>? Items { get; set; }
    }

    public sealed class ReasonInput
    {
        public string? Reason { get; set; }
    }

    public enum EngagementResult
    {
        Ok,
        NotFound,
        Forbidden,
        Invalid,
        Conflict
    }

    public sealed record EngagementOutcome(EngagementResult Result, string Message, object? Body = null)
    {
        public static EngagementOutcome Ok(string message, object? body = null) => new(EngagementResult.Ok, message, body);
        public static EngagementOutcome Invalid(string message) => new(EngagementResult.Invalid, message);
        public static EngagementOutcome Conflict(string message) => new(EngagementResult.Conflict, message);
        public static readonly EngagementOutcome NotFound = new(EngagementResult.NotFound, "Engagement not found");
        public static readonly EngagementOutcome Forbidden = new(EngagementResult.Forbidden, "Only the customer and the programmer of this engagement can do this.");
    }

    public class EngagementService
    {
        public const int MaxRevisions = 2;
        public const int EvidenceMin = 5;
        public const int EvidenceMax = 500;
        public const int DeliveryNoteMin = 5;
        public const int DeliveryNoteMax = 1000;
        public const int ReasonMin = 5;
        public const int ReasonMax = 500;

        private const string ChangedMeanwhile = "This engagement changed while you were working. Reload it and try again.";

        private readonly AppDbContext _context;

        public EngagementService(AppDbContext context)
        {
            _context = context;
        }

        /// <summary>The engagement a newly accepted application starts. Criteria, amount and deadline are copied from the project and application.</summary>
        public static Engagement Build(Post post, PostApplication application, IEnumerable<AcceptanceCriterion> criteria, DateTime now)
        {
            var days = application.DurationDays ?? post.DeadlineDays;
            var engagement = new Engagement
            {
                PostId = post.Id,
                ApplicationId = application.Id,
                CustomerId = post.UserId,
                ProgrammerId = application.ProgrammerId,
                ProjectTitle = post.Title ?? "",
                AgreedAmount = application.Price,
                DurationDays = days,
                DeadlineAt = days.HasValue ? now.AddDays(days.Value) : null,
                Status = EngagementStatuses.Active,
                CreatedAt = now
            };
            foreach (var c in criteria.OrderBy(c => c.SortOrder))
                engagement.Criteria.Add(new EngagementCriterion { SortOrder = c.SortOrder, Text = c.Text });
            engagement.CriteriaTotal = engagement.Criteria.Count;

            var terms = application.Price.HasValue ? $"Agreed amount ${application.Price.Value:0.##}" : "No amount agreed";
            var due = days.HasValue ? $", due in {days} days" : "";
            engagement.Events.Add(new EngagementEvent
            {
                ActorId = post.UserId,
                Type = "Started",
                Message = $"Application accepted and work started. {terms}{due}.",
                CreatedAt = now
            });
            return engagement;
        }

        private Task<Engagement?> LoadAsync(int id) =>
            _context.Engagements
                .Include(e => e.Criteria)
                .Include(e => e.Deliveries).ThenInclude(d => d.Items)
                .AsSplitQuery()
                .FirstOrDefaultAsync(e => e.Id == id);

        private static bool IsParty(Engagement e, int callerId) => e.CustomerId == callerId || e.ProgrammerId == callerId;

        private static bool IsClosed(Engagement e) => e.Status is EngagementStatuses.Completed or EngagementStatuses.Cancelled;

        private void Notify(int userId, string title, string message, int engagementId) =>
            _context.Notifications.Add(new Notification
            {
                UserId = userId,
                Title = title,
                Message = message,
                Type = "engagement",
                ReferenceId = engagementId,
                CreatedAt = DateTime.UtcNow
            });

        private static void Log(Engagement e, int? actorId, string type, string message, DateTime now) =>
            e.Events.Add(new EngagementEvent { ActorId = actorId, Type = type, Message = message, CreatedAt = now });

        // One save per action: a second request holding the same row version fails here instead of applying twice.
        private async Task<EngagementOutcome?> SaveAsync()
        {
            try
            {
                await _context.SaveChangesAsync();
                return null;
            }
            catch (DbUpdateException)
            {
                _context.ChangeTracker.Clear();
                return EngagementOutcome.Conflict(ChangedMeanwhile);
            }
        }

        private static string Clean(string? value) => value?.Trim() ?? "";

        // ---------------- delivery ----------------

        public async Task<EngagementOutcome> Deliver(int id, int callerId, DeliveryInput input)
        {
            var e = await LoadAsync(id);
            if (e == null) return EngagementOutcome.NotFound;
            if (e.ProgrammerId != callerId) return EngagementOutcome.Forbidden;
            if (IsClosed(e)) return EngagementOutcome.Conflict("This engagement is closed.");
            if (e.Status == EngagementStatuses.Delivered) return EngagementOutcome.Conflict("The customer is reviewing your delivery.");

            var note = Clean(input.Note);
            if (note.Length < DeliveryNoteMin || note.Length > DeliveryNoteMax)
                return EngagementOutcome.Invalid($"Add an overall note of {DeliveryNoteMin}–{DeliveryNoteMax} characters.");

            var items = input.Items ?? new List<DeliveryItemInput>();
            var byId = e.Criteria.ToDictionary(c => c.Id);
            if (items.Any(i => !byId.ContainsKey(i.CriterionId))) return EngagementOutcome.Invalid("An answer refers to a requirement that isn't in this engagement.");
            if (items.GroupBy(i => i.CriterionId).Any(g => g.Count() > 1)) return EngagementOutcome.Invalid("Answer each requirement once.");

            foreach (var item in items)
            {
                var c = byId[item.CriterionId];
                if (c.Status == EngagementCriterionStatuses.Accepted) return EngagementOutcome.Invalid($"Requirement {c.SortOrder} is already accepted.");
            }

            // Every requirement not yet accepted needs an answer; on the first delivery that is all of them.
            var open = e.Criteria.Where(c => c.Status != EngagementCriterionStatuses.Accepted).OrderBy(c => c.SortOrder).ToList();
            foreach (var c in open)
            {
                var item = items.FirstOrDefault(i => i.CriterionId == c.Id);
                if (item == null) return EngagementOutcome.Invalid($"Answer requirement {c.SortOrder}.");
                if (!DeliveryClaims.All.Contains(item.Claim)) return EngagementOutcome.Invalid($"Requirement {c.SortOrder}: choose Met or Not met.");
                var evidence = Clean(item.Evidence);
                if (evidence.Length < EvidenceMin || evidence.Length > EvidenceMax)
                    return EngagementOutcome.Invalid($"Requirement {c.SortOrder}: add evidence of {EvidenceMin}–{EvidenceMax} characters, such as a note or a link.");
            }

            var now = DateTime.UtcNow;
            var delivery = new EngagementDelivery { Round = e.Deliveries.Count + 1, Note = note, CreatedAt = now };
            foreach (var c in open)
            {
                var item = items.First(i => i.CriterionId == c.Id);
                delivery.Items.Add(new EngagementDeliveryItem { CriterionId = c.Id, Claim = item.Claim!, Evidence = Clean(item.Evidence) });
                c.Status = EngagementCriterionStatuses.InReview;
            }
            e.Deliveries.Add(delivery);
            e.Status = EngagementStatuses.Delivered;
            e.UpdatedAt = now;

            var met = delivery.Items.Count(i => i.Claim == DeliveryClaims.Met);
            Log(e, callerId, "Delivered", $"Delivery {delivery.Round} submitted: {met} of {open.Count} requirements marked met.", now);
            Notify(e.CustomerId, "Delivery submitted", $"A delivery for \"{e.ProjectTitle}\" is ready for your review.", e.Id);

            return await SaveAsync() ?? EngagementOutcome.Ok("Your delivery was submitted.", new { message = "Your delivery was submitted.", round = delivery.Round });
        }

        // ---------------- review ----------------

        public async Task<EngagementOutcome> Review(int id, int callerId, ReviewInput input)
        {
            var e = await LoadAsync(id);
            if (e == null) return EngagementOutcome.NotFound;
            if (e.CustomerId != callerId) return EngagementOutcome.Forbidden;
            if (IsClosed(e)) return EngagementOutcome.Conflict("This engagement is closed.");
            if (e.Status != EngagementStatuses.Delivered) return EngagementOutcome.Conflict("There's no delivery to review.");

            var delivery = e.Deliveries.OrderByDescending(d => d.Round).First();
            var inReview = e.Criteria.Where(c => c.Status == EngagementCriterionStatuses.InReview).OrderBy(c => c.SortOrder).ToList();
            var items = input.Items ?? new List<ReviewItemInput>();
            var reviewable = inReview.Select(c => c.Id).ToHashSet();
            if (items.Any(i => !reviewable.Contains(i.CriterionId))) return EngagementOutcome.Invalid("A decision refers to a requirement that isn't in this delivery.");
            if (items.GroupBy(i => i.CriterionId).Any(g => g.Count() > 1)) return EngagementOutcome.Invalid("Decide on each requirement once.");

            foreach (var c in inReview)
            {
                var item = items.FirstOrDefault(i => i.CriterionId == c.Id);
                if (item == null) return EngagementOutcome.Invalid($"Decide on requirement {c.SortOrder}.");
                if (!ReviewDecisions.All.Contains(item.Decision)) return EngagementOutcome.Invalid($"Requirement {c.SortOrder}: choose Accept or Needs revision.");
                var note = Clean(item.Note);
                if (note.Length > ReasonMax) return EngagementOutcome.Invalid($"Requirement {c.SortOrder}: the note can have at most {ReasonMax} characters.");
                var claim = delivery.Items.First(i => i.CriterionId == c.Id).Claim;
                if (item.Decision == ReviewDecisions.Revise)
                {
                    if (e.RevisionsUsed >= MaxRevisions)
                        return EngagementOutcome.Invalid("No revision rounds are left. Accept the remaining requirements or request cancellation.");
                    if (note.Length < ReasonMin) return EngagementOutcome.Invalid($"Requirement {c.SortOrder}: explain what needs revision in {ReasonMin}–{ReasonMax} characters.");
                }
                else if (claim == DeliveryClaims.NotMet && !item.Waive)
                {
                    return EngagementOutcome.Invalid($"Requirement {c.SortOrder} was marked not met. Confirm the waiver to accept it.");
                }
            }

            var now = DateTime.UtcNow;
            foreach (var c in inReview)
            {
                var decision = items.First(i => i.CriterionId == c.Id);
                var row = delivery.Items.First(i => i.CriterionId == c.Id);
                row.Decision = decision.Decision;
                row.ReviewNote = Clean(decision.Note) is { Length: > 0 } n ? n : null;
                var accept = decision.Decision == ReviewDecisions.Accept;
                row.Waived = accept && row.Claim == DeliveryClaims.NotMet;
                c.Status = accept ? EngagementCriterionStatuses.Accepted : EngagementCriterionStatuses.NeedsRevision;
                c.Waived = row.Waived;
                c.AcceptedAt = accept ? now : null;
            }
            delivery.ReviewedAt = now;
            e.UpdatedAt = now;

            var revise = inReview.Count(c => c.Status == EngagementCriterionStatuses.NeedsRevision);
            if (revise == 0)
            {
                e.Status = EngagementStatuses.Completed;
                e.CompletedAt = now;
                // A waived requirement was accepted without being met.
                e.CriteriaMet = e.Criteria.Count(c => !c.Waived);
                var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == e.PostId);
                if (post != null) post.CompletedAt = now;

                Log(e, callerId, "Completed", $"All requirements accepted. Engagement completed: criteria met {e.CriteriaMet}/{e.CriteriaTotal}.", now);
                Notify(e.ProgrammerId, "Work accepted", $"Every requirement of \"{e.ProjectTitle}\" was accepted. The engagement is complete.", e.Id);
                return await SaveAsync() ?? EngagementOutcome.Ok("", new { message = "All requirements accepted. The engagement is complete.", status = e.Status });
            }

            e.RevisionsUsed++;
            e.Status = EngagementStatuses.Active;
            var accepted = inReview.Count - revise;
            Log(e, callerId, "RevisionRequested",
                $"Revision {e.RevisionsUsed} of {MaxRevisions} requested: {revise} {(revise == 1 ? "requirement needs" : "requirements need")} changes, {accepted} accepted.", now);
            Notify(e.ProgrammerId, "Revision requested",
                $"{revise} {(revise == 1 ? "requirement" : "requirements")} of \"{e.ProjectTitle}\" need changes; {accepted} accepted.", e.Id);
            return await SaveAsync() ?? EngagementOutcome.Ok("", new { message = "Your review was sent to the programmer.", status = e.Status });
        }

        // ---------------- cancellation ----------------

        public async Task<EngagementOutcome> RequestCancellation(int id, int callerId, ReasonInput input)
        {
            var e = await LoadAsync(id);
            if (e == null) return EngagementOutcome.NotFound;
            if (!IsParty(e, callerId)) return EngagementOutcome.Forbidden;
            if (IsClosed(e)) return EngagementOutcome.Conflict("This engagement is closed.");
            if (e.CancellationRequestedBy != null) return EngagementOutcome.Conflict("A cancellation request is already waiting for an answer.");

            var reason = Clean(input.Reason);
            if (reason.Length < ReasonMin || reason.Length > ReasonMax)
                return EngagementOutcome.Invalid($"Give a reason of {ReasonMin}–{ReasonMax} characters.");

            var now = DateTime.UtcNow;
            e.CancellationRequestedBy = callerId;
            e.CancellationReason = reason;
            e.CancellationRequestedAt = now;
            e.UpdatedAt = now;
            var who = callerId == e.CustomerId ? "The customer" : "The programmer";
            Log(e, callerId, "CancellationRequested", $"{who} asked to cancel: {reason}", now);
            Notify(callerId == e.CustomerId ? e.ProgrammerId : e.CustomerId, "Cancellation requested",
                $"{who} asked to cancel \"{e.ProjectTitle}\". Open the engagement to agree or decline.", e.Id);
            return await SaveAsync() ?? EngagementOutcome.Ok("Your cancellation request was sent.");
        }

        public async Task<EngagementOutcome> AnswerCancellation(int id, int callerId, bool agree)
        {
            var e = await LoadAsync(id);
            if (e == null) return EngagementOutcome.NotFound;
            if (!IsParty(e, callerId)) return EngagementOutcome.Forbidden;
            if (IsClosed(e)) return EngagementOutcome.Conflict("This engagement is closed.");
            if (e.CancellationRequestedBy == null) return EngagementOutcome.Conflict("There's no cancellation request to answer.");
            if (e.CancellationRequestedBy == callerId)
                return new EngagementOutcome(EngagementResult.Forbidden, "The other party answers your cancellation request.");

            var now = DateTime.UtcNow;
            var requester = e.CancellationRequestedBy.Value;
            e.UpdatedAt = now;
            if (agree)
            {
                e.Status = EngagementStatuses.Cancelled;
                e.CancelledAt = now;
                Log(e, callerId, "Cancelled", "Cancelled by agreement of both parties.", now);
                Notify(requester, "Engagement cancelled", $"Your request to cancel \"{e.ProjectTitle}\" was accepted. The engagement is cancelled.", e.Id);
                return await SaveAsync() ?? EngagementOutcome.Ok("The engagement is cancelled.");
            }

            e.CancellationRequestedBy = null;
            e.CancellationReason = null;
            e.CancellationRequestedAt = null;
            Log(e, callerId, "CancellationDeclined", "The cancellation request was declined. Work continues.", now);
            Notify(requester, "Cancellation declined", $"Your request to cancel \"{e.ProjectTitle}\" was declined. Work continues.", e.Id);
            return await SaveAsync() ?? EngagementOutcome.Ok("You declined the cancellation. Work continues.");
        }

        public async Task<EngagementOutcome> AdminCancel(int id, int adminId, ReasonInput input)
        {
            var e = await LoadAsync(id);
            if (e == null) return EngagementOutcome.NotFound;
            if (IsClosed(e)) return EngagementOutcome.Conflict("This engagement is closed.");
            var reason = Clean(input.Reason);
            if (reason.Length < ReasonMin || reason.Length > ReasonMax)
                return EngagementOutcome.Invalid($"Give a reason of {ReasonMin}–{ReasonMax} characters.");

            var now = DateTime.UtcNow;
            e.Status = EngagementStatuses.Cancelled;
            e.CancelledAt = now;
            e.CancellationReason = reason;
            e.UpdatedAt = now;
            Log(e, adminId, "Cancelled", $"Cancelled by a DevLink admin: {reason}", now);
            foreach (var party in new[] { e.CustomerId, e.ProgrammerId })
                Notify(party, "Engagement cancelled", $"A DevLink admin cancelled \"{e.ProjectTitle}\": {reason}", e.Id);
            return await SaveAsync() ?? EngagementOutcome.Ok("The engagement is cancelled.");
        }

        // ---------------- reading ----------------

        private async Task<Dictionary<int, string>> NamesAsync(params int[] userIds)
        {
            var customers = await _context.CustomerProfiles.AsNoTracking().Where(p => userIds.Contains(p.UserId))
                .Select(p => new { p.UserId, p.Nickname }).ToListAsync();
            var programmers = await _context.ProgrammerProfiles.AsNoTracking().Where(p => userIds.Contains(p.UserId))
                .Select(p => new { p.UserId, p.Nickname }).ToListAsync();
            var names = new Dictionary<int, string>();
            foreach (var p in customers.Concat(programmers))
                if (!string.IsNullOrWhiteSpace(p.Nickname)) names.TryAdd(p.UserId, p.Nickname);
            return names;
        }

        private static string Role(Engagement e, int callerId) =>
            e.CustomerId == callerId ? "customer" : e.ProgrammerId == callerId ? "programmer" : "admin";

        public async Task<EngagementOutcome> Get(int id, int callerId, bool callerIsAdmin)
        {
            var e = await _context.Engagements.AsNoTracking()
                .Include(x => x.Criteria)
                .Include(x => x.Deliveries).ThenInclude(d => d.Items)
                .Include(x => x.Events)
                .AsSplitQuery()
                .FirstOrDefaultAsync(x => x.Id == id);
            if (e == null) return EngagementOutcome.NotFound;
            if (!IsParty(e, callerId) && !callerIsAdmin) return EngagementOutcome.Forbidden;

            var names = await NamesAsync(e.CustomerId, e.ProgrammerId);
            string NameOf(int? userId) => userId == null ? "DevLink" :
                userId == e.CustomerId ? names.GetValueOrDefault(e.CustomerId, "Customer") :
                userId == e.ProgrammerId ? names.GetValueOrDefault(e.ProgrammerId, "Programmer") : "DevLink admin";

            var role = Role(e, callerId);
            var open = !IsClosed(e);
            var deliveries = e.Deliveries.OrderBy(d => d.Round).ToList();
            var accepted = e.Criteria.Count(c => c.Status == EngagementCriterionStatuses.Accepted);
            var pendingCancel = open && e.CancellationRequestedBy != null;

            return EngagementOutcome.Ok("", new
            {
                id = e.Id,
                projectId = e.PostId,
                projectTitle = e.ProjectTitle,
                status = e.Status,
                role,
                customerId = e.CustomerId,
                customerName = NameOf(e.CustomerId),
                programmerId = e.ProgrammerId,
                programmerName = NameOf(e.ProgrammerId),
                agreedAmount = e.AgreedAmount,
                durationDays = e.DurationDays,
                deadlineAt = e.DeadlineAt,
                createdAt = e.CreatedAt,
                completedAt = e.CompletedAt,
                cancelledAt = e.CancelledAt,
                revisionsUsed = e.RevisionsUsed,
                maxRevisions = MaxRevisions,
                criteriaTotal = e.CriteriaTotal,
                criteriaAccepted = accepted,
                criteriaMet = e.CriteriaMet,
                cancellation = e.CancellationRequestedBy == null && e.Status != EngagementStatuses.Cancelled ? null : new
                {
                    requestedBy = e.CancellationRequestedBy,
                    requestedByName = e.CancellationRequestedBy == null ? null : NameOf(e.CancellationRequestedBy),
                    reason = e.CancellationReason,
                    requestedAt = e.CancellationRequestedAt
                },
                criteria = e.Criteria.OrderBy(c => c.SortOrder).Select(c =>
                {
                    var latest = deliveries.SelectMany(d => d.Items.Select(i => (d.Round, i))).Where(x => x.i.CriterionId == c.Id)
                        .OrderByDescending(x => x.Round).Select(x => x.i).FirstOrDefault();
                    return new
                    {
                        id = c.Id,
                        order = c.SortOrder,
                        text = c.Text,
                        status = c.Status,
                        waived = c.Waived,
                        claim = latest?.Claim,
                        evidence = latest?.Evidence,
                        decision = latest?.Decision,
                        reviewNote = latest?.ReviewNote
                    };
                }).ToList(),
                deliveries = deliveries.Select(d => new
                {
                    round = d.Round,
                    note = d.Note,
                    createdAt = d.CreatedAt,
                    reviewedAt = d.ReviewedAt,
                    metCount = d.Items.Count(i => i.Claim == DeliveryClaims.Met),
                    itemCount = d.Items.Count
                }).ToList(),
                timeline = e.Events.OrderBy(x => x.CreatedAt).ThenBy(x => x.Id).Select(x => new
                {
                    type = x.Type,
                    message = x.Message,
                    actorName = NameOf(x.ActorId),
                    createdAt = x.CreatedAt
                }).ToList(),
                actions = new
                {
                    canDeliver = role == "programmer" && e.Status == EngagementStatuses.Active,
                    canReview = role == "customer" && e.Status == EngagementStatuses.Delivered,
                    canRequestRevision = role == "customer" && e.Status == EngagementStatuses.Delivered && e.RevisionsUsed < MaxRevisions,
                    canRequestCancellation = role != "admin" && open && e.CancellationRequestedBy == null,
                    canAnswerCancellation = role != "admin" && pendingCancel && e.CancellationRequestedBy != callerId,
                    canAdminCancel = role == "admin" && open
                }
            });
        }

        /// <summary>The caller's engagements: open ones first, then the newest.</summary>
        public async Task<List<object>> Mine(int callerId)
        {
            var rows = await _context.Engagements.AsNoTracking()
                .Include(e => e.Criteria)
                .Where(e => e.CustomerId == callerId || e.ProgrammerId == callerId)
                .ToListAsync();
            var names = await NamesAsync(rows.SelectMany(e => new[] { e.CustomerId, e.ProgrammerId }).Distinct().ToArray());

            return rows
                .OrderBy(e => IsClosed(e) ? 1 : 0)
                .ThenByDescending(e => e.UpdatedAt ?? e.CreatedAt)
                .Select(e =>
                {
                    var role = Role(e, callerId);
                    var other = role == "customer" ? e.ProgrammerId : e.CustomerId;
                    var needsMe = (role == "programmer" && e.Status == EngagementStatuses.Active) ||
                                  (role == "customer" && e.Status == EngagementStatuses.Delivered) ||
                                  (!IsClosed(e) && e.CancellationRequestedBy != null && e.CancellationRequestedBy != callerId);
                    return (object)new
                    {
                        id = e.Id,
                        projectId = e.PostId,
                        projectTitle = e.ProjectTitle,
                        status = e.Status,
                        role,
                        otherPartyName = names.GetValueOrDefault(other, role == "customer" ? "Programmer" : "Customer"),
                        criteriaTotal = e.CriteriaTotal,
                        criteriaAccepted = e.Criteria.Count(c => c.Status == EngagementCriterionStatuses.Accepted),
                        criteriaMet = e.CriteriaMet,
                        revisionsUsed = e.RevisionsUsed,
                        agreedAmount = e.AgreedAmount,
                        deadlineAt = e.DeadlineAt,
                        cancellationPending = !IsClosed(e) && e.CancellationRequestedBy != null,
                        needsMyAction = needsMe,
                        updatedAt = e.UpdatedAt ?? e.CreatedAt
                    };
                }).ToList();
        }

        /// <summary>Completed engagements shown on a programmer's profile. The amount stays private.</summary>
        public static IQueryable<object> CompletedFor(AppDbContext context, int programmerId) =>
            context.Engagements.AsNoTracking()
                .Where(e => e.ProgrammerId == programmerId && e.Status == EngagementStatuses.Completed)
                .OrderByDescending(e => e.CompletedAt)
                .Select(e => (object)new
                {
                    engagementId = e.Id,
                    projectTitle = e.ProjectTitle,
                    completedAt = e.CompletedAt,
                    criteriaMet = e.CriteriaMet ?? 0,
                    criteriaTotal = e.CriteriaTotal
                });
    }
}
