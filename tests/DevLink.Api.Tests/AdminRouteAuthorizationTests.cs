using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // ============================================================
    // M2.7a authorization matrix for the 18 admin / moderation /
    // support-inbox routes (docs/M2_7_ENDPOINT_PLAN.md §2):
    //   T-7A-01  enforced: anonymous 401, Customer/Programmer/owner/other 403, Admin allowed
    //   T-7A-02  enforced: client isAdmin/userId/requesterId never grant access
    //   T-7A-03  fallback (Development + switch off + loopback): tokenless requests pass and are logged;
    //            a request with a token (valid or not) never falls back
    //   T-7A-04  fallback refused for a non-loopback client and when the switch is not set
    // ============================================================
    public sealed record AdminRouteScenario(Account Owner, Account Other, Account Programmer, Account Admin, int PostId, int MessageId);

    public sealed record Account(int Id, string Email, string Token);

    public sealed record AdminRoute(string Name, HttpMethod Method, Func<AdminRouteScenario, string> Path,
        Func<AdminRouteScenario, object?> Body, bool ProgrammerIsOwner = false, bool AlwaysSucceedsForAdmin = true);

    public static class AdminRoutes
    {
        private static int _seq;

        public static readonly AdminRoute[] All =
        {
            new("Admin.GetUsers", HttpMethod.Get, s => "/api/Admin/users", _ => null),
            new("Admin.GetUser", HttpMethod.Get, s => $"/api/Admin/users/{s.Owner.Id}", _ => null),
            new("Admin.CreateUser", HttpMethod.Post, s => "/api/Admin/users",
                _ => new { email = ApiTestHelpers.UniqueEmail($"made{Interlocked.Increment(ref _seq)}"), password = "Managed-Ok-9", userType = "Customer" }),
            new("Admin.UpdateUser", HttpMethod.Put, s => $"/api/Admin/users/{s.Owner.Id}", _ => new { password = "Brand-New-Pass-77" }),
            new("Admin.DeleteUser", HttpMethod.Delete, s => $"/api/Admin/users/{s.Owner.Id}", _ => null),
            new("Admin.GetProgrammers", HttpMethod.Get, s => "/api/Admin/programmers", _ => null),
            new("Admin.VerifyProgrammer", HttpMethod.Post, s => $"/api/Admin/programmers/{s.Programmer.Id}/verify", _ => null, ProgrammerIsOwner: true, AlwaysSucceedsForAdmin: false),
            new("Admin.UnverifyProgrammer", HttpMethod.Post, s => $"/api/Admin/programmers/{s.Programmer.Id}/unverify", _ => null, ProgrammerIsOwner: true, AlwaysSucceedsForAdmin: false),
            new("Admin.Statistics", HttpMethod.Get, s => "/api/Admin/statistics", _ => null),
            new("ProgrammerProfile.Verify", HttpMethod.Post, s => $"/api/ProgrammerProfile/{s.Programmer.Id}/verify", _ => null, ProgrammerIsOwner: true, AlwaysSucceedsForAdmin: false),
            new("ProgrammerProfile.Unverify", HttpMethod.Post, s => $"/api/ProgrammerProfile/{s.Programmer.Id}/unverify", _ => null, ProgrammerIsOwner: true, AlwaysSucceedsForAdmin: false),
            new("Posts.Pending", HttpMethod.Get, s => "/api/Posts/pending", _ => null),
            new("Posts.Approve", HttpMethod.Post, s => $"/api/Posts/{s.PostId}/approve", _ => null),
            new("Posts.Reject", HttpMethod.Post, s => $"/api/Posts/{s.PostId}/reject", _ => new { reason = "Not a project request" }),
            new("Support.All", HttpMethod.Get, s => "/api/Support/all", _ => null),
            new("Support.Reply", HttpMethod.Post, s => $"/api/Support/{s.MessageId}/reply", _ => new { reply = "Thanks, we are on it" }),
            new("Support.Read", HttpMethod.Post, s => $"/api/Support/{s.MessageId}/read", _ => null),
            new("Support.Delete", HttpMethod.Delete, s => $"/api/Support/{s.MessageId}", _ => null),
        };

        public static IEnumerable<object[]> Names => All.Select(r => new object[] { r.Name });

        public static AdminRoute Get(string name) => All.Single(r => r.Name == name);

        // Users are inserted directly (legacy plaintext, rehashed at first login) and sign in through the normal login.
        public static async Task<Account> AccountAsync(DevLinkApiFactory factory, HttpClient client, string userType)
        {
            const string password = "Matrix-Pass-42";
            var email = ApiTestHelpers.UniqueEmail($"matrix-{userType.ToLowerInvariant()}");
            int id = 0;
            await factory.WithDbAsync(async db =>
            {
                var user = new User { Email = email, PasswordHash = password, UserType = userType };
                db.Users.Add(user);
                await db.SaveChangesAsync();
                id = user.Id;
            });

            var login = await ApiTestHelpers.LoginAsync(client, email, password, userType);
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            return new Account(id, email, (await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("accessToken").GetString()!);
        }

        public static async Task<AdminRouteScenario> ScenarioAsync(DevLinkApiFactory factory, HttpClient client)
        {
            var owner = await AccountAsync(factory, client, "Customer");
            var other = await AccountAsync(factory, client, "Customer");
            var programmer = await AccountAsync(factory, client, "Programmer");
            var admin = await AccountAsync(factory, client, "Admin");
            int postId = 0, messageId = 0;
            await factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = owner.Id, Content = "Need a small website", Status = "Pending" };
                var message = new SupportMessage { UserId = owner.Id, Name = "Owner", Email = owner.Email, Subject = "Help", Message = "Question" };
                db.Posts.Add(post);
                db.SupportMessages.Add(message);
                await db.SaveChangesAsync();
                postId = post.Id;
                messageId = message.Id;
            });
            return new AdminRouteScenario(owner, other, programmer, admin, postId, messageId);
        }

        public static Task<HttpResponseMessage> SendAsync(HttpClient client, AdminRoute route, AdminRouteScenario s, string? token, string query = "")
        {
            var request = new HttpRequestMessage(route.Method, route.Path(s) + query);
            var body = route.Body(s);
            if (body != null) request.Content = JsonContent.Create(body);
            if (token != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return client.SendAsync(request);
        }

        public static async Task<string?> ErrorCode(HttpResponseMessage response)
        {
            var text = await response.Content.ReadAsStringAsync();
            if (string.IsNullOrWhiteSpace(text) || !text.TrimStart().StartsWith("{")) return null;
            return JsonDocument.Parse(text).RootElement.TryGetProperty("errorCode", out var code) ? code.GetString() : null;
        }

        public static void AssertAllowed(AdminRoute route, HttpResponseMessage response)
        {
            Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.NotEqual(HttpStatusCode.Forbidden, response.StatusCode);
            if (route.AlwaysSucceedsForAdmin)
            {
                Assert.True(response.IsSuccessStatusCode, $"{route.Name}: {(int)response.StatusCode}");
            }
        }
    }

    public class AdminRouteAuthorizationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public AdminRouteAuthorizationTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Theory]
        [MemberData(nameof(AdminRoutes.Names), MemberType = typeof(AdminRoutes))]
        public async Task T_7A_01_enforced_only_an_admin_token_is_accepted(string name)
        {
            var route = AdminRoutes.Get(name);
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);
            var owner = route.ProgrammerIsOwner ? s.Programmer : s.Owner;

            var anonymous = await AdminRoutes.SendAsync(_client, route, s, null);
            Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
            Assert.Equal("UNAUTHENTICATED", await AdminRoutes.ErrorCode(anonymous));

            foreach (var caller in new[] { s.Other, s.Programmer, owner })
            {
                var forbidden = await AdminRoutes.SendAsync(_client, route, s, caller.Token);
                Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
                Assert.Equal("FORBIDDEN", await AdminRoutes.ErrorCode(forbidden));
            }

            AdminRoutes.AssertAllowed(route, await AdminRoutes.SendAsync(_client, route, s, s.Admin.Token));
        }

        [Theory]
        [MemberData(nameof(AdminRoutes.Names), MemberType = typeof(AdminRoutes))]
        public async Task T_7A_02_client_sent_isAdmin_or_ids_never_grant_access(string name)
        {
            var route = AdminRoutes.Get(name);
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);
            var spoof = $"?isAdmin=true&userId={s.Admin.Id}&requesterId={s.Admin.Id}&adminId={s.Admin.Id}";

            Assert.Equal(HttpStatusCode.Unauthorized, (await AdminRoutes.SendAsync(_client, route, s, null, spoof)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await AdminRoutes.SendAsync(_client, route, s, s.Other.Token, spoof)).StatusCode);
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }

        [Fact]
        public async Task T_7A_02b_programmers_cannot_verify_themselves_KI_05()
        {
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);
            foreach (var path in new[] { $"/api/ProgrammerProfile/{s.Programmer.Id}/verify", $"/api/Admin/programmers/{s.Programmer.Id}/verify" })
            {
                var request = new HttpRequestMessage(HttpMethod.Post, path);
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", s.Programmer.Token);
                Assert.Equal(HttpStatusCode.Forbidden, (await _client.SendAsync(request)).StatusCode);
            }
        }

        [Fact]
        public async Task T_7A_02c_moderation_and_deletion_change_nothing_when_refused()
        {
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);

            await AdminRoutes.SendAsync(_client, AdminRoutes.Get("Posts.Approve"), s, s.Owner.Token);
            await AdminRoutes.SendAsync(_client, AdminRoutes.Get("Admin.DeleteUser"), s, null);
            await AdminRoutes.SendAsync(_client, AdminRoutes.Get("Support.Delete"), s, s.Other.Token, "?isAdmin=true");

            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal("Pending", (await db.Posts.AsNoTracking().SingleAsync(p => p.Id == s.PostId)).Status);
                Assert.True(await db.Users.AnyAsync(u => u.Id == s.Owner.Id));
                Assert.True(await db.SupportMessages.AnyAsync(m => m.Id == s.MessageId));
            });
        }
    }

    public class AdminRouteFallbackTests : IClassFixture<DevFallbackApiFactory>
    {
        private readonly DevFallbackApiFactory _factory;
        private readonly HttpClient _client;

        public AdminRouteFallbackTests(DevFallbackApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Theory]
        [MemberData(nameof(AdminRoutes.Names), MemberType = typeof(AdminRoutes))]
        public async Task T_7A_03_tokenless_requests_pass_and_are_logged_but_tokens_are_enforced(string name)
        {
            var route = AdminRoutes.Get(name);
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);
            var owner = route.ProgrammerIsOwner ? s.Programmer : s.Owner;

            // A token is present → fully enforced, never the fallback.
            foreach (var caller in new[] { s.Other, s.Programmer, owner })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await AdminRoutes.SendAsync(_client, route, s, caller.Token, "?isAdmin=true")).StatusCode);
            }

            var invalid = await AdminRoutes.SendAsync(_client, route, s, "not-a-valid-token");
            Assert.Equal(HttpStatusCode.Unauthorized, invalid.StatusCode);

            var before = _factory.Logs.Entries.Count(e => e.Message.Contains("Auth.DevFallbackUsed TokenlessRequest"));
            var tokenless = await AdminRoutes.SendAsync(_client, route, s, null);

            AdminRoutes.AssertAllowed(route, tokenless);
            var logs = _factory.Logs.Entries.Where(e => e.Message.Contains("Auth.DevFallbackUsed TokenlessRequest")).ToList();
            Assert.True(logs.Count > before);
            // Case and route template only: no ids, emails or query strings.
            Assert.All(logs, e =>
            {
                Assert.DoesNotContain(owner.Email, e.Message);
                Assert.DoesNotContain("?", e.Message);
                Assert.DoesNotContain($"/{owner.Id}", e.Message);
            });
        }

        [Fact]
        public async Task T_7A_03b_admin_token_still_works_and_suspend_never_falls_back()
        {
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);

            AdminRoutes.AssertAllowed(AdminRoutes.Get("Admin.GetUsers"), await AdminRoutes.SendAsync(_client, AdminRoutes.Get("Admin.GetUsers"), s, s.Admin.Token));

            var suspend = await _client.PostAsJsonAsync($"/api/Admin/users/{s.Owner.Id}/suspend", new { reason = "test" });
            var unsuspend = await _client.PostAsync($"/api/Admin/users/{s.Owner.Id}/unsuspend", null);
            Assert.Equal(HttpStatusCode.Unauthorized, suspend.StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, unsuspend.StatusCode);
            // Refused, so no fallback use may be logged for them.
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed") && e.Message.Contains("suspend"));
            await _factory.WithDbAsync(async db => Assert.Equal(UserStatus.Active, (await db.Users.SingleAsync(u => u.Id == s.Owner.Id)).Status));
        }

        [Fact]
        public async Task T_7A_03c_a_tokenless_delete_is_audited_without_an_actor()
        {
            var s = await AdminRoutes.ScenarioAsync(_factory, _client);

            Assert.Equal(HttpStatusCode.OK, (await _client.DeleteAsync($"/api/Admin/users/{s.Owner.Id}")).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var evt = await db.SecurityEvents.AsNoTracking().SingleAsync(e => e.UserId == s.Owner.Id && e.EventType == "Admin.UserDeleted");
                Assert.Null(evt.ActorUserId);
                Assert.Equal(SecurityEventOutcome.Success, evt.Outcome);
            });
        }
    }

    public class AdminRouteRemoteFallbackTests : IClassFixture<DevFallbackRemoteApiFactory>
    {
        private readonly DevFallbackRemoteApiFactory _factory;

        public AdminRouteRemoteFallbackTests(DevFallbackRemoteApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("Admin.GetUsers")]
        [InlineData("Admin.DeleteUser")]
        [InlineData("Posts.Approve")]
        [InlineData("Support.All")]
        public async Task T_7A_04_non_loopback_clients_never_get_the_fallback(string name)
        {
            var client = _factory.CreateClient();
            var s = await AdminRoutes.ScenarioAsync(_factory, client);

            var response = await AdminRoutes.SendAsync(client, AdminRoutes.Get(name), s, null);

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Contains(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackRefused TokenlessRequest"));
        }
    }

    public class AdminRouteDevDefaultTests : IClassFixture<DevDefaultApiFactory>
    {
        private readonly DevDefaultApiFactory _factory;

        public AdminRouteDevDefaultTests(DevDefaultApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("Admin.GetUsers")]
        [InlineData("Admin.UpdateUser")]
        [InlineData("Posts.Pending")]
        [InlineData("Support.Delete")]
        public async Task T_7A_04b_development_without_the_switch_is_enforced(string name)
        {
            var client = _factory.CreateClient();
            var s = await AdminRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await AdminRoutes.SendAsync(client, AdminRoutes.Get(name), s, null)).StatusCode);
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }
    }
}
