using System.Net;
using System.Text.Json;
using DataBase.Models;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // Engagements: accept, deliver, review, complete and cancel, under enforced authorization.
    public class EngagementTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public EngagementTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private static readonly string Approach =
            "I will build the booking flow first, then notifications, and test double bookings with parallel requests before delivery.";

        private Task<WriteScenario> Scenario() => WriteRoutes.ScenarioAsync(_factory, _client);

        private Task<HttpResponseMessage> Send(HttpMethod method, string path, Account? caller, object? body = null) =>
            WriteRoutes.SendAsync(_client, WriteRoutes.Json(method, path, body), caller?.Token);

        private static async Task<JsonElement> Json(HttpResponseMessage response) =>
            JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

        private static async Task<string?> Message(HttpResponseMessage response) =>
            (await Json(response)).TryGetProperty("message", out var m) ? m.GetString() : null;

        private sealed record Setup(WriteScenario S, int ProjectId, int ApplicationId, int EngagementId, int[] CriterionIds);

        private async Task<(int ProjectId, int ApplicationId)> ProjectWithApplicationAsync(WriteScenario s, Account? programmer = null)
        {
            var create = await Send(HttpMethod.Post, "/api/Projects", s.Owner, new
            {
                title = "Booking site for a salon",
                problemStatement = "Clients call to book today, and two people sometimes get the same time slot.",
                budgetMin = 300m,
                budgetMax = 500m,
                deadlineDays = 18,
                criteria = new[]
                {
                    "A customer can book a 30-minute slot from a phone.",
                    "The salon receives a message for every new booking.",
                    "Two customers cannot book the same slot at once.",
                }
            });
            Assert.Equal(HttpStatusCode.OK, create.StatusCode);
            var projectId = (await Json(create)).GetProperty("id").GetInt32();
            int[] ids = Array.Empty<int>();
            await _factory.WithDbAsync(async db =>
            {
                (await db.Posts.SingleAsync(p => p.Id == projectId)).Status = "Approved";
                await db.SaveChangesAsync();
                ids = await db.AcceptanceCriteria.Where(c => c.PostId == projectId).OrderBy(c => c.SortOrder).Select(c => c.Id).ToArrayAsync();
            });

            var apply = await Send(HttpMethod.Post, $"/api/Posts/{projectId}/apply", programmer ?? s.Programmer, new
            {
                proposal = Approach,
                price = 420m,
                durationDays = 12,
                responses = ids.Select(id => new { criterionId = id, response = "WillMeet" }).ToArray()
            });
            Assert.Equal(HttpStatusCode.OK, apply.StatusCode);
            return (projectId, (await Json(apply)).GetProperty("applicationId").GetInt32());
        }

        private async Task<Setup> EngagedAsync()
        {
            var s = await Scenario();
            var (projectId, applicationId) = await ProjectWithApplicationAsync(s);
            var accept = await Send(HttpMethod.Post, $"/api/Posts/{projectId}/applications/{applicationId}/accept", s.Owner);
            Assert.Equal(HttpStatusCode.OK, accept.StatusCode);
            var engagementId = (await Json(accept)).GetProperty("engagementId").GetInt32();
            int[] ids = Array.Empty<int>();
            await _factory.WithDbAsync(async db =>
                ids = await db.EngagementCriteria.Where(c => c.EngagementId == engagementId).OrderBy(c => c.SortOrder).Select(c => c.Id).ToArrayAsync());
            return new Setup(s, projectId, applicationId, engagementId, ids);
        }

        private static object Delivery(IEnumerable<int> ids, params string[] claims) => new
        {
            note = "Everything is deployed to the staging link for you to try.",
            items = ids.Select((id, i) => new
            {
                criterionId = id,
                claim = i < claims.Length ? claims[i] : "Met",
                evidence = "https://staging.example.test/booking"
            }).ToArray()
        };

        private static object Review(IEnumerable<int> ids, Func<int, (string decision, string? note, bool waive)>? pick = null) => new
        {
            items = ids.Select((id, i) =>
            {
                var (decision, note, waive) = pick?.Invoke(i) ?? ("Accept", null, false);
                return new { criterionId = id, decision, note, waive };
            }).ToArray()
        };

        private Task<HttpResponseMessage> Deliver(Setup x, object body, Account? caller = null) =>
            Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/deliveries", caller ?? x.S.Programmer, body);

        private Task<HttpResponseMessage> ReviewIt(Setup x, object body, Account? caller = null) =>
            Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/review", caller ?? x.S.Owner, body);

        private async Task<Engagement> LoadAsync(int id)
        {
            Engagement? e = null;
            await _factory.WithDbAsync(async db =>
                e = await db.Engagements.AsNoTracking().Include(x => x.Criteria).Include(x => x.Events).Include(x => x.Deliveries)
                    .SingleAsync(x => x.Id == id));
            return e!;
        }

        // ---------------- creation ----------------

        [Fact]
        public async Task Accepting_an_application_creates_an_active_engagement_with_a_snapshot()
        {
            var x = await EngagedAsync();
            var e = await LoadAsync(x.EngagementId);

            Assert.Equal(EngagementStatuses.Active, e.Status);
            Assert.Equal(x.ProjectId, e.PostId);
            Assert.Equal(x.ApplicationId, e.ApplicationId);
            Assert.Equal(x.S.Owner.Id, e.CustomerId);
            Assert.Equal(x.S.Programmer.Id, e.ProgrammerId);
            Assert.Equal(420m, e.AgreedAmount);
            Assert.Equal(12, e.DurationDays);
            Assert.True(e.DeadlineAt > DateTime.UtcNow.AddDays(11) && e.DeadlineAt < DateTime.UtcNow.AddDays(13));
            Assert.Equal(3, e.CriteriaTotal);
            Assert.All(e.Criteria, c => Assert.Equal(EngagementCriterionStatuses.Open, c.Status));
            Assert.Equal("Started", Assert.Single(e.Events).Type);

            // The copy does not follow later edits to the project's criteria.
            await _factory.WithDbAsync(async db =>
            {
                foreach (var c in db.AcceptanceCriteria.Where(c => c.PostId == x.ProjectId)) c.Text = "Changed after the agreement was made.";
                await db.SaveChangesAsync();
            });
            var after = await LoadAsync(x.EngagementId);
            Assert.Equal("A customer can book a 30-minute slot from a phone.", after.Criteria.OrderBy(c => c.SortOrder).First().Text);
        }

        [Fact]
        public async Task Accepting_a_social_post_application_creates_no_engagement()
        {
            var s = await Scenario();
            var accept = await Send(HttpMethod.Post, $"/api/Posts/{s.PostId}/applications/{s.ApplicationId}/accept", s.Owner);
            Assert.Equal(HttpStatusCode.OK, accept.StatusCode);
            await _factory.WithDbAsync(async db => Assert.False(await db.Engagements.AnyAsync(e => e.PostId == s.PostId)));
        }

        // ---------------- authorization ----------------

        [Fact]
        public async Task Only_the_two_parties_and_admins_can_read_an_engagement()
        {
            var x = await EngagedAsync();
            var path = $"/api/Engagements/{x.EngagementId}";

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Get, path, x.S.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Get, path, x.S.Programmer)).StatusCode);
            var admin = await Send(HttpMethod.Get, path, x.S.Admin);
            Assert.Equal(HttpStatusCode.OK, admin.StatusCode);
            Assert.Equal("admin", (await Json(admin)).GetProperty("role").GetString());
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, x.S.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, x.S.OtherProgrammer)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(HttpMethod.Get, path, null)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Get, "/api/Engagements/999999", x.S.Owner)).StatusCode);
        }

        public static IEnumerable<object[]> RefusedActions => new[]
        {
            // action, caller, expected status
            new object[] { "deliver", "owner", HttpStatusCode.Forbidden },
            new object[] { "deliver", "otherProgrammer", HttpStatusCode.Forbidden },
            new object[] { "deliver", "admin", HttpStatusCode.Forbidden },
            new object[] { "deliver", "anonymous", HttpStatusCode.Unauthorized },
            new object[] { "review", "programmer", HttpStatusCode.Forbidden },
            new object[] { "review", "other", HttpStatusCode.Forbidden },
            new object[] { "review", "admin", HttpStatusCode.Forbidden },
            new object[] { "cancel", "other", HttpStatusCode.Forbidden },
            new object[] { "cancel", "otherProgrammer", HttpStatusCode.Forbidden },
            new object[] { "cancel", "admin", HttpStatusCode.Forbidden },
            new object[] { "agree", "otherProgrammer", HttpStatusCode.Forbidden },
            new object[] { "decline", "other", HttpStatusCode.Forbidden },
            new object[] { "adminCancel", "owner", HttpStatusCode.Forbidden },
            new object[] { "adminCancel", "programmer", HttpStatusCode.Forbidden },
        };

        [Theory]
        [MemberData(nameof(RefusedActions))]
        public async Task Actions_are_refused_for_everyone_but_the_rightful_party(string action, string caller, HttpStatusCode expected)
        {
            var x = await EngagedAsync();
            var s = x.S;
            if (action is "review") Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(x.CriterionIds))).StatusCode);
            if (action is "agree" or "decline")
                Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/cancellation", s.Owner, new { reason = "The salon closed for the season." })).StatusCode);

            var who = caller switch
            {
                "owner" => s.Owner, "other" => s.Other, "programmer" => s.Programmer, "otherProgrammer" => s.OtherProgrammer,
                "admin" => s.Admin, _ => null
            };
            var before = await LoadAsync(x.EngagementId);

            var response = action switch
            {
                "deliver" => await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/deliveries", who, Delivery(x.CriterionIds)),
                "review" => await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/review", who, Review(x.CriterionIds)),
                "cancel" => await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/cancellation", who, new { reason = "Changing my plans entirely." }),
                "agree" => await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/cancellation/agree", who),
                "decline" => await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/cancellation/decline", who),
                _ => await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/admin-cancel", who, new { reason = "Reported as a duplicate." }),
            };

            Assert.Equal(expected, response.StatusCode);
            var after = await LoadAsync(x.EngagementId);
            Assert.Equal(before.Status, after.Status);
            Assert.Equal(before.Events.Count, after.Events.Count);
            Assert.Equal(before.CancellationRequestedBy, after.CancellationRequestedBy);
        }

        [Fact]
        public async Task My_engagements_lists_only_the_callers_own()
        {
            var x = await EngagedAsync();
            async Task<int[]> Ids(Account a) =>
                (await Json(await Send(HttpMethod.Get, "/api/Engagements/mine", a))).GetProperty("engagements").EnumerateArray()
                .Select(e => e.GetProperty("id").GetInt32()).ToArray();

            Assert.Contains(x.EngagementId, await Ids(x.S.Owner));
            Assert.Contains(x.EngagementId, await Ids(x.S.Programmer));
            Assert.DoesNotContain(x.EngagementId, await Ids(x.S.Other));
            Assert.DoesNotContain(x.EngagementId, await Ids(x.S.OtherProgrammer));
        }

        [Fact]
        public async Task Project_details_show_the_engagement_only_to_the_parties()
        {
            var x = await EngagedAsync();
            async Task<JsonElement> EngagementIdFor(Account a) =>
                (await Json(await Send(HttpMethod.Get, $"/api/Projects/{x.ProjectId}", a))).GetProperty("engagementId");

            Assert.Equal(x.EngagementId, (await EngagementIdFor(x.S.Owner)).GetInt32());
            Assert.Equal(x.EngagementId, (await EngagementIdFor(x.S.Programmer)).GetInt32());
            Assert.Equal(JsonValueKind.Null, (await EngagementIdFor(x.S.OtherProgrammer)).ValueKind);
        }

        // ---------------- delivery validation ----------------

        public static IEnumerable<object[]> InvalidDeliveries => new[]
        {
            new object[] { "missing", "Answer requirement 3." },
            new object[] { "bad claim", "Requirement 1: choose Met or Not met." },
            new object[] { "evidence 4", "Requirement 1: add evidence of 5–500 characters, such as a note or a link." },
            new object[] { "evidence 501", "Requirement 1: add evidence of 5–500 characters, such as a note or a link." },
            new object[] { "note 4", "Add an overall note of 5–1000 characters." },
            new object[] { "unknown", "An answer refers to a requirement that isn't in this engagement." },
            new object[] { "duplicate", "Answer each requirement once." },
        };

        [Theory]
        [MemberData(nameof(InvalidDeliveries))]
        public async Task An_incomplete_or_invalid_delivery_is_refused(string kind, string message)
        {
            var x = await EngagedAsync();
            var ids = x.CriterionIds;
            object Item(int id, string claim = "Met", string evidence = "https://staging.example.test") => new { criterionId = id, claim, evidence };
            object Body(string note, params object[] items) => new { note, items };
            const string note = "Ready for review on staging.";

            var body = kind switch
            {
                "missing" => Body(note, Item(ids[0]), Item(ids[1])),
                "bad claim" => Body(note, Item(ids[0], "Maybe"), Item(ids[1]), Item(ids[2])),
                "evidence 4" => Body(note, Item(ids[0], evidence: "link"), Item(ids[1]), Item(ids[2])),
                "evidence 501" => Body(note, Item(ids[0], evidence: new string('e', 501)), Item(ids[1]), Item(ids[2])),
                "note 4" => Body("done", Item(ids[0]), Item(ids[1]), Item(ids[2])),
                "unknown" => Body(note, Item(ids[0]), Item(ids[1]), Item(ids[2]), Item(999999)),
                _ => Body(note, Item(ids[0]), Item(ids[0]), Item(ids[1]), Item(ids[2])),
            };

            var response = await Deliver(x, body);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal(message, await Message(response));
            var e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Active, e.Status);
            Assert.Empty(e.Deliveries);
        }

        // ---------------- the full path ----------------

        [Fact]
        public async Task Deliver_revise_redeliver_and_accept_completes_the_engagement_and_the_project()
        {
            var x = await EngagedAsync();
            var ids = x.CriterionIds;

            Assert.Equal(HttpStatusCode.Conflict, (await ReviewIt(x, Review(ids))).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(ids))).StatusCode);
            Assert.Equal(HttpStatusCode.Conflict, (await Deliver(x, Delivery(ids))).StatusCode);

            // A revision needs a note.
            var noNote = await ReviewIt(x, Review(ids, i => i == 2 ? ("Revise", null, false) : ("Accept", null, false)));
            Assert.Equal(HttpStatusCode.BadRequest, noNote.StatusCode);
            Assert.Equal("Requirement 3: explain what needs revision in 5–500 characters.", await Message(noNote));

            var revise = await ReviewIt(x, Review(ids, i => i == 2 ? ("Revise", "Two phones booked 10:00 at the same time.", false) : ("Accept", null, false)));
            Assert.Equal(HttpStatusCode.OK, revise.StatusCode);
            var e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Active, e.Status);
            Assert.Equal(1, e.RevisionsUsed);
            Assert.Equal(2, e.Criteria.Count(c => c.Status == EngagementCriterionStatuses.Accepted));
            Assert.Equal(EngagementCriterionStatuses.NeedsRevision, e.Criteria.Single(c => c.Id == ids[2]).Status);

            // The re-delivery answers only what is still open; accepted ones are refused.
            var withAccepted = await Deliver(x, Delivery(ids));
            Assert.Equal(HttpStatusCode.BadRequest, withAccepted.StatusCode);
            Assert.Equal("Requirement 1 is already accepted.", await Message(withAccepted));
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(new[] { ids[2] }))).StatusCode);

            // The review covers exactly the re-delivered requirement.
            Assert.Equal(HttpStatusCode.BadRequest, (await ReviewIt(x, Review(ids))).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await ReviewIt(x, Review(new[] { ids[2] }))).StatusCode);

            e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Completed, e.Status);
            Assert.NotNull(e.CompletedAt);
            Assert.Equal(3, e.CriteriaMet);
            Assert.Equal(new[] { "Started", "Delivered", "RevisionRequested", "Delivered", "Completed" },
                e.Events.OrderBy(v => v.Id).Select(v => v.Type));
            await _factory.WithDbAsync(async db => Assert.NotNull((await db.Posts.SingleAsync(p => p.Id == x.ProjectId)).CompletedAt));

            // Closed: nothing else changes it.
            Assert.Equal(HttpStatusCode.Conflict, (await Deliver(x, Delivery(ids))).StatusCode);
            Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/cancellation", x.S.Owner, new { reason = "Too late to cancel now." })).StatusCode);

            // The programmer's profile shows the record.
            var profile = await Json(await Send(HttpMethod.Get, $"/api/ProgrammerProfile/{x.S.Programmer.Id}", x.S.Other));
            var record = Assert.Single(profile.GetProperty("completedEngagements").EnumerateArray());
            Assert.Equal(3, record.GetProperty("criteriaMet").GetInt32());
            Assert.Equal(3, record.GetProperty("criteriaTotal").GetInt32());
            Assert.False(record.TryGetProperty("agreedAmount", out _));
        }

        [Fact]
        public async Task Accepting_a_requirement_marked_not_met_needs_a_waiver_and_lowers_criteria_met()
        {
            var x = await EngagedAsync();
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(x.CriterionIds, "Met", "NotMet"))).StatusCode);

            var noWaiver = await ReviewIt(x, Review(x.CriterionIds));
            Assert.Equal(HttpStatusCode.BadRequest, noWaiver.StatusCode);
            Assert.Equal("Requirement 2 was marked not met. Confirm the waiver to accept it.", await Message(noWaiver));

            Assert.Equal(HttpStatusCode.OK, (await ReviewIt(x, Review(x.CriterionIds, i => ("Accept", null, i == 1)))).StatusCode);
            var e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Completed, e.Status);
            Assert.Equal(2, e.CriteriaMet);
            Assert.True(e.Criteria.Single(c => c.Id == x.CriterionIds[1]).Waived);
        }

        [Fact]
        public async Task After_two_revision_rounds_only_accept_or_cancel_remain()
        {
            var x = await EngagedAsync();
            var last = new[] { x.CriterionIds[0] };
            var reviseFirst = Review(x.CriterionIds, i => i == 0 ? ("Revise", "The phone layout breaks on small screens.", false) : ("Accept", null, false));

            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(x.CriterionIds))).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await ReviewIt(x, reviseFirst)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(last))).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await ReviewIt(x, Review(last, _ => ("Revise", "Still broken on a 360px screen.", false)))).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(last))).StatusCode);

            var third = await ReviewIt(x, Review(last, _ => ("Revise", "One more time, please.", false)));
            Assert.Equal(HttpStatusCode.BadRequest, third.StatusCode);
            Assert.Equal("No revision rounds are left. Accept the remaining requirements or request cancellation.", await Message(third));

            var view = await Json(await Send(HttpMethod.Get, $"/api/Engagements/{x.EngagementId}", x.S.Owner));
            Assert.True(view.GetProperty("actions").GetProperty("canReview").GetBoolean());
            Assert.False(view.GetProperty("actions").GetProperty("canRequestRevision").GetBoolean());
            Assert.True(view.GetProperty("actions").GetProperty("canRequestCancellation").GetBoolean());

            Assert.Equal(HttpStatusCode.OK, (await ReviewIt(x, Review(last))).StatusCode);
            Assert.Equal(EngagementStatuses.Completed, (await LoadAsync(x.EngagementId)).Status);
        }

        // ---------------- cancellation ----------------

        [Fact]
        public async Task Cancellation_needs_the_other_party_and_a_decline_lets_work_continue()
        {
            var x = await EngagedAsync();
            var path = $"/api/Engagements/{x.EngagementId}/cancellation";

            var shortReason = await Send(HttpMethod.Post, path, x.S.Programmer, new { reason = "no" });
            Assert.Equal(HttpStatusCode.BadRequest, shortReason.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, path, x.S.Programmer, new { reason = "I can no longer take this on." })).StatusCode);
            Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Post, path, x.S.Owner, new { reason = "I also want to cancel this." })).StatusCode);

            // The requester cannot answer their own request.
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Post, path + "/agree", x.S.Programmer)).StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, path + "/decline", x.S.Owner)).StatusCode);
            var e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Active, e.Status);
            Assert.Null(e.CancellationRequestedBy);
            Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Post, path + "/agree", x.S.Owner)).StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, path, x.S.Owner, new { reason = "The salon closed for the season." })).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, path + "/agree", x.S.Programmer)).StatusCode);
            e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Cancelled, e.Status);
            Assert.NotNull(e.CancelledAt);
            Assert.Equal(HttpStatusCode.Conflict, (await Deliver(x, Delivery(x.CriterionIds))).StatusCode);

            var profile = await Json(await Send(HttpMethod.Get, $"/api/ProgrammerProfile/{x.S.Programmer.Id}", x.S.Owner));
            Assert.Empty(profile.GetProperty("completedEngagements").EnumerateArray());
        }

        [Fact]
        public async Task An_admin_can_cancel_and_both_parties_are_told()
        {
            var x = await EngagedAsync();
            var response = await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/admin-cancel", x.S.Admin, new { reason = "Reported as a duplicate project." });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal(EngagementStatuses.Cancelled, (await LoadAsync(x.EngagementId)).Status);
            await _factory.WithDbAsync(async db =>
            {
                Assert.True(await db.Notifications.AnyAsync(n => n.UserId == x.S.Owner.Id && n.Type == "engagement" && n.ReferenceId == x.EngagementId));
                Assert.True(await db.Notifications.AnyAsync(n => n.UserId == x.S.Programmer.Id && n.Type == "engagement" && n.ReferenceId == x.EngagementId));
            });
            Assert.Equal(HttpStatusCode.Conflict,
                (await Send(HttpMethod.Post, $"/api/Engagements/{x.EngagementId}/admin-cancel", x.S.Admin, new { reason = "Again, by mistake." })).StatusCode);
        }

        // ---------------- notifications ----------------

        [Fact]
        public async Task Each_step_notifies_the_other_party()
        {
            var x = await EngagedAsync();
            async Task<string[]> Titles(Account a)
            {
                string[] titles = Array.Empty<string>();
                await _factory.WithDbAsync(async db => titles = await db.Notifications
                    .Where(n => n.UserId == a.Id && n.Type == "engagement" && n.ReferenceId == x.EngagementId)
                    .OrderBy(n => n.Id).Select(n => n.Title).ToArrayAsync());
                return titles;
            }

            await Deliver(x, Delivery(x.CriterionIds));
            await ReviewIt(x, Review(x.CriterionIds, i => i == 0 ? ("Revise", "Please add the cancel button.", false) : ("Accept", null, false)));
            await Deliver(x, Delivery(new[] { x.CriterionIds[0] }));
            await ReviewIt(x, Review(new[] { x.CriterionIds[0] }));

            Assert.Equal(new[] { "Delivery submitted", "Delivery submitted" }, await Titles(x.S.Owner));
            Assert.Equal(new[] { "Revision requested", "Work accepted" }, await Titles(x.S.Programmer));
        }

        // ---------------- concurrency ----------------

        [Fact]
        public async Task Two_deliveries_at_once_store_exactly_one()
        {
            var x = await EngagedAsync();
            var results = await Task.WhenAll(Deliver(x, Delivery(x.CriterionIds)), Deliver(x, Delivery(x.CriterionIds)));

            Assert.Single(results, r => r.StatusCode == HttpStatusCode.OK);
            Assert.Single(results, r => r.StatusCode == HttpStatusCode.Conflict);
            var e = await LoadAsync(x.EngagementId);
            Assert.Single(e.Deliveries);
            Assert.Single(e.Events, v => v.Type == "Delivered");
        }

        [Fact]
        public async Task Two_accepting_reviews_at_once_complete_once()
        {
            var x = await EngagedAsync();
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(x.CriterionIds))).StatusCode);

            var results = await Task.WhenAll(ReviewIt(x, Review(x.CriterionIds)), ReviewIt(x, Review(x.CriterionIds)));

            Assert.Single(results, r => r.StatusCode == HttpStatusCode.OK);
            Assert.Single(results, r => r.StatusCode == HttpStatusCode.Conflict);
            var e = await LoadAsync(x.EngagementId);
            Assert.Equal(EngagementStatuses.Completed, e.Status);
            Assert.Single(e.Events, v => v.Type == "Completed");
            await _factory.WithDbAsync(async db =>
                Assert.Equal(1, await db.Notifications.CountAsync(n => n.UserId == x.S.Programmer.Id && n.Title == "Work accepted" && n.ReferenceId == x.EngagementId)));
        }

        [Fact]
        public async Task Two_accepts_at_once_start_one_engagement()
        {
            var s = await Scenario();
            var (projectId, first) = await ProjectWithApplicationAsync(s);
            var apply = await Send(HttpMethod.Post, $"/api/Posts/{projectId}/apply", s.OtherProgrammer, new
            {
                proposal = Approach,
                price = 380m,
                durationDays = 10,
                responses = await CriterionAnswers(projectId)
            });
            Assert.Equal(HttpStatusCode.OK, apply.StatusCode);
            var second = (await Json(apply)).GetProperty("applicationId").GetInt32();

            var results = await Task.WhenAll(
                Send(HttpMethod.Post, $"/api/Posts/{projectId}/applications/{first}/accept", s.Owner),
                Send(HttpMethod.Post, $"/api/Posts/{projectId}/applications/{second}/accept", s.Owner));

            Assert.Single(results, r => r.StatusCode == HttpStatusCode.OK);
            Assert.Single(results, r => r.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.BadRequest);
            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal(1, await db.Engagements.CountAsync(e => e.PostId == projectId));
                Assert.Equal(1, await db.PostApplications.CountAsync(a => a.PostId == projectId && a.Status == "Accepted"));
            });
        }

        private async Task<object[]> CriterionAnswers(int projectId)
        {
            int[] ids = Array.Empty<int>();
            await _factory.WithDbAsync(async db => ids = await db.AcceptanceCriteria.Where(c => c.PostId == projectId).Select(c => c.Id).ToArrayAsync());
            return ids.Select(id => (object)new { criterionId = id, response = "WillMeet" }).ToArray();
        }

        // ---------------- deletes ----------------

        [Fact]
        public async Task Deleting_either_party_removes_their_engagements()
        {
            var x = await EngagedAsync();
            Assert.Equal(HttpStatusCode.OK, (await Deliver(x, Delivery(x.CriterionIds))).StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Delete, $"/api/Admin/users/{x.S.Programmer.Id}", x.S.Admin)).StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.False(await db.Engagements.AnyAsync(e => e.Id == x.EngagementId));
                Assert.False(await db.EngagementCriteria.AnyAsync(c => c.EngagementId == x.EngagementId));
                Assert.False(await db.EngagementEvents.AnyAsync(v => v.EngagementId == x.EngagementId));
            });

            var y = await EngagedAsync();
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Delete, $"/api/Admin/users/{y.S.Owner.Id}", y.S.Admin)).StatusCode);
            await _factory.WithDbAsync(async db => Assert.False(await db.Engagements.AnyAsync(e => e.Id == y.EngagementId)));
        }
    }
}
