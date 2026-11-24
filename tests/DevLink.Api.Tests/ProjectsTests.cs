using System.Net;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // Customer projects with acceptance criteria, under enforced authorization.
    public class ProjectsTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public ProjectsTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<WriteScenario> Scenario() => WriteRoutes.ScenarioAsync(_factory, _client);

        private Task<HttpResponseMessage> Send(HttpMethod method, string path, Account? caller, object? body = null) =>
            WriteRoutes.SendAsync(_client, WriteRoutes.Json(method, path, body), caller?.Token);

        private static async Task<JsonElement> Json(HttpResponseMessage response) =>
            JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

        private static readonly string[] GoodCriteria =
        {
            "A customer can book a 30-minute slot from a phone.",
            "The salon receives a message for every new booking.",
            "Two customers cannot book the same slot at once.",
        };

        private static object Body(string? title = "Booking site for a salon", string? problem = null, decimal? min = 300, decimal? max = 500,
            int? deadline = 18, IEnumerable<string>? criteria = null) => new
        {
            title,
            problemStatement = problem ?? "Clients call to book today, and two people sometimes get the same time slot.",
            targetUsers = "Salon customers on their phones, and the owner on a laptop.",
            budgetMin = min,
            budgetMax = max,
            deadlineDays = deadline,
            criteria = (criteria ?? GoodCriteria).ToArray()
        };

        private async Task<int> CreateAsync(Account customer, object? body = null)
        {
            var response = await Send(HttpMethod.Post, "/api/Projects", customer, body ?? Body());
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return (await Json(response)).GetProperty("id").GetInt32();
        }

        private Task SetStatusAsync(int id, string status, string? reason = null) =>
            _factory.WithDbAsync(async db =>
            {
                var post = await db.Posts.SingleAsync(p => p.Id == id);
                post.Status = status;
                post.RejectionReason = reason;
                await db.SaveChangesAsync();
            });

        // ---------------- authorization matrix ----------------

        public static IEnumerable<object[]> CustomerRoutes => new[]
        {
            new object[] { "POST", "/api/Projects" },
            new object[] { "PUT", "/api/Projects/{id}" },
            new object[] { "POST", "/api/Projects/readiness" },
        };

        [Theory]
        [MemberData(nameof(CustomerRoutes))]
        public async Task Customer_routes_refuse_anonymous_programmers_and_admins(string method, string template)
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);
            var path = template.Replace("{id}", id.ToString());
            var verb = new HttpMethod(method);

            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(verb, path, null, Body())).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(verb, path, s.Programmer, Body())).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(verb, path, s.Admin, Body())).StatusCode);
        }

        [Fact]
        public async Task Details_needs_a_token_and_is_open_to_every_role_once_approved()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);
            await SetStatusAsync(id, "Approved");

            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(HttpMethod.Get, $"/api/Projects/{id}", null)).StatusCode);
            foreach (var caller in new[] { s.Owner, s.Other, s.Programmer, s.Admin })
                Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Get, $"/api/Projects/{id}", caller)).StatusCode);
        }

        [Fact]
        public async Task Pending_and_rejected_projects_are_visible_only_to_owner_and_admin()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);

            foreach (var status in new[] { "Pending", "Rejected" })
            {
                await SetStatusAsync(id, status, status == "Rejected" ? "Too vague" : null);
                Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Get, $"/api/Projects/{id}", s.Owner)).StatusCode);
                Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Get, $"/api/Projects/{id}", s.Admin)).StatusCode);
                Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Get, $"/api/Projects/{id}", s.Programmer)).StatusCode);
                Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Get, $"/api/Projects/{id}", s.Other)).StatusCode);
            }
        }

        [Fact]
        public async Task Only_the_owner_can_update_and_only_while_pending_or_rejected()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);

            var other = await Send(HttpMethod.Put, $"/api/Projects/{id}", s.Other, Body(title: "Someone else's edit"));
            Assert.Equal(HttpStatusCode.Forbidden, other.StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Put, $"/api/Projects/{id}", s.Owner, Body(title: "Booking site, second draft"))).StatusCode);

            await SetStatusAsync(id, "Approved");
            Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Put, $"/api/Projects/{id}", s.Owner, Body())).StatusCode);

            Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Put, "/api/Projects/987654321", s.Owner, Body())).StatusCode);
            // A social post is not a project.
            Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Put, $"/api/Projects/{s.PostId}", s.Owner, Body())).StatusCode);
        }

        // ---------------- create and update ----------------

        [Fact]
        public async Task A_new_project_is_pending_with_its_criteria_in_order()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);

            await _factory.WithDbAsync(async db =>
            {
                var post = await db.Posts.Include(p => p.Criteria).SingleAsync(p => p.Id == id);
                Assert.Equal("Pending", post.Status);
                Assert.Equal(s.Owner.Id, post.UserId);
                Assert.Equal(post.ProblemStatement, post.Content);
                Assert.Equal(GoodCriteria, post.Criteria.OrderBy(c => c.SortOrder).Select(c => c.Text));
                Assert.Equal(new[] { 1, 2, 3 }, post.Criteria.Select(c => c.SortOrder).OrderBy(o => o));
            });
        }

        [Fact]
        public async Task Updating_a_rejected_project_resubmits_it_and_replaces_the_criteria()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);
            await SetStatusAsync(id, "Rejected", "Too vague");

            var criteria = GoodCriteria.Reverse().Append("The owner can close days from one simple page.").ToArray();
            var response = await Send(HttpMethod.Put, $"/api/Projects/{id}", s.Owner, Body(criteria: criteria));
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var post = await db.Posts.Include(p => p.Criteria).SingleAsync(p => p.Id == id);
                Assert.Equal("Pending", post.Status);
                Assert.Null(post.RejectionReason);
                Assert.Equal(criteria, post.Criteria.OrderBy(c => c.SortOrder).Select(c => c.Text));
            });
        }

        // ---------------- validation (400) ----------------

        public static IEnumerable<object[]> InvalidBodies => new[]
        {
            new object[] { "no criteria", Body(criteria: Array.Empty<string>()) },
            new object[] { "21 criteria", Body(criteria: Enumerable.Range(1, 21).Select(i => $"Criterion number {i} is checkable.")) },
            new object[] { "criterion too short", Body(criteria: GoodCriteria.Append("Too short")) },
            new object[] { "criterion too long", Body(criteria: GoodCriteria.Append(new string('x', 301))) },
            new object[] { "title too long", Body(title: new string('t', 121)) },
            new object[] { "problem too long", Body(problem: new string('p', 2001)) },
            new object[] { "negative budget", Body(min: -1) },
            new object[] { "deadline zero", Body(deadline: 0) },
            new object[] { "deadline over a year", Body(deadline: 366) },
        };

        [Theory]
        [MemberData(nameof(InvalidBodies))]
        public async Task Invalid_fields_are_refused_with_400(string _, object body)
        {
            var s = await Scenario();
            var response = await Send(HttpMethod.Post, "/api/Projects", s.Owner, body);

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.True((await Json(response)).GetProperty("errors").EnumerateObject().Any());
            await _factory.WithDbAsync(async db => Assert.False(await db.Posts.AnyAsync(p => p.UserId == s.Owner.Id && p.Title != null)));
        }

        [Fact]
        public async Task Twenty_criteria_of_300_characters_are_accepted()
        {
            var s = await Scenario();
            var criteria = Enumerable.Range(1, 20).Select(i => $"{i:D2}" + new string('c', 298));
            await CreateAsync(s.Owner, Body(criteria: criteria));
        }

        // ---------------- readiness ----------------

        public static IEnumerable<object[]> NotReadyBodies => new[]
        {
            new object[] { "TOO_FEW_CRITERIA", Body(criteria: GoodCriteria.Take(2)) },
            new object[] { "TITLE_TOO_SHORT", Body(title: "Booking") },
            new object[] { "PROBLEM_TOO_SHORT", Body(problem: "Double bookings.") },
            new object[] { "BUDGET_INVALID", Body(min: 500, max: 300) },
            new object[] { "BUDGET_INVALID", Body(min: null, max: null) },
            new object[] { "BUDGET_INVALID", Body(min: 0, max: 0) },
        };

        [Theory]
        [MemberData(nameof(NotReadyBodies))]
        public async Task Hard_readiness_rules_block_submission_with_422(string code, object body)
        {
            var s = await Scenario();
            var response = await Send(HttpMethod.Post, "/api/Projects", s.Owner, body);

            Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
            var json = await Json(response);
            Assert.Equal("READINESS_BLOCKING_ISSUES", json.GetProperty("errorCode").GetString());
            var readiness = json.GetProperty("readiness");
            Assert.False(readiness.GetProperty("ready").GetBoolean());
            Assert.Contains(readiness.GetProperty("blocking").EnumerateArray(), b => b.GetProperty("code").GetString() == code);
        }

        [Fact]
        public async Task Vague_words_only_warn()
        {
            var s = await Scenario();
            var criteria = GoodCriteria.Append("The design should look nice and modern.").ToArray();

            var check = await Json(await Send(HttpMethod.Post, "/api/Projects/readiness", s.Owner, Body(criteria: criteria)));
            var readiness = check.GetProperty("readiness");
            Assert.True(readiness.GetProperty("ready").GetBoolean());
            var warning = Assert.Single(readiness.GetProperty("warnings").EnumerateArray());
            Assert.Equal("VAGUE_CRITERION", warning.GetProperty("code").GetString());
            Assert.Equal("criteria[3]", warning.GetProperty("field").GetString());
            Assert.Equal(96, readiness.GetProperty("score").GetInt32());

            await CreateAsync(s.Owner, Body(criteria: criteria));
        }

        [Fact]
        public async Task The_readiness_check_reports_without_saving()
        {
            var s = await Scenario();
            var response = await Send(HttpMethod.Post, "/api/Projects/readiness", s.Owner, Body(criteria: GoodCriteria.Take(2)));

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var readiness = (await Json(response)).GetProperty("readiness");
            Assert.False(readiness.GetProperty("ready").GetBoolean());
            Assert.Equal(90, readiness.GetProperty("score").GetInt32());
            await _factory.WithDbAsync(async db => Assert.False(await db.Posts.AnyAsync(p => p.UserId == s.Owner.Id && p.Title != null)));
        }

        // ---------------- details, feed, moderation ----------------

        [Fact]
        public async Task Details_return_the_numbered_criteria_and_hide_review_data_from_others()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);
            await SetStatusAsync(id, "Approved");

            var asProgrammer = await Json(await Send(HttpMethod.Get, $"/api/Projects/{id}", s.Programmer));
            Assert.Equal(3, asProgrammer.GetProperty("criteriaCount").GetInt32());
            var criteria = asProgrammer.GetProperty("criteria").EnumerateArray().ToList();
            Assert.Equal(new[] { 1, 2, 3 }, criteria.Select(c => c.GetProperty("order").GetInt32()));
            Assert.Equal(GoodCriteria, criteria.Select(c => c.GetProperty("text").GetString()));
            Assert.Equal(JsonValueKind.Null, asProgrammer.GetProperty("readiness").ValueKind);
            Assert.False(asProgrammer.GetProperty("isMine").GetBoolean());

            var asOwner = await Json(await Send(HttpMethod.Get, $"/api/Projects/{id}", s.Owner));
            Assert.True(asOwner.GetProperty("isMine").GetBoolean());
            Assert.True(asOwner.GetProperty("readiness").GetProperty("ready").GetBoolean());

            // A social post has no project details.
            Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Get, $"/api/Projects/{s.PostId}", s.Owner)).StatusCode);
        }

        [Fact]
        public async Task The_feed_carries_a_criteria_count_for_projects_only()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);
            await SetStatusAsync(id, "Approved");

            var feed = await Json(await Send(HttpMethod.Get, $"/api/Posts/feed?userId={s.Programmer.Id}&pageSize=50", s.Programmer));
            var rows = feed.GetProperty("posts").EnumerateArray().ToList();

            var project = rows.Single(p => p.GetProperty("id").GetInt32() == id);
            Assert.True(project.GetProperty("isProject").GetBoolean());
            Assert.Equal(3, project.GetProperty("criteriaCount").GetInt32());
            Assert.Equal("Booking site for a salon", project.GetProperty("title").GetString());

            var social = rows.Single(p => p.GetProperty("id").GetInt32() == s.PostId);
            Assert.False(social.GetProperty("isProject").GetBoolean());
            Assert.Equal(0, social.GetProperty("criteriaCount").GetInt32());
        }

        [Fact]
        public async Task Admin_moderation_lists_pending_projects_with_their_criteria()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);

            var pending = await Json(await Send(HttpMethod.Get, "/api/Posts/pending", s.Admin));
            var row = pending.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == id);
            Assert.True(row.GetProperty("isProject").GetBoolean());
            Assert.Equal(GoodCriteria, row.GetProperty("criteria").EnumerateArray().Select(c => c.GetProperty("text").GetString()));

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, $"/api/Posts/{id}/approve", s.Admin)).StatusCode);
            await _factory.WithDbAsync(async db => Assert.Equal("Approved", (await db.Posts.SingleAsync(p => p.Id == id)).Status));
        }

        [Fact]
        public async Task Programmers_can_apply_to_an_approved_project()
        {
            var s = await Scenario();
            var id = await CreateAsync(s.Owner);
            await SetStatusAsync(id, "Approved");

            var apply = await Send(HttpMethod.Post, $"/api/Posts/{id}/apply", s.Programmer, new { proposal = "I can build it" });
            Assert.Equal(HttpStatusCode.OK, apply.StatusCode);
        }
    }
}
