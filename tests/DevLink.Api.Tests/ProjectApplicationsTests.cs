using System.Net;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // Structured applications to customer projects and the owner's comparison list, under enforced authorization.
    public class ProjectApplicationsTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public ProjectApplicationsTests(SessionApiFactory factory)
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

        private sealed record Project(int Id, int[] CriterionIds);

        private async Task<Project> ProjectAsync(Account owner)
        {
            var create = await Send(HttpMethod.Post, "/api/Projects", owner, new
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
            var id = (await Json(create)).GetProperty("id").GetInt32();
            await _factory.WithDbAsync(async db =>
            {
                (await db.Posts.SingleAsync(p => p.Id == id)).Status = "Approved";
                await db.SaveChangesAsync();
            });
            var ids = new int[0];
            await _factory.WithDbAsync(async db =>
                ids = await db.AcceptanceCriteria.Where(c => c.PostId == id).OrderBy(c => c.SortOrder).Select(c => c.Id).ToArrayAsync());
            return new Project(id, ids);
        }

        private static object[] Answers(int[] ids, params string[] responses) =>
            ids.Select((id, i) => (object)new
            {
                criterionId = id,
                response = i < responses.Length ? responses[i] : "WillMeet",
                note = i < responses.Length && responses[i] != "WillMeet" ? "Which phone models matter most?" : null
            }).ToArray();

        private static object Application(Project p, object[]? answers = null, string? approach = null, decimal? price = 400m, int? days = 14) => new
        {
            proposal = approach ?? Approach,
            price,
            durationDays = days,
            responses = answers ?? Answers(p.CriterionIds)
        };

        private async Task<int> ApplyAsync(Account programmer, Project p, object? body = null)
        {
            var response = await Send(HttpMethod.Post, $"/api/Posts/{p.Id}/apply", programmer, body ?? Application(p));
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return (await Json(response)).GetProperty("applicationId").GetInt32();
        }

        // ---------------- applying ----------------

        [Fact]
        public async Task A_complete_application_stores_every_answer_amount_duration_and_approach()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            var id = await ApplyAsync(s.Programmer, p, Application(p, Answers(p.CriterionIds, "WillMeet", "NeedsClarification", "ProposeChange")));

            await _factory.WithDbAsync(async db =>
            {
                var app = await db.PostApplications.Include(a => a.Responses).SingleAsync(a => a.Id == id);
                Assert.Equal(400m, app.Price);
                Assert.Equal(14, app.DurationDays);
                Assert.Equal(Approach, app.Proposal);
                Assert.Equal(3, app.Responses.Count);
                Assert.Equal(new[] { "WillMeet", "NeedsClarification", "ProposeChange" },
                    app.Responses.OrderBy(r => Array.IndexOf(p.CriterionIds, r.CriterionId)).Select(r => r.Response));
                Assert.Null(app.Responses.Single(r => r.Response == "WillMeet").Note);
            });
        }

        [Fact]
        public async Task A_missing_answer_is_refused_and_names_the_requirement()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            var answers = Answers(p.CriterionIds).Take(2).ToArray();

            var response = await Send(HttpMethod.Post, $"/api/Posts/{p.Id}/apply", s.Programmer, Application(p, answers));
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal("Answer requirement 3.", (await Json(response)).GetProperty("message").GetString());
            await _factory.WithDbAsync(async db => Assert.False(await db.PostApplications.AnyAsync(a => a.PostId == p.Id)));
        }

        public static IEnumerable<object[]> InvalidApplications => new[]
        {
            new object[] { "approach 99 chars" }, new object[] { "approach 1501 chars" }, new object[] { "no amount" }, new object[] { "zero amount" },
            new object[] { "no duration" }, new object[] { "duration 0" }, new object[] { "duration 366" }, new object[] { "unknown response" },
            new object[] { "clarify without note" }, new object[] { "note 4 chars" }, new object[] { "note 301 chars" },
            new object[] { "unknown criterion" }, new object[] { "duplicate criterion" },
        };

        [Theory]
        [MemberData(nameof(InvalidApplications))]
        public async Task Invalid_applications_are_refused(string kind)
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            var ids = p.CriterionIds;
            object Answer(int id, string response, string? note) => new { criterionId = id, response, note };

            object body = kind switch
            {
                "approach 99 chars" => Application(p, approach: new string('a', 99)),
                "approach 1501 chars" => Application(p, approach: new string('a', 1501)),
                "no amount" => Application(p, price: null),
                "zero amount" => Application(p, price: 0m),
                "no duration" => Application(p, days: null),
                "duration 0" => Application(p, days: 0),
                "duration 366" => Application(p, days: 366),
                "unknown response" => Application(p, new[] { Answer(ids[0], "Maybe", null), Answer(ids[1], "WillMeet", null), Answer(ids[2], "WillMeet", null) }),
                "clarify without note" => Application(p, new[] { Answer(ids[0], "NeedsClarification", null), Answer(ids[1], "WillMeet", null), Answer(ids[2], "WillMeet", null) }),
                "note 4 chars" => Application(p, new[] { Answer(ids[0], "ProposeChange", "abcd"), Answer(ids[1], "WillMeet", null), Answer(ids[2], "WillMeet", null) }),
                "note 301 chars" => Application(p, new[] { Answer(ids[0], "WillMeet", new string('n', 301)), Answer(ids[1], "WillMeet", null), Answer(ids[2], "WillMeet", null) }),
                "unknown criterion" => Application(p, new[] { Answer(ids[0], "WillMeet", null), Answer(ids[1], "WillMeet", null), Answer(ids[2], "WillMeet", null), Answer(987654, "WillMeet", null) }),
                _ => Application(p, new[] { Answer(ids[0], "WillMeet", null), Answer(ids[0], "WillMeet", null), Answer(ids[1], "WillMeet", null), Answer(ids[2], "WillMeet", null) }),
            };

            var response = await Send(HttpMethod.Post, $"/api/Posts/{p.Id}/apply", s.Programmer, body);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            await _factory.WithDbAsync(async db => Assert.False(await db.PostApplications.AnyAsync(a => a.PostId == p.Id)));
        }

        [Fact]
        public async Task The_framework_rule_still_applies_to_projects()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            await _factory.WithDbAsync(async db =>
            {
                (await db.Posts.SingleAsync(x => x.Id == p.Id)).Framework = "Flutter";
                await db.SaveChangesAsync();
            });

            Assert.Equal(HttpStatusCode.BadRequest, (await Send(HttpMethod.Post, $"/api/Posts/{p.Id}/apply", s.Programmer, Application(p))).StatusCode);
            var body = new { proposal = Approach, price = 400m, durationDays = 14, framework = "flutter", responses = Answers(p.CriterionIds) };
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Post, $"/api/Posts/{p.Id}/apply", s.Programmer, body)).StatusCode);
        }

        // ---------------- authorization ----------------

        [Fact]
        public async Task Only_the_owner_sees_the_applicants()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            await ApplyAsync(s.Programmer, p);
            var path = $"/api/Projects/{p.Id}/applicants";

            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(HttpMethod.Get, path, null)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, s.Programmer)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, s.Admin)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Get, path, s.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Get, $"/api/Projects/{s.PostId}/applicants", s.Owner)).StatusCode);
        }

        [Fact]
        public async Task A_full_application_is_visible_only_to_the_owner_and_the_applicant()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            var id = await ApplyAsync(s.Programmer, p);
            var path = $"/api/Projects/{p.Id}/applications/{id}";

            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(HttpMethod.Get, path, null)).StatusCode);
            foreach (var refused in new[] { s.OtherProgrammer, s.Other, s.Admin })
                Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, refused)).StatusCode);

            foreach (var allowed in new[] { s.Owner, s.Programmer })
            {
                var json = await Json(await Send(HttpMethod.Get, path, allowed));
                var answers = json.GetProperty("answers").EnumerateArray().ToList();
                Assert.Equal(3, answers.Count);
                Assert.All(answers, a => Assert.Equal("WillMeet", a.GetProperty("response").GetString()));
                Assert.Equal(new[] { 1, 2, 3 }, answers.Select(a => a.GetProperty("order").GetInt32()));
            }

            Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Get, $"/api/Projects/{p.Id}/applications/987654", s.Owner)).StatusCode);
        }

        [Fact]
        public async Task My_applications_are_for_programmers_and_list_only_their_own()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            var mine = await ApplyAsync(s.Programmer, p);
            await ApplyAsync(s.OtherProgrammer, p);
            const string path = "/api/Projects/applications/mine";

            Assert.Equal(HttpStatusCode.Unauthorized, (await Send(HttpMethod.Get, path, null)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, s.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(HttpMethod.Get, path, s.Admin)).StatusCode);

            var list = (await Json(await Send(HttpMethod.Get, path, s.Programmer))).GetProperty("applications").EnumerateArray().ToList();
            var row = Assert.Single(list);
            Assert.Equal(mine, row.GetProperty("applicationId").GetInt32());
            Assert.Equal(3, row.GetProperty("coverage").GetProperty("willMeet").GetInt32());
            Assert.Equal(3, row.GetProperty("coverage").GetProperty("total").GetInt32());
        }

        // ---------------- comparison ----------------

        private async Task<int[]> ApplicantOrder(Account owner, int projectId, string query = "")
        {
            var json = await Json(await Send(HttpMethod.Get, $"/api/Projects/{projectId}/applicants{query}", owner));
            return json.GetProperty("applicants").EnumerateArray().Select(a => a.GetProperty("programmerId").GetInt32()).ToArray();
        }

        [Fact]
        public async Task Applicants_sort_oldest_first_by_default_and_by_any_column_on_request()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            // First: 1 will meet, 2 clarify, $450, 20 days. Second: 3 will meet, $500, 10 days. Third: 2 will meet, $300, 30 days.
            await ApplyAsync(s.Programmer, p, Application(p, Answers(p.CriterionIds, "WillMeet", "NeedsClarification", "NeedsClarification"), price: 450m, days: 20));
            await ApplyAsync(s.OtherProgrammer, p, Application(p, price: 500m, days: 10));
            await ApplyAsync(s.FreshProgrammer, p, Application(p, Answers(p.CriterionIds, "WillMeet", "WillMeet", "ProposeChange"), price: 300m, days: 30));
            var (a, b, c) = (s.Programmer.Id, s.OtherProgrammer.Id, s.FreshProgrammer.Id);

            Assert.Equal(new[] { a, b, c }, await ApplicantOrder(s.Owner, p.Id));
            Assert.Equal(new[] { b, c, a }, await ApplicantOrder(s.Owner, p.Id, "?sort=coverage"));
            Assert.Equal(new[] { a, c, b }, await ApplicantOrder(s.Owner, p.Id, "?sort=coverage&dir=asc"));
            Assert.Equal(new[] { c, a, b }, await ApplicantOrder(s.Owner, p.Id, "?sort=amount"));
            Assert.Equal(new[] { b, a, c }, await ApplicantOrder(s.Owner, p.Id, "?sort=duration"));
            Assert.Equal(new[] { c, b, a }, await ApplicantOrder(s.Owner, p.Id, "?sort=submitted&dir=desc"));
            // The scenario's two programmers are verified; the fresh one has no profile.
            Assert.Equal(c, (await ApplicantOrder(s.Owner, p.Id, "?sort=verified")).Last());
            Assert.Equal(HttpStatusCode.BadRequest, (await Send(HttpMethod.Get, $"/api/Projects/{p.Id}/applicants?sort=ai", s.Owner)).StatusCode);

            var rows = (await Json(await Send(HttpMethod.Get, $"/api/Projects/{p.Id}/applicants", s.Owner))).GetProperty("applicants").EnumerateArray().ToList();
            var first = rows[0];
            Assert.Equal(1, first.GetProperty("coverage").GetProperty("willMeet").GetInt32());
            Assert.Equal(2, first.GetProperty("coverage").GetProperty("needsClarification").GetInt32());
            Assert.Equal(450m, first.GetProperty("amount").GetDecimal());
            Assert.Equal(20, first.GetProperty("durationDays").GetInt32());
            Assert.True(first.GetProperty("isVerified").GetBoolean());
            Assert.Equal(JsonValueKind.Null, first.GetProperty("rating").ValueKind);
        }

        [Fact]
        public async Task Coverage_ties_fall_back_to_submission_time()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            await ApplyAsync(s.Programmer, p);
            await ApplyAsync(s.OtherProgrammer, p);

            Assert.Equal(new[] { s.Programmer.Id, s.OtherProgrammer.Id }, await ApplicantOrder(s.Owner, p.Id, "?sort=coverage"));
        }

        [Fact]
        public async Task The_owner_can_accept_a_structured_application()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Owner);
            var id = await ApplyAsync(s.Programmer, p);

            var accept = await Send(HttpMethod.Post, $"/api/Posts/{p.Id}/applications/{id}/accept", s.Owner);
            Assert.Equal(HttpStatusCode.OK, accept.StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal("Accepted", (await db.PostApplications.SingleAsync(a => a.Id == id)).Status);
                Assert.True((await db.Posts.SingleAsync(x => x.Id == p.Id)).IsClosed);
            });
        }

        // ---------------- deletes ----------------

        [Fact]
        public async Task Deleting_a_customer_with_an_answered_project_or_a_programmer_with_answers_succeeds()
        {
            var s = await Scenario();
            var p = await ProjectAsync(s.Other);
            await ApplyAsync(s.Programmer, p);
            await ApplyAsync(s.OtherProgrammer, p);

            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Delete, $"/api/Admin/users/{s.OtherProgrammer.Id}", s.Admin)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(HttpMethod.Delete, $"/api/Admin/users/{s.Other.Id}", s.Admin)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                Assert.False(await db.Posts.AnyAsync(x => x.Id == p.Id));
                Assert.False(await db.AcceptanceCriteria.AnyAsync(c => c.PostId == p.Id));
                Assert.False(await db.ApplicationCriterionResponses.AnyAsync(r => p.CriterionIds.Contains(r.CriterionId)));
            });
        }
    }
}
