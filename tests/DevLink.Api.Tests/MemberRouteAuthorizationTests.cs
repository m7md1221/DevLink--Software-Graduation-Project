using System.Net;
using System.Reflection;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Routing;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // ============================================================
    // M2.7d (docs/M2_7_ENDPOINT_PLAN.md §2):
    //   T-7D-01…05  authorization matrix for the 7 member-only reads, enforced and fallback
    //   T-7D-06     spoofed client ids are ignored
    //   T-7D-07     comments of unapproved posts
    //   T-7D-08     CV and certificate downloads (design 8 #27)
    //   T-7D-10…12  deny by default: reflection over every action, and a route with no attribute
    //   T-7D-20…    KI-58 notification sender names, KI-29 weather errors, KI-57 start-up race
    // ============================================================
    public sealed record MemberRoute(
        string Name,
        Func<WriteScenario, string> Path,
        Func<WriteScenario, Account> Actor,
        Func<WriteScenario, Account[]> Refused,
        HttpStatusCode AdminStatus = HttpStatusCode.OK,
        string FallbackCase = "IdentityFromClient",
        bool CallsExternalService = false);

    public static class MemberRoutes
    {
        public static readonly MemberRoute[] All =
        {
            new("ProgrammerProfile.All", _ => "/api/ProgrammerProfile/all", s => s.Admin, s => new[] { s.Owner, s.Programmer }, FallbackCase: "TokenlessRequest"),
            new("Posts.Feed", s => $"/api/Posts/feed?userId={s.Owner.Id}", s => s.Owner, _ => Array.Empty<Account>()),
            new("Posts.UserPosts", s => $"/api/Posts/user/{s.Owner.Id}?currentUserId={s.Owner.Id}", s => s.Other, _ => Array.Empty<Account>()),
            new("Posts.Comments", s => $"/api/Posts/{s.PostId}/comments", s => s.Other, _ => Array.Empty<Account>(), FallbackCase: "TokenlessRequest"),
            new("Posts.ApplicationsCount", s => $"/api/Posts/{s.PostId}/applications/count", s => s.Other, _ => Array.Empty<Account>(), FallbackCase: "TokenlessRequest"),
            new("Posts.HasApplied", s => $"/api/Posts/{s.PostId}/has-applied?userId={s.Programmer.Id}", s => s.Programmer, _ => Array.Empty<Account>()),
            new("Posts.WeatherLocation", _ => "/api/Posts/weather-location?lat=32.2&lon=35.2", s => s.Other, _ => Array.Empty<Account>(), FallbackCase: "TokenlessRequest", CallsExternalService: true),
        };

        public static IEnumerable<object[]> Names => All.Select(r => new object[] { r.Name });

        public static MemberRoute Get(string name) => All.Single(r => r.Name == name);

        // The location route depends on outbound internet: reaching it, not its result, is what is asserted.
        public static void AssertAllowed(MemberRoute route, HttpResponseMessage response)
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
    }

    public class MemberRouteAuthorizationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public MemberRouteAuthorizationTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<WriteScenario> Scenario() => WriteRoutes.ScenarioAsync(_factory, _client);

        private Task<HttpResponseMessage> Get(string path, Account? caller) =>
            SessionApiFactory.GetWithToken(_client, path, caller?.Token);

        [Theory]
        [MemberData(nameof(MemberRoutes.Names), MemberType = typeof(MemberRoutes))]
        public async Task T_7D_01_enforced_anonymous_and_invalid_tokens_are_refused(string name)
        {
            var route = MemberRoutes.Get(name);
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
        [MemberData(nameof(MemberRoutes.Names), MemberType = typeof(MemberRoutes))]
        public async Task T_7D_02_enforced_signed_in_members_are_allowed(string name)
        {
            var route = MemberRoutes.Get(name);
            var s = await Scenario();

            MemberRoutes.AssertAllowed(route, await Get(route.Path(s), route.Actor(s)));
        }

        [Theory]
        [MemberData(nameof(MemberRoutes.Names), MemberType = typeof(MemberRoutes))]
        public async Task T_7D_03_enforced_admin_outcome(string name)
        {
            var route = MemberRoutes.Get(name);
            var s = await Scenario();

            var response = await Get(route.Path(s), s.Admin);

            if (route.CallsExternalService)
            {
                MemberRoutes.AssertAllowed(route, response);
            }
            else
            {
                Assert.Equal(route.AdminStatus, response.StatusCode);
            }
        }

        [Fact]
        public async Task T_7D_06_spoofed_client_ids_are_ignored()
        {
            var s = await Scenario();
            await _factory.WithDbAsync(async db =>
            {
                db.PostLikes.Add(new DataBase.Models.PostLike { PostId = s.PostId, UserId = s.Owner.Id });
                await db.SaveChangesAsync();
            });

            // The feed answers isMine and isLikedByMe for the token, not the client's userId.
            var feed = JsonDocument.Parse(await (await Get($"/api/Posts/feed?userId={s.Owner.Id}", s.Other)).Content.ReadAsStringAsync()).RootElement;
            var post = feed.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == s.PostId);
            Assert.False(post.GetProperty("isMine").GetBoolean());
            Assert.False(post.GetProperty("isLikedByMe").GetBoolean());

            var posts = JsonDocument.Parse(await (await Get($"/api/Posts/user/{s.Owner.Id}?currentUserId={s.Owner.Id}", s.Other)).Content.ReadAsStringAsync()).RootElement;
            Assert.False(posts.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == s.PostId).GetProperty("isMine").GetBoolean());

            // Programmer has applied; the question is answered for the caller.
            var other = JsonDocument.Parse(await (await Get($"/api/Posts/{s.PostId}/has-applied?userId={s.Programmer.Id}", s.OtherProgrammer)).Content.ReadAsStringAsync()).RootElement;
            Assert.False(other.GetProperty("hasApplied").GetBoolean());
            var self = JsonDocument.Parse(await (await Get($"/api/Posts/{s.PostId}/has-applied?userId={s.OtherProgrammer.Id}", s.Programmer)).Content.ReadAsStringAsync()).RootElement;
            Assert.True(self.GetProperty("hasApplied").GetBoolean());
        }

        [Fact]
        public async Task T_7D_07_comments_of_an_unapproved_post_only_for_its_owner_and_admins()
        {
            var s = await Scenario();
            int pending = 0;
            await _factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = s.Owner.Id, Content = "Not reviewed", Status = "Pending" };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                pending = post.Id;
            });

            Assert.Equal(HttpStatusCode.Forbidden, (await Get($"/api/Posts/{pending}/comments", s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Get($"/api/Posts/{pending}/comments", s.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Get($"/api/Posts/{pending}/comments", s.Admin)).StatusCode);
        }

        [Theory]
        [InlineData("cv")]
        [InlineData("certificate")]
        public async Task T_7D_08_documents_only_for_the_programmer_an_admin_or_a_customer_they_applied_to(string document)
        {
            var s = await Scenario();
            var path = $"/api/ProgrammerProfile/{s.Programmer.Id}/{document}";

            Assert.Equal(HttpStatusCode.Unauthorized, (await Get(path, null)).StatusCode);
            foreach (var refused in new[] { s.Other, s.OtherProgrammer })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await Get(path, refused)).StatusCode);
            }

            // Programmer applied to Owner's post.
            foreach (var allowed in new[] { s.Programmer, s.Admin, s.Owner })
            {
                Assert.Equal(HttpStatusCode.OK, (await Get(path, allowed)).StatusCode);
            }
        }

        [Theory]
        [InlineData("/api/Posts/image/999999")]
        [InlineData("/api/Posts/user/999999/avatar")]
        [InlineData("/api/CustomerProfile/999999/image")]
        [InlineData("/api/ProgrammerProfile/999999/image")]
        public async Task T_7D_09_image_routes_stay_reachable_without_a_token_until_M2_8(string path)
        {
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync(path)).StatusCode);
        }

        // ---------------- deny by default ----------------

        [Fact]
        public async Task T_7D_11_a_route_with_no_attribute_is_refused()
        {
            var s = await Scenario();

            var anonymous = await _client.GetAsync("/__tests/auth/no-attribute");
            Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
            Assert.Equal("UNAUTHENTICATED", await AdminRoutes.ErrorCode(anonymous));
            Assert.Equal(HttpStatusCode.OK, (await Get("/__tests/auth/no-attribute", s.Owner)).StatusCode);
        }

        // ---------------- KI-58: sender names in notifications ----------------

        private async Task<string> LatestNotificationAsync(int userId)
        {
            var message = "";
            await _factory.WithDbAsync(async db => message = await db.Notifications.AsNoTracking()
                .Where(n => n.UserId == userId && (n.Type == "like" || n.Type == "comment"))
                .OrderByDescending(n => n.Id).Select(n => n.Message).FirstAsync());
            return message;
        }

        [Theory]
        [InlineData("like")]
        [InlineData("comment")]
        public async Task T_7D_20_notifications_name_the_sender_by_nickname_never_by_email(string action)
        {
            var s = await Scenario();

            // Programmer has a profile with the nickname "Prog".
            var path = action == "like" ? $"/api/Posts/{s.PostId}/like" : $"/api/Posts/{s.PostId}/comments";
            object body = action == "like" ? new { } : new { content = "Interesting" };
            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, path, body), s.Programmer.Token)).StatusCode);

            var message = await LatestNotificationAsync(s.Owner.Id);

            Assert.StartsWith("Prog ", message);
            Assert.DoesNotContain(s.Programmer.Email.Split('@')[0], message);
            Assert.DoesNotContain("@", message);
        }

        [Theory]
        [InlineData("like")]
        [InlineData("comment")]
        public async Task T_7D_21_a_sender_without_a_profile_gets_a_neutral_name(string action)
        {
            var s = await Scenario();

            // Other has no profile.
            var path = action == "like" ? $"/api/Posts/{s.PostId}/like" : $"/api/Posts/{s.PostId}/comments";
            object body = action == "like" ? new { } : new { content = "Interesting" };
            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, path, body), s.Other.Token)).StatusCode);

            var message = await LatestNotificationAsync(s.Owner.Id);

            Assert.StartsWith("A DevLink member ", message);
            Assert.DoesNotContain(s.Other.Email.Split('@')[0], message);
        }

        [Fact]
        public void T_7D_22_notification_and_weather_code_never_use_email_parts_or_exception_text_in_responses()
        {
            var backend = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "backend"));
            var service = File.ReadAllText(Path.Combine(backend, "Services", "PostService.cs"));
            var controller = File.ReadAllText(Path.Combine(backend, "Controllers", "PostsController.cs"));

            Assert.DoesNotContain("Split('@')", service);
            Assert.DoesNotContain("$\"Error: {ex.Message}\"", controller);
        }
    }

    // Reflection over the API assembly: no action may rely on a missing attribute.
    public class DenyByDefaultTests
    {
        // The 8 sign-in routes and the 4 image routes (anonymous until M2.8).
        private static readonly string[] PublicRoutes =
        {
            "AuthController.Login", "AuthController.GoogleLogin", "AuthController.SendCode", "AuthController.SendResetCode",
            "AuthController.VerifyCode", "AuthController.VerifyResetCode", "AuthController.SignUp", "AuthController.ResetPassword",
            "CustomerProfileController.GetProfileImage", "ProgrammerProfileController.GetProfileImage",
            "PostsController.GetPostImage", "PostsController.GetUserAvatar"
        };

        // No access token by design: they authenticate with the refresh token behind their own CSRF guard.
        private static readonly string[] OwnGuardRoutes = { "AuthController.RefreshSession", "AuthController.Logout" };

        private static IEnumerable<MethodInfo> Actions() =>
            typeof(Program).Assembly.GetTypes()
                .Where(t => typeof(ControllerBase).IsAssignableFrom(t) && !t.IsAbstract)
                .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
                .Where(m => m.GetCustomAttributes<HttpMethodAttribute>().Any());

        private static string NameOf(MethodInfo m) => $"{m.DeclaringType!.Name}.{m.Name}";

        [Fact]
        public void T_7D_10_every_action_has_an_explicit_policy_or_AllowAnonymous()
        {
            var missing = Actions()
                .Where(m => m.GetCustomAttribute<AllowAnonymousAttribute>() == null &&
                            m.GetCustomAttribute<AuthorizeAttribute>() == null &&
                            m.DeclaringType!.GetCustomAttribute<AuthorizeAttribute>() == null)
                .Select(NameOf)
                .ToList();

            Assert.Empty(missing);
            Assert.Equal(73, Actions().Count());
        }

        [Fact]
        public void T_7D_10b_AllowAnonymous_is_exactly_the_listed_public_routes()
        {
            var anonymous = Actions().Where(m => m.GetCustomAttribute<AllowAnonymousAttribute>() != null).Select(NameOf).OrderBy(n => n);

            Assert.Equal(PublicRoutes.Concat(OwnGuardRoutes).OrderBy(n => n), anonymous);
            Assert.Equal(12, PublicRoutes.Length);
        }

        [Fact]
        public void T_7D_10c_no_controller_is_anonymous_as_a_whole_and_no_action_mixes_both()
        {
            var controllers = typeof(Program).Assembly.GetTypes().Where(t => typeof(ControllerBase).IsAssignableFrom(t));
            Assert.DoesNotContain(controllers, t => t.GetCustomAttribute<AllowAnonymousAttribute>() != null);
            Assert.DoesNotContain(Actions(), m => m.GetCustomAttribute<AllowAnonymousAttribute>() != null && m.GetCustomAttribute<AuthorizeAttribute>() != null);
        }
    }

    public class MemberRouteFallbackTests : IClassFixture<DevFallbackApiFactory>
    {
        private readonly DevFallbackApiFactory _factory;
        private readonly HttpClient _client;

        public MemberRouteFallbackTests(DevFallbackApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Theory]
        [MemberData(nameof(MemberRoutes.Names), MemberType = typeof(MemberRoutes))]
        public async Task T_7D_04_tokenless_passes_and_is_logged_tokens_stay_enforced(string name)
        {
            var route = MemberRoutes.Get(name);
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            foreach (var caller in route.Refused(s))
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await SessionApiFactory.GetWithToken(_client, route.Path(s), caller.Token)).StatusCode);
            }

            Assert.Equal(HttpStatusCode.Unauthorized, (await SessionApiFactory.GetWithToken(_client, route.Path(s), "not-a-valid-token")).StatusCode);

            var marker = $"Auth.DevFallbackUsed {route.FallbackCase}";
            var before = _factory.Logs.Entries.Count(e => e.Message.Contains(marker));

            MemberRoutes.AssertAllowed(route, await _client.GetAsync(route.Path(s)));

            var logs = _factory.Logs.Entries.Where(e => e.Message.Contains("Auth.DevFallbackUsed")).ToList();
            Assert.True(logs.Count(e => e.Message.Contains(marker)) > before);
            Assert.All(logs, e =>
            {
                Assert.DoesNotContain(s.Owner.Email, e.Message);
                Assert.DoesNotContain("?", e.Message);
            });
        }

        [Fact]
        public async Task T_7D_04b_tokenless_feed_answers_for_the_client_id()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            var feed = JsonDocument.Parse(await (await _client.GetAsync($"/api/Posts/feed?userId={s.Owner.Id}")).Content.ReadAsStringAsync()).RootElement;

            Assert.True(feed.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == s.PostId).GetProperty("isMine").GetBoolean());
        }

        [Fact]
        public async Task T_7D_08b_tokenless_documents_use_the_file_case_tokens_stay_enforced()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var path = $"/api/ProgrammerProfile/{s.Programmer.Id}/cv";

            Assert.Equal(HttpStatusCode.Forbidden, (await SessionApiFactory.GetWithToken(_client, path, s.Other.Token)).StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(path)).StatusCode);
            Assert.Contains(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed FileWithoutToken"));
        }

        [Fact]
        public async Task T_7D_07b_tokenless_comments_of_an_unapproved_post_are_refused()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            int pending = 0;
            await _factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = s.Owner.Id, Content = "Not reviewed", Status = "Pending" };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                pending = post.Id;
            });

            Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync($"/api/Posts/{pending}/comments")).StatusCode);
        }

        [Fact]
        public async Task T_7D_12_the_fail_closed_default_never_takes_the_fallback()
        {
            var before = _factory.Logs.Entries.Count(e => e.Message.Contains("Auth.DevFallbackUsed"));

            var response = await _client.GetAsync("/__tests/auth/no-attribute");

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Equal(before, _factory.Logs.Entries.Count(e => e.Message.Contains("Auth.DevFallbackUsed")));
        }
    }

    public class MemberRouteRemoteFallbackTests : IClassFixture<DevFallbackRemoteApiFactory>
    {
        private readonly DevFallbackRemoteApiFactory _factory;

        public MemberRouteRemoteFallbackTests(DevFallbackRemoteApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [MemberData(nameof(MemberRoutes.Names), MemberType = typeof(MemberRoutes))]
        public async Task T_7D_05_non_loopback_clients_never_get_the_fallback(string name)
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(MemberRoutes.Get(name).Path(s))).StatusCode);
        }

        [Fact]
        public async Task T_7D_05c_non_loopback_clients_get_no_documents()
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync($"/api/ProgrammerProfile/{s.Programmer.Id}/cv")).StatusCode);
        }
    }

    public class MemberRouteDevDefaultTests : IClassFixture<DevDefaultApiFactory>
    {
        private readonly DevDefaultApiFactory _factory;

        public MemberRouteDevDefaultTests(DevDefaultApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("Posts.Feed")]
        [InlineData("Posts.Comments")]
        [InlineData("ProgrammerProfile.All")]
        public async Task T_7D_05b_development_without_the_switch_is_enforced(string name)
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(MemberRoutes.Get(name).Path(s))).StatusCode);
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }
    }

    // KI-57: the harness must report the real refusal even when CreateClient() lost the race to the host's disposal.
    public class StartupFailureRaceTests
    {
        [Fact]
        public void T_7D_30_a_disposed_host_still_reports_the_real_refusal_from_the_host_log()
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Cors:AllowedOrigins:0"] = "http://app.devlink.test" });

            factory.StartupFailure();

            Assert.Contains("must use https outside Development", factory.FailureText(new ObjectDisposedException("host")));
        }
    }
}
