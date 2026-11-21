using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DataBase.Models;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // ============================================================
    // Integration of the partner's 2026-11-21 features under the M2 rules
    // (authorization enforced, no development fallback):
    //   T-SV-01  saved-post routes: anonymous 401, admin 403
    //   T-SV-02  save / unsave toggles for the token's user; a client userId is ignored
    //   T-SV-03  a saved list is private: another user's list is 403
    //   T-SV-04  only visible posts can be saved (pending post of someone else: 404)
    //   T-SV-05  the saved list carries signed image URLs and drops posts that are no longer visible
    //   T-SV-06  feed rows carry isSaved and framework
    //   T-SV-07  the framework rule on applications (partner logic)
    //   T-SV-08  the new-application notification names the applicant by nickname, never by email (KI-58)
    //   T-SV-09  deleting a user with saved posts succeeds (NO ACTION foreign key)
    // ============================================================
    public class SavedPostsTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public SavedPostsTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<WriteScenario> Scenario() => WriteRoutes.ScenarioAsync(_factory, _client);

        private Task<HttpResponseMessage> Send(HttpMethod method, string path, Account? caller, object? body = null) =>
            WriteRoutes.SendAsync(_client, WriteRoutes.Json(method, path, body), caller?.Token);

        private static async Task<JsonElement> Json(HttpResponseMessage response) =>
            JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

        private async Task<int> PostAsync(int ownerId, string status, string? framework = null)
        {
            var id = 0;
            await _factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = ownerId, Content = "Saved-post test", Status = status, Framework = framework };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                db.PostImages.Add(new PostImage { PostId = post.Id, ImageData = TestFiles.Png, ContentType = "image/png", SortOrder = 0 });
                await db.SaveChangesAsync();
                id = post.Id;
            });
            return id;
        }

        public static IEnumerable<object[]> Routes => new[]
        {
            new object[] { "POST", "/api/Posts/{post}/save" },
            new object[] { "GET", "/api/Posts/saved/{user}" },
            new object[] { "GET", "/api/Posts/{post}/is-saved?userId={user}" },
        };

        [Theory]
        [MemberData(nameof(Routes))]
        public async Task T_SV_01_anonymous_is_401_and_admin_is_403(string method, string template)
        {
            var s = await Scenario();
            var path = template.Replace("{post}", s.PostId.ToString()).Replace("{user}", s.Owner.Id.ToString());
            var verb = new HttpMethod(method);
            object? body = method == "POST" ? new { userId = s.Owner.Id } : null;

            var anonymous = await Send(verb, path, null, body);
            Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);

            var admin = await Send(verb, path.Replace(s.Owner.Id.ToString(), s.Admin.Id.ToString()), s.Admin, body);
            Assert.Equal(HttpStatusCode.Forbidden, admin.StatusCode);
        }

        [Fact]
        public async Task T_SV_02_save_and_unsave_belong_to_the_token_user_and_ignore_a_client_userId()
        {
            var s = await Scenario();

            // The programmer sends the owner's id: the row is still the programmer's.
            var save = await Send(HttpMethod.Post, $"/api/Posts/{s.PostId}/save", s.Programmer, new { userId = s.Owner.Id });
            Assert.Equal(HttpStatusCode.OK, save.StatusCode);
            Assert.True((await Json(save)).GetProperty("isSaved").GetBoolean());

            await _factory.WithDbAsync(async db =>
            {
                Assert.True(await db.SavedPosts.AnyAsync(sp => sp.PostId == s.PostId && sp.UserId == s.Programmer.Id));
                Assert.False(await db.SavedPosts.AnyAsync(sp => sp.PostId == s.PostId && sp.UserId == s.Owner.Id));
            });

            var isSaved = await Send(HttpMethod.Get, $"/api/Posts/{s.PostId}/is-saved?userId={s.Owner.Id}", s.Programmer);
            Assert.True((await Json(isSaved)).GetProperty("isSaved").GetBoolean());

            var unsave = await Send(HttpMethod.Post, $"/api/Posts/{s.PostId}/save", s.Programmer);
            Assert.False((await Json(unsave)).GetProperty("isSaved").GetBoolean());
            await _factory.WithDbAsync(async db =>
                Assert.False(await db.SavedPosts.AnyAsync(sp => sp.PostId == s.PostId && sp.UserId == s.Programmer.Id)));
        }

        [Fact]
        public async Task T_SV_03_a_saved_list_is_private()
        {
            var s = await Scenario();
            await Send(HttpMethod.Post, $"/api/Posts/{s.PostId}/save", s.Programmer);

            var other = await Send(HttpMethod.Get, $"/api/Posts/saved/{s.Programmer.Id}", s.OtherProgrammer);
            Assert.Equal(HttpStatusCode.Forbidden, other.StatusCode);

            var own = await Send(HttpMethod.Get, $"/api/Posts/saved/{s.Programmer.Id}", s.Programmer);
            Assert.Equal(HttpStatusCode.OK, own.StatusCode);
            Assert.Equal(1, (await Json(own)).GetProperty("posts").GetArrayLength());
        }

        [Fact]
        public async Task T_SV_04_only_visible_posts_can_be_saved()
        {
            var s = await Scenario();
            var pending = await PostAsync(s.Other.Id, "Pending");

            var refused = await Send(HttpMethod.Post, $"/api/Posts/{pending}/save", s.Programmer);
            Assert.Equal(HttpStatusCode.NotFound, refused.StatusCode);

            var missing = await Send(HttpMethod.Post, "/api/Posts/987654321/save", s.Programmer);
            Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);

            // The author may keep their own pending post.
            var own = await Send(HttpMethod.Post, $"/api/Posts/{pending}/save", s.Other);
            Assert.Equal(HttpStatusCode.OK, own.StatusCode);
        }

        [Fact]
        public async Task T_SV_05_saved_list_has_signed_image_urls_and_drops_posts_no_longer_visible()
        {
            var s = await Scenario();
            var withImage = await PostAsync(s.Other.Id, "Approved");
            await Send(HttpMethod.Post, $"/api/Posts/{withImage}/save", s.Programmer);
            await Send(HttpMethod.Post, $"/api/Posts/{s.PostId}/save", s.Programmer);

            var list = await Json(await Send(HttpMethod.Get, $"/api/Posts/saved/{s.Programmer.Id}", s.Programmer));
            var saved = list.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == withImage);
            var url = saved.GetProperty("images")[0].GetProperty("url").GetString()!;
            Assert.Contains("sig=", url);
            Assert.Contains("exp=", url);
            Assert.True(saved.GetProperty("isSaved").GetBoolean());

            // The signed URL works without a token.
            var image = await _client.GetAsync(url);
            Assert.Equal(HttpStatusCode.OK, image.StatusCode);

            // A post rejected later disappears from the list.
            await _factory.WithDbAsync(async db =>
            {
                var post = await db.Posts.SingleAsync(p => p.Id == withImage);
                post.Status = "Rejected";
                await db.SaveChangesAsync();
            });
            var after = await Json(await Send(HttpMethod.Get, $"/api/Posts/saved/{s.Programmer.Id}", s.Programmer));
            Assert.DoesNotContain(after.GetProperty("posts").EnumerateArray(), p => p.GetProperty("id").GetInt32() == withImage);
        }

        [Fact]
        public async Task T_SV_06_feed_rows_carry_isSaved_and_framework()
        {
            var s = await Scenario();
            var flutterPost = await PostAsync(s.Other.Id, "Approved", "Flutter");
            await Send(HttpMethod.Post, $"/api/Posts/{flutterPost}/save", s.Programmer);

            var feed = await Json(await Send(HttpMethod.Get, $"/api/Posts/feed?userId={s.Programmer.Id}&pageSize=50", s.Programmer));
            var row = feed.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == flutterPost);
            Assert.True(row.GetProperty("isSaved").GetBoolean());
            Assert.Equal("Flutter", row.GetProperty("framework").GetString());

            var asOwner = await Json(await Send(HttpMethod.Get, $"/api/Posts/feed?userId={s.Other.Id}&pageSize=50", s.Other));
            var ownerRow = asOwner.GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == flutterPost);
            Assert.False(ownerRow.GetProperty("isSaved").GetBoolean());
        }

        [Fact]
        public async Task T_SV_07_a_post_that_names_a_framework_takes_applications_for_it_only()
        {
            var s = await Scenario();
            var flutterPost = await PostAsync(s.Owner.Id, "Approved", "Flutter");

            var none = await Send(HttpMethod.Post, $"/api/Posts/{flutterPost}/apply", s.Programmer, new { proposal = "I can build it" });
            Assert.Equal(HttpStatusCode.BadRequest, none.StatusCode);

            var wrong = await Send(HttpMethod.Post, $"/api/Posts/{flutterPost}/apply", s.Programmer, new { proposal = "I can build it", framework = "React" });
            Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode);

            var right = await Send(HttpMethod.Post, $"/api/Posts/{flutterPost}/apply", s.Programmer, new { proposal = "I can build it", framework = "flutter" });
            Assert.Equal(HttpStatusCode.OK, right.StatusCode);

            await _factory.WithDbAsync(async db =>
                Assert.Equal("flutter", (await db.PostApplications.SingleAsync(a => a.PostId == flutterPost)).Framework));
        }

        [Fact]
        public async Task T_SV_08_new_application_notification_names_the_applicant_by_nickname_not_email()
        {
            var s = await Scenario();
            var post = await PostAsync(s.Owner.Id, "Approved");

            var apply = await Send(HttpMethod.Post, $"/api/Posts/{post}/apply", s.OtherProgrammer, new { proposal = "I can build it" });
            Assert.Equal(HttpStatusCode.OK, apply.StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var notice = await db.Notifications.SingleAsync(n => n.UserId == s.Owner.Id && n.Type == "application" && n.ReferenceId == post);
                Assert.Equal("Prog applied to your post.", notice.Message);
                Assert.DoesNotContain(s.OtherProgrammer.Email.Split('@')[0], notice.Message);
            });
        }

        [Fact]
        public async Task T_SV_09_deleting_a_user_with_saved_posts_succeeds_and_removes_the_list()
        {
            var s = await Scenario();
            await Send(HttpMethod.Post, $"/api/Posts/{s.PostId}/save", s.FreshCustomer);

            var delete = await Send(HttpMethod.Delete, $"/api/Admin/users/{s.FreshCustomer.Id}", s.Admin);
            Assert.Equal(HttpStatusCode.OK, delete.StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                Assert.False(await db.Users.AnyAsync(u => u.Id == s.FreshCustomer.Id));
                Assert.False(await db.SavedPosts.AnyAsync(sp => sp.UserId == s.FreshCustomer.Id));
            });
        }
    }
}
