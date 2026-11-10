using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DataBase.Models;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // ============================================================
    // M2.10 (N1): notifications are kept, the default response is unchanged,
    // paging by limit/before or page/pageSize, the unread count, retention.
    // ============================================================
    public class NotificationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public NotificationTests(SessionApiFactory factory)
        {
            factory.Time.Reset();
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<(Account Owner, Account Other, int[] Ids)> SeedAsync(int count, Func<int, bool>? isRead = null)
        {
            var owner = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var other = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var ids = new int[count];
            await _factory.WithDbAsync(async db =>
            {
                for (var i = 0; i < count; i++)
                {
                    var n = new Notification { UserId = owner.Id, Title = $"T{i}", Message = $"M{i}", Type = "like", IsRead = isRead?.Invoke(i) ?? false, CreatedAt = DateTime.UtcNow.AddMinutes(i - count) };
                    db.Notifications.Add(n);
                    await db.SaveChangesAsync();
                    ids[i] = n.Id;
                }
            });
            return (owner, other, ids);
        }

        private Task<HttpResponseMessage> GetAsync(string path, Account caller) =>
            SessionApiFactory.GetWithToken(_client, path, caller.Token);

        private async Task<int[]> IdsAsync(string path, Account caller)
        {
            var response = await GetAsync(path, caller);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(JsonValueKind.Array, body.ValueKind);
            return body.EnumerateArray().Select(n => n.GetProperty("id").GetInt32()).ToArray();
        }

        [Fact]
        public async Task T_NR_01_every_notification_is_kept()
        {
            var owner = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var commenter = await AdminRoutes.AccountAsync(_factory, _client, "Programmer");
            int postId = 0;
            await _factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = owner.Id, Content = "Keep my notifications", Status = "Approved" };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                postId = post.Id;
            });

            for (var i = 0; i < 7; i++)
            {
                var comment = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{postId}/comments", new { content = $"Comment {i}" }), commenter.Token);
                Assert.Equal(HttpStatusCode.OK, comment.StatusCode);
            }

            await _factory.WithDbAsync(async db =>
                Assert.Equal(7, await db.Notifications.CountAsync(n => n.UserId == owner.Id)));
        }

        [Fact]
        public async Task T_NR_02_without_parameters_the_newest_five_come_as_the_same_array_as_before()
        {
            var (owner, _, ids) = await SeedAsync(8);

            var response = await GetAsync($"/api/Notifications/{owner.Id}", owner);
            var body = await response.Content.ReadFromJsonAsync<JsonElement>();

            Assert.Equal(ids.Reverse().Take(5), body.EnumerateArray().Select(n => n.GetProperty("id").GetInt32()));
            var first = body.EnumerateArray().First();
            Assert.Equal(new[] { "id", "title", "message", "type", "isRead", "referenceId", "createdAt" },
                first.EnumerateObject().Select(p => p.Name));
        }

        [Fact]
        public async Task T_NR_03_limit_and_before_page_through_everything_newest_first()
        {
            var (owner, _, ids) = await SeedAsync(12);
            var seen = new List<int>();
            int? before = null;

            while (true)
            {
                var page = await IdsAsync($"/api/Notifications/{owner.Id}?limit=5" + (before == null ? "" : $"&before={before}"), owner);
                if (page.Length == 0) break;
                seen.AddRange(page);
                before = page.Last();
            }

            Assert.Equal(ids.Reverse(), seen);
        }

        [Fact]
        public async Task T_NR_04_page_and_pageSize_page_through_everything_newest_first()
        {
            var (owner, _, ids) = await SeedAsync(12);

            var pages = new[]
            {
                await IdsAsync($"/api/Notifications/{owner.Id}?page=1&pageSize=5", owner),
                await IdsAsync($"/api/Notifications/{owner.Id}?page=2&pageSize=5", owner),
                await IdsAsync($"/api/Notifications/{owner.Id}?page=3&pageSize=5", owner),
                await IdsAsync($"/api/Notifications/{owner.Id}?page=4&pageSize=5", owner)
            };

            Assert.Equal(new[] { 5, 5, 2, 0 }, pages.Select(p => p.Length));
            Assert.Equal(ids.Reverse(), pages.SelectMany(p => p));
            Assert.Equal(ids.Reverse().Take(5), await IdsAsync($"/api/Notifications/{owner.Id}?page=1", owner));
            Assert.Equal(ids.Reverse().Take(10), await IdsAsync($"/api/Notifications/{owner.Id}?pageSize=10", owner));
        }

        [Fact]
        public async Task T_NR_05_sizes_are_capped_at_50_and_bad_values_are_refused()
        {
            var (owner, _, _) = await SeedAsync(55);

            Assert.Equal(50, (await IdsAsync($"/api/Notifications/{owner.Id}?limit=500", owner)).Length);
            Assert.Equal(50, (await IdsAsync($"/api/Notifications/{owner.Id}?pageSize=51", owner)).Length);
            Assert.Empty(await IdsAsync($"/api/Notifications/{owner.Id}?page=2147483647&pageSize=50", owner));

            foreach (var query in new[] { "limit=0", "limit=-1", "pageSize=0", "page=0", "before=0", "before=-5", "limit=5&page=1", "before=10&pageSize=5", "limit=abc" })
            {
                Assert.Equal(HttpStatusCode.BadRequest, (await GetAsync($"/api/Notifications/{owner.Id}?{query}", owner)).StatusCode);
            }
        }

        [Fact]
        public async Task T_NR_06_the_unread_count_covers_every_unread_notification()
        {
            var (owner, other, _) = await SeedAsync(9, i => i % 3 == 0);

            var response = await GetAsync($"/api/Notifications/{owner.Id}/unread-count", owner);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal(6, (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("count").GetInt32());
            Assert.Equal(0, (await (await GetAsync($"/api/Notifications/{other.Id}/unread-count", other)).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("count").GetInt32());
        }

        [Fact]
        public async Task T_NR_07_only_the_recipient_reads_counts_or_marks()
        {
            var (owner, other, ids) = await SeedAsync(3);
            var admin = await AdminRoutes.AccountAsync(_factory, _client, "Admin");

            foreach (var caller in new[] { other, admin })
            {
                foreach (var path in new[] { $"/api/Notifications/{owner.Id}", $"/api/Notifications/{owner.Id}?limit=50", $"/api/Notifications/{owner.Id}?page=1&pageSize=50", $"/api/Notifications/{owner.Id}/unread-count" })
                {
                    Assert.Equal(HttpStatusCode.Forbidden, (await GetAsync(path, caller)).StatusCode);
                }

                Assert.Equal(HttpStatusCode.Forbidden, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, $"/api/Notifications/{ids[0]}/read"), caller.Token)).StatusCode);
            }

            Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync($"/api/Notifications/{owner.Id}/unread-count")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync($"/api/Notifications/{owner.Id}?limit=50")).StatusCode);
            await _factory.WithDbAsync(async db => Assert.False(await db.Notifications.AnyAsync(n => n.UserId == owner.Id && n.IsRead)));
        }

        private SessionCleanupService Cleanup =>
            _factory.Services.GetServices<IHostedService>().OfType<SessionCleanupService>().Single();

        [Fact]
        public async Task T_NR_08_retention_removes_read_after_180_days_and_unread_after_365_by_the_server_clock()
        {
            var owner = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var now = DateTime.UtcNow;
            var rows = new (string Name, int AgeDays, bool Read, bool Kept)[]
            {
                ("read-179", 179, true, true), ("read-181", 181, true, false),
                ("unread-181", 181, false, true), ("unread-364", 364, false, true), ("unread-366", 366, false, false),
                ("read-today", 0, true, true)
            };
            await _factory.WithDbAsync(async db =>
            {
                foreach (var row in rows)
                {
                    db.Notifications.Add(new Notification { UserId = owner.Id, Title = row.Name, Message = "m", Type = "like", IsRead = row.Read, CreatedAt = now.AddDays(-row.AgeDays) });
                }
                await db.SaveChangesAsync();
            });

            var summary = await Cleanup.RunOnceAsync(CancellationToken.None);

            Assert.True(summary.ReadNotificationsDeleted >= 1);
            Assert.True(summary.UnreadNotificationsDeleted >= 1);
            await _factory.WithDbAsync(async db =>
            {
                var left = await db.Notifications.Where(n => n.UserId == owner.Id).Select(n => n.Title).ToListAsync();
                Assert.Equal(rows.Where(r => r.Kept).Select(r => r.Name).OrderBy(n => n), left.OrderBy(n => n));
            });

            // Move the clock 2 days: read-179 passes 180 and unread-364 passes 365, so both go; the rest stay.
            _factory.Time.Advance(TimeSpan.FromDays(2));
            await Cleanup.RunOnceAsync(CancellationToken.None);
            await _factory.WithDbAsync(async db =>
            {
                var left = await db.Notifications.Where(n => n.UserId == owner.Id).Select(n => n.Title).ToListAsync();
                Assert.Equal(new[] { "read-today", "unread-181" }, left.OrderBy(n => n));
            });
        }

        [Fact]
        public async Task T_NR_09_creating_notifications_never_deletes_any()
        {
            var (owner, _, _) = await SeedAsync(20);
            var liker = await AdminRoutes.AccountAsync(_factory, _client, "Programmer");
            int postId = 0;
            await _factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = owner.Id, Content = "Like me", Status = "Approved" };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                postId = post.Id;
            });

            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{postId}/like", new { }), liker.Token)).StatusCode);

            await _factory.WithDbAsync(async db => Assert.Equal(21, await db.Notifications.CountAsync(n => n.UserId == owner.Id)));
        }
    }

    // Retention values are configurable, and 0 turns a rule off.
    public class NotificationRetentionConfigFactory : SessionApiFactory
    {
        protected override IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?>
        {
            ["Notifications:ReadRetentionDays"] = "0",
            ["Notifications:UnreadRetentionDays"] = "30"
        };
    }

    public class NotificationRetentionConfigTests : IClassFixture<NotificationRetentionConfigFactory>
    {
        private readonly NotificationRetentionConfigFactory _factory;

        public NotificationRetentionConfigTests(NotificationRetentionConfigFactory factory)
        {
            _factory = factory;
            factory.CreateClient();
        }

        [Fact]
        public async Task T_NR_10_configured_values_apply_and_zero_keeps_everything_of_that_kind()
        {
            var user = new User { Email = ApiTestHelpers.UniqueEmail("retention"), PasswordHash = "x", UserType = "Customer" };
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(user);
                await db.SaveChangesAsync();
                db.Notifications.AddRange(
                    new Notification { UserId = user.Id, Title = "read-1000", Message = "m", Type = "like", IsRead = true, CreatedAt = DateTime.UtcNow.AddDays(-1000) },
                    new Notification { UserId = user.Id, Title = "unread-31", Message = "m", Type = "like", IsRead = false, CreatedAt = DateTime.UtcNow.AddDays(-31) },
                    new Notification { UserId = user.Id, Title = "unread-29", Message = "m", Type = "like", IsRead = false, CreatedAt = DateTime.UtcNow.AddDays(-29) });
                await db.SaveChangesAsync();
            });

            await _factory.Services.GetServices<IHostedService>().OfType<SessionCleanupService>().Single().RunOnceAsync(CancellationToken.None);

            await _factory.WithDbAsync(async db =>
            {
                var left = await db.Notifications.Where(n => n.UserId == user.Id).Select(n => n.Title).ToListAsync();
                Assert.Equal(new[] { "read-1000", "unread-29" }, left.OrderBy(n => n));
            });
        }
    }
}
