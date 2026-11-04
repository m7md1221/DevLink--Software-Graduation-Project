using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace DevLink.Api.Tests
{
    // Verifies that partner features (posts, weather, notifications) and the M1
    // services are wired together correctly after the 2026-11-01 synchronization.
    public class WiringAndNotificationTests : IClassFixture<DevLinkApiFactory>
    {
        private readonly DevLinkApiFactory _factory;
        private readonly HttpClient _client;

        public WiringAndNotificationTests(DevLinkApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private HttpClient? _adminClient;

        // M2.7a: admin routes need an Admin token.
        private async Task<HttpClient> Admin() => _adminClient ??= await ApiTestHelpers.AdminClientAsync(_factory);
        private async Task<int> CreateUserAsync(string userType)
        {
            var email = ApiTestHelpers.UniqueEmail(userType.ToLower());
            var response = await (await Admin()).PostAsJsonAsync("/api/Admin/users",
                new { email, password = "Secret123", userType });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            int id = 0;
            await _factory.WithDbAsync(async db =>
                id = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync());

            // M2.7b: write routes take the caller from the token.
            var client = _factory.CreateClient();
            var login = await ApiTestHelpers.LoginAsync(client, email, "Secret123", userType);
            var token = (await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("accessToken").GetString();
            client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
            _clients[id] = client;
            return id;
        }

        private readonly Dictionary<int, HttpClient> _clients = new();

        // Creates a post as its author, then approves it: likes and comments need an approved post.
        private async Task<int> CreatePostAsync(int userId)
        {
            using var form = new MultipartFormDataContent
            {
                { new StringContent("Need a small website for my bakery"), "Content" }
            };

            var response = await _clients[userId].PostAsync("/api/Posts", form);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            var postId = body.GetProperty("postId").GetInt32();
            Assert.Equal(HttpStatusCode.OK, (await (await Admin()).PostAsync($"/api/Posts/{postId}/approve", null)).StatusCode);

            // Approval notifies the author; these tests count later notifications only.
            await _factory.WithDbAsync(async db => await db.Notifications.Where(n => n.UserId == userId).ExecuteDeleteAsync());
            return postId;
        }

        private async Task<JsonElement> NotificationsForAsync(int userId)
        {
            var response = await _clients[userId].GetAsync($"/api/Notifications/{userId}");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return await response.Content.ReadFromJsonAsync<JsonElement>();
        }

        [Fact]
        public void Every_controller_can_be_constructed_from_dependency_injection()
        {
            var controllerTypes = typeof(Program).Assembly.GetTypes()
                .Where(t => typeof(ControllerBase).IsAssignableFrom(t) && !t.IsAbstract)
                .ToList();

            Assert.Contains(controllerTypes, t => t.Name == "PostsController");
            Assert.Contains(controllerTypes, t => t.Name == "NotificationsController");

            using var scope = _factory.Services.CreateScope();
            foreach (var type in controllerTypes)
            {
                var controller = ActivatorUtilities.CreateInstance(scope.ServiceProvider, type);
                Assert.NotNull(controller);
            }
        }

        [Fact]
        public async Task Posts_feed_and_pending_endpoints_respond()
        {
            var customerId = await CreateUserAsync("Customer");

            var feed = await _client.GetAsync($"/api/Posts/feed?userId={customerId}");
            var pending = await (await Admin()).GetAsync("/api/Posts/pending");

            Assert.Equal(HttpStatusCode.OK, feed.StatusCode);
            Assert.Equal(HttpStatusCode.OK, pending.StatusCode);
        }

        [Fact]
        public async Task Weather_endpoint_is_wired_and_refuses_anonymous_callers()
        {
            // Refused before any call to the external weather service (unknown user: T-7C-06).
            var response = await _client.GetAsync("/api/Posts/weather/999999");

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }

        [Fact]
        public async Task Liking_a_post_notifies_its_author_and_the_notification_can_be_marked_read()
        {
            var authorId = await CreateUserAsync("Customer");
            var likerId = await CreateUserAsync("Programmer");
            var postId = await CreatePostAsync(authorId);

            var like = await _clients[likerId].PostAsJsonAsync($"/api/Posts/{postId}/like", new { });
            Assert.Equal(HttpStatusCode.OK, like.StatusCode);

            var notifications = await NotificationsForAsync(authorId);
            var notification = notifications.EnumerateArray().Single();
            Assert.Equal("like", notification.GetProperty("type").GetString());
            Assert.Equal(postId, notification.GetProperty("referenceId").GetInt32());
            Assert.False(notification.GetProperty("isRead").GetBoolean());

            var id = notification.GetProperty("id").GetInt32();
            var markRead = await _clients[authorId].PostAsync($"/api/Notifications/{id}/read", null);
            Assert.Equal(HttpStatusCode.OK, markRead.StatusCode);

            var after = await NotificationsForAsync(authorId);
            Assert.True(after.EnumerateArray().Single().GetProperty("isRead").GetBoolean());
        }

        // Characterizes CURRENT behaviour only: PostService keeps the newest five
        // notifications per user and deletes older ones. Whether to keep a full
        // history is an open product decision (docs/decision-log.md, N1).
        [Fact]
        public async Task Current_behaviour_only_the_newest_five_notifications_are_kept()
        {
            var authorId = await CreateUserAsync("Customer");
            var commenterId = await CreateUserAsync("Programmer");
            var postId = await CreatePostAsync(authorId);

            for (var i = 0; i < 7; i++)
            {
                var comment = await _clients[commenterId].PostAsJsonAsync($"/api/Posts/{postId}/comments",
                    new { content = $"Comment {i}" });
                Assert.Equal(HttpStatusCode.OK, comment.StatusCode);
            }

            await _factory.WithDbAsync(async db =>
                Assert.Equal(5, await db.Notifications.CountAsync(n => n.UserId == authorId)));
        }
    }
}
