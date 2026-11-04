using System.Net;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // ============================================================
    // M2.7c authorization matrix for the 9 personal-data read routes
    // (docs/M2_7_ENDPOINT_PLAN.md §2):
    //   T-7C-01  enforced: anonymous 401; another user / wrong role refused
    //   T-7C-02  enforced: the rightful caller is allowed
    //   T-7C-03  enforced: the admin outcome of each route
    //   T-7C-04  fallback: tokenless passes and is logged; tokens stay enforced
    //   T-7C-05  fallback refused for a non-loopback client / when the switch is not set
    //   T-7C-1x  response shapes: email/phone keys kept, null for non-owners, filled for the owner (D-5)
    // ============================================================
    public sealed record ReadRoute(
        string Name,
        Func<WriteScenario, string> Path,
        Func<WriteScenario, Account> Actor,
        Func<WriteScenario, Account[]> Refused,
        HttpStatusCode AdminStatus = HttpStatusCode.Forbidden,
        string FallbackCase = "IdentityFromClient",
        bool CallsExternalService = false);

    public static class ReadRoutes
    {
        public static readonly ReadRoute[] All =
        {
            new("CustomerProfile.Get", s => $"/api/CustomerProfile/{s.Owner.Id}", s => s.Owner, s => new[] { s.Other, s.Programmer }, HttpStatusCode.OK),
            new("ProgrammerProfile.Get", s => $"/api/ProgrammerProfile/{s.Programmer.Id}", s => s.Programmer, _ => Array.Empty<Account>(), HttpStatusCode.OK),
            new("Notifications.List", s => $"/api/Notifications/{s.Owner.Id}", s => s.Owner, s => new[] { s.Other, s.Programmer }),
            new("Posts.Search", _ => "/api/Posts/search?q=Prog", s => s.Owner, _ => Array.Empty<Account>(), HttpStatusCode.OK, "TokenlessRequest"),
            new("Posts.Profile", s => $"/api/Posts/profile/{s.Owner.Id}", s => s.Owner, _ => Array.Empty<Account>(), HttpStatusCode.OK, "TokenlessRequest"),
            new("Posts.Weather", s => $"/api/Posts/weather/{s.Owner.Id}", s => s.Owner, s => new[] { s.Other, s.Programmer }, CallsExternalService: true),
            new("Support.Get", s => $"/api/Support/{s.MessageId}", s => s.Owner, s => new[] { s.Other, s.Programmer }, HttpStatusCode.OK, "TokenlessRequest"),
            new("Support.My", s => $"/api/Support/my/{s.Owner.Id}", s => s.Owner, s => new[] { s.Other, s.Programmer }),
            new("Support.UnreadCount", s => $"/api/Support/my/{s.Owner.Id}/unread-count", s => s.Owner, s => new[] { s.Other, s.Programmer }),
        };

        public static IEnumerable<object[]> Names => All.Select(r => new object[] { r.Name });

        public static ReadRoute Get(string name) => All.Single(r => r.Name == name);

        // The weather route depends on outbound internet: reaching it, not its result, is what is asserted.
        public static void AssertAllowed(ReadRoute route, HttpResponseMessage response)
        {
            if (route.CallsExternalService)
            {
                Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
                Assert.NotEqual(HttpStatusCode.Forbidden, response.StatusCode);
            }
            else
            {
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            }
        }

        public static async Task<JsonElement> Json(HttpResponseMessage response)
        {
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;
        }

        // The key must exist and be JSON null (D-5).
        public static void AssertNullKey(JsonElement body, string key)
        {
            Assert.True(body.TryGetProperty(key, out var value), $"missing key {key}");
            Assert.Equal(JsonValueKind.Null, value.ValueKind);
        }

        public static void AssertFilled(JsonElement body, string key, string expected) =>
            Assert.Equal(expected, body.GetProperty(key).GetString());

        // Search is by nickname: a unique one finds exactly this user in a shared test database.
        public static async Task<string> UniqueNicknameAsync(DevLinkApiFactory factory, int customerId)
        {
            var nickname = $"nick{Guid.NewGuid():N}";
            await factory.WithDbAsync(async db => await db.CustomerProfiles.Where(p => p.UserId == customerId)
                .ExecuteUpdateAsync(u => u.SetProperty(p => p.Nickname, nickname)));
            return nickname;
        }
    }

    public class ReadRouteAuthorizationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public ReadRouteAuthorizationTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<WriteScenario> Scenario() => WriteRoutes.ScenarioAsync(_factory, _client);

        private Task<HttpResponseMessage> Get(string path, Account? caller) =>
            SessionApiFactory.GetWithToken(_client, path, caller?.Token);

        [Theory]
        [MemberData(nameof(ReadRoutes.Names), MemberType = typeof(ReadRoutes))]
        public async Task T_7C_01_enforced_anonymous_another_user_and_wrong_role_are_refused(string name)
        {
            var route = ReadRoutes.Get(name);
            var s = await Scenario();

            var anonymous = await Get(route.Path(s), null);
            Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
            Assert.Equal("UNAUTHENTICATED", await AdminRoutes.ErrorCode(anonymous));

            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, route.Path(s), "not-a-valid-token")).StatusCode);

            foreach (var caller in route.Refused(s))
            {
                var refused = await Get(route.Path(s), caller);
                Assert.Equal(HttpStatusCode.Forbidden, refused.StatusCode);
                Assert.Equal("FORBIDDEN", await AdminRoutes.ErrorCode(refused));
            }
        }

        [Theory]
        [MemberData(nameof(ReadRoutes.Names), MemberType = typeof(ReadRoutes))]
        public async Task T_7C_02_enforced_the_rightful_caller_is_allowed(string name)
        {
            var route = ReadRoutes.Get(name);
            var s = await Scenario();

            ReadRoutes.AssertAllowed(route, await Get(route.Path(s), route.Actor(s)));
        }

        [Theory]
        [MemberData(nameof(ReadRoutes.Names), MemberType = typeof(ReadRoutes))]
        public async Task T_7C_03_enforced_admin_outcome(string name)
        {
            var route = ReadRoutes.Get(name);
            var s = await Scenario();

            Assert.Equal(route.AdminStatus, (await Get(route.Path(s), s.Admin)).StatusCode);
        }

        [Fact]
        public async Task T_7C_06_a_client_userId_in_the_query_changes_nothing()
        {
            var s = await Scenario();

            foreach (var path in new[]
            {
                $"/api/Notifications/{s.Owner.Id}?userId={s.Other.Id}&isAdmin=true",
                $"/api/Support/my/{s.Owner.Id}?userId={s.Other.Id}&isAdmin=true",
                $"/api/CustomerProfile/{s.Owner.Id}?userId={s.Other.Id}&isAdmin=true"
            })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await Get(path, s.Other)).StatusCode);
            }

            var profile = await ReadRoutes.Json(await Get($"/api/Posts/profile/{s.Owner.Id}?userId={s.Owner.Id}&isAdmin=true", s.Other));
            ReadRoutes.AssertNullKey(profile, "email");
        }

        [Fact]
        public async Task T_7C_07_the_notification_list_stays_a_json_array_of_the_callers_rows()
        {
            var s = await Scenario();

            var body = await ReadRoutes.Json(await Get($"/api/Notifications/{s.Owner.Id}", s.Owner));

            Assert.Equal(JsonValueKind.Array, body.ValueKind);
            Assert.Equal(s.NotificationId, body.EnumerateArray().Single().GetProperty("id").GetInt32());
        }

        [Fact]
        public async Task T_7C_08_suspended_accounts_keep_their_support_tickets_only()
        {
            var s = await Scenario();
            await _factory.WithDbAsync(async db => await db.Users.Where(u => u.Id == s.Owner.Id)
                .ExecuteUpdateAsync(u => u.SetProperty(x => x.Status, UserStatus.Suspended)));
            ((Services.Auth.SessionStateCache)_factory.Services.GetService(typeof(Services.Auth.SessionStateCache))!).Invalidate(s.Owner.Id);

            Assert.Equal(HttpStatusCode.OK, (await Get($"/api/Support/my/{s.Owner.Id}", s.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Get($"/api/Support/{s.MessageId}", s.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Get($"/api/Support/my/{s.Owner.Id}/unread-count", s.Owner)).StatusCode);

            var notifications = await Get($"/api/Notifications/{s.Owner.Id}", s.Owner);
            Assert.Equal(HttpStatusCode.Forbidden, notifications.StatusCode);
            Assert.Equal("ACCOUNT_SUSPENDED", await AdminRoutes.ErrorCode(notifications));
        }

        // ---------------- response shapes (D-5) ----------------

        [Fact]
        public async Task T_7C_10_member_profile_customer_email_and_phone_only_for_self_and_admin()
        {
            var s = await Scenario();
            var path = $"/api/Posts/profile/{s.Owner.Id}";

            foreach (var caller in new[] { s.Owner, s.Admin })
            {
                var full = await ReadRoutes.Json(await Get(path, caller));
                ReadRoutes.AssertFilled(full, "email", s.Owner.Email);
                ReadRoutes.AssertFilled(full, "phoneNumber", "0590000001");
            }

            foreach (var caller in new[] { s.Other, s.Programmer })
            {
                var body = await ReadRoutes.Json(await Get(path, caller));
                ReadRoutes.AssertNullKey(body, "email");
                ReadRoutes.AssertNullKey(body, "phoneNumber");
                ReadRoutes.AssertFilled(body, "nickname", "Owner");
                Assert.DoesNotContain(s.Owner.Email, body.GetRawText());
            }
        }

        [Fact]
        public async Task T_7C_11_member_profile_programmer_email_and_phone_only_for_self_and_admin()
        {
            var s = await Scenario();
            var path = $"/api/Posts/profile/{s.Programmer.Id}";

            foreach (var caller in new[] { s.Programmer, s.Admin })
            {
                var full = await ReadRoutes.Json(await Get(path, caller));
                ReadRoutes.AssertFilled(full, "email", s.Programmer.Email);
                ReadRoutes.AssertFilled(full, "phoneNumber", "0590000002");
            }

            var body = await ReadRoutes.Json(await Get(path, s.OtherProgrammer));
            ReadRoutes.AssertNullKey(body, "email");
            ReadRoutes.AssertNullKey(body, "phoneNumber");
            ReadRoutes.AssertFilled(body, "specialty", "Backend");
        }

        [Fact]
        public async Task T_7C_12_programmer_profile_route_hides_phone_and_file_names_from_other_members()
        {
            var s = await Scenario();
            var path = $"/api/ProgrammerProfile/{s.Programmer.Id}";

            foreach (var caller in new[] { s.Programmer, s.Admin })
            {
                var full = await ReadRoutes.Json(await Get(path, caller));
                ReadRoutes.AssertFilled(full, "phoneNumber", "0590000002");
                ReadRoutes.AssertFilled(full, "cvName", "cv.pdf");
                ReadRoutes.AssertFilled(full, "certificateName", "cert.pdf");
            }

            foreach (var caller in new[] { s.OtherProgrammer, s.Owner })
            {
                var body = await ReadRoutes.Json(await Get(path, caller));
                ReadRoutes.AssertNullKey(body, "phoneNumber");
                ReadRoutes.AssertNullKey(body, "cvName");
                ReadRoutes.AssertNullKey(body, "certificateName");
                Assert.True(body.GetProperty("hasCV").GetBoolean());
            }
        }

        [Fact]
        public async Task T_7C_13_search_email_is_null_and_not_searchable_except_for_admins()
        {
            var s = await Scenario();
            var nickname = await ReadRoutes.UniqueNicknameAsync(_factory, s.Owner.Id);

            async Task<JsonElement> Users(string q, Account caller) =>
                (await ReadRoutes.Json(await Get($"/api/Posts/search?q={Uri.EscapeDataString(q)}", caller))).GetProperty("users");

            var member = (await Users(nickname, s.Other)).EnumerateArray().Single();
            ReadRoutes.AssertNullKey(member, "email");
            Assert.Equal(s.Owner.Id, member.GetProperty("userId").GetInt32());

            // Finding someone by their email would confirm the address.
            Assert.Empty((await Users(s.Owner.Email, s.Other)).EnumerateArray());

            var admin = (await Users(nickname, s.Admin)).EnumerateArray().Single();
            ReadRoutes.AssertFilled(admin, "email", s.Owner.Email);
            Assert.Single((await Users(s.Owner.Email, s.Admin)).EnumerateArray());
        }

        [Fact]
        public async Task T_7C_14_support_ticket_holds_the_email_only_for_its_sender_and_admins()
        {
            var s = await Scenario();

            foreach (var caller in new[] { s.Owner, s.Admin })
            {
                ReadRoutes.AssertFilled(await ReadRoutes.Json(await Get($"/api/Support/{s.MessageId}", caller)), "email", s.Owner.Email);
            }
        }

        [Fact]
        public async Task T_7C_15_D6_applicant_email_is_visible_only_to_the_post_owner()
        {
            var s = await Scenario();
            var path = $"/api/Posts/{s.PostId}/applications";

            var applications = (await ReadRoutes.Json(await Get(path, s.Owner))).GetProperty("applications");
            ReadRoutes.AssertFilled(applications.EnumerateArray().Single(), "email", s.Programmer.Email);

            foreach (var caller in new[] { s.Other, s.Programmer, s.OtherProgrammer, s.Admin })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await Get(path, caller)).StatusCode);
            }
        }
    }

    public class ReadRouteFallbackTests : IClassFixture<DevFallbackApiFactory>
    {
        private readonly DevFallbackApiFactory _factory;
        private readonly HttpClient _client;

        public ReadRouteFallbackTests(DevFallbackApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Theory]
        [MemberData(nameof(ReadRoutes.Names), MemberType = typeof(ReadRoutes))]
        public async Task T_7C_04_tokenless_passes_and_is_logged_tokens_stay_enforced(string name)
        {
            var route = ReadRoutes.Get(name);
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            foreach (var caller in route.Refused(s))
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await SessionApiFactory.GetWithToken(_client, route.Path(s), caller.Token)).StatusCode);
            }

            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, route.Path(s), "not-a-valid-token")).StatusCode);

            var marker = $"Auth.DevFallbackUsed {route.FallbackCase}";
            var before = _factory.Logs.Entries.Count(e => e.Message.Contains(marker));

            ReadRoutes.AssertAllowed(route, await _client.GetAsync(route.Path(s)));

            var logs = _factory.Logs.Entries.Where(e => e.Message.Contains("Auth.DevFallbackUsed")).ToList();
            Assert.True(logs.Count(e => e.Message.Contains(marker)) > before);
            Assert.All(logs, e =>
            {
                Assert.DoesNotContain(route.Actor(s).Email, e.Message);
                Assert.DoesNotContain("?", e.Message);
                Assert.DoesNotContain($"/{route.Actor(s).Id}", e.Message);
            });
        }

        [Fact]
        public async Task T_7C_06b_tokenless_weather_of_an_unknown_user_is_404_before_any_external_call()
        {
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync("/api/Posts/weather/999999")).StatusCode);
        }

        // The unchanged app sends no token, so the member routes treat it as nobody in particular.
        [Fact]
        public async Task T_7C_16_tokenless_profile_and_search_return_null_email_and_phone()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var nickname = await ReadRoutes.UniqueNicknameAsync(_factory, s.Owner.Id);

            var profile = await ReadRoutes.Json(await _client.GetAsync($"/api/Posts/profile/{s.Owner.Id}"));
            ReadRoutes.AssertNullKey(profile, "email");
            ReadRoutes.AssertNullKey(profile, "phoneNumber");

            var users = (await ReadRoutes.Json(await _client.GetAsync($"/api/Posts/search?q={nickname}"))).GetProperty("users");
            ReadRoutes.AssertNullKey(users.EnumerateArray().Single(), "email");

            var byEmail = (await ReadRoutes.Json(await _client.GetAsync($"/api/Posts/search?q={Uri.EscapeDataString(s.Owner.Email)}"))).GetProperty("users");
            Assert.Empty(byEmail.EnumerateArray());
        }

        // Their own dashboards call these two with their id: the fallback answers for that id, so the dashboards keep working.
        [Fact]
        public async Task T_7C_17_tokenless_dashboard_routes_stay_complete()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            ReadRoutes.AssertFilled(await ReadRoutes.Json(await _client.GetAsync($"/api/CustomerProfile/{s.Owner.Id}")), "phoneNumber", "0590000001");
            ReadRoutes.AssertFilled(await ReadRoutes.Json(await _client.GetAsync($"/api/ProgrammerProfile/{s.Programmer.Id}")), "phoneNumber", "0590000002");
        }

        [Fact]
        public async Task T_7C_18_a_token_wins_in_fallback_mode_too()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            var other = await ReadRoutes.Json(await SessionApiFactory.GetWithToken(_client, $"/api/Posts/profile/{s.Owner.Id}", s.Other.Token));
            ReadRoutes.AssertNullKey(other, "email");

            var self = await ReadRoutes.Json(await SessionApiFactory.GetWithToken(_client, $"/api/Posts/profile/{s.Owner.Id}", s.Owner.Token));
            ReadRoutes.AssertFilled(self, "email", s.Owner.Email);
        }
    }

    public class ReadRouteRemoteFallbackTests : IClassFixture<DevFallbackRemoteApiFactory>
    {
        private readonly DevFallbackRemoteApiFactory _factory;

        public ReadRouteRemoteFallbackTests(DevFallbackRemoteApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [MemberData(nameof(ReadRoutes.Names), MemberType = typeof(ReadRoutes))]
        public async Task T_7C_05_non_loopback_clients_never_get_the_fallback(string name)
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(ReadRoutes.Get(name).Path(s))).StatusCode);
        }
    }

    public class ReadRouteDevDefaultTests : IClassFixture<DevDefaultApiFactory>
    {
        private readonly DevDefaultApiFactory _factory;

        public ReadRouteDevDefaultTests(DevDefaultApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("Notifications.List")]
        [InlineData("Posts.Profile")]
        [InlineData("Support.My")]
        public async Task T_7C_05b_development_without_the_switch_is_enforced(string name)
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(ReadRoutes.Get(name).Path(s))).StatusCode);
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }
    }
}
