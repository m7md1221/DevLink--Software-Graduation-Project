using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DataBase;
using DataBase.Models;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // ============================================================
    // M2.7b authorization matrix for the 19 write routes that trusted a
    // client id (docs/M2_7_ENDPOINT_PLAN.md §2):
    //   T-7B-01  enforced: anonymous 401; other user / wrong role refused
    //   T-7B-02  enforced: the rightful caller succeeds
    //   T-7B-03  enforced: the admin outcome of each route
    //   T-7B-04  fallback: tokenless acts with the client id and is logged once; tokens stay enforced
    //   T-7B-05  fallback refused for a non-loopback client / when the switch is not set
    //   T-7B-1x  spoofing and business rules
    // ============================================================
    public sealed record WriteScenario(
        Account Owner, Account Other, Account FreshCustomer,
        Account Programmer, Account OtherProgrammer, Account FreshProgrammer, Account Admin,
        int PostId, int CommentId, int ApplicationId, int NotificationId, int MessageId);

    // Build sends the Actor's id wherever the route has a client id. Refused callers replay it with their own token (spoofing).
    public sealed record WriteRoute(
        string Name,
        Func<WriteScenario, HttpRequestMessage> Build,
        Func<WriteScenario, Account> Actor,
        Func<WriteScenario, Account[]> Refused,
        HttpStatusCode AdminStatus = HttpStatusCode.Forbidden,
        string FallbackCase = "IdentityFromClient");

    public static class WriteRoutes
    {
        public static HttpRequestMessage Json(HttpMethod method, string path, object? body = null)
        {
            var request = new HttpRequestMessage(method, path);
            if (body != null) request.Content = JsonContent.Create(body);
            return request;
        }

        public static HttpRequestMessage Form(HttpMethod method, string path, params (string Name, string Value)[] fields)
        {
            var form = new MultipartFormDataContent();
            foreach (var (name, value) in fields) form.Add(new StringContent(value), name);
            return new HttpRequestMessage(method, path) { Content = form };
        }

        public static HttpRequestMessage File(string path, string field, string fileName)
        {
            var form = new MultipartFormDataContent();
            form.Add(new ByteArrayContent(TestFiles.Pdf), field, fileName);
            return new HttpRequestMessage(HttpMethod.Post, path) { Content = form };
        }

        private static (string, string)[] CustomerFields(int userId) => new[]
        {
            ("UserId", userId.ToString()), ("Nickname", "Matrix"), ("Country", "PS"), ("City", "Nablus"), ("PhoneNumber", "0590000000")
        };

        private static (string, string)[] ProgrammerFields(int userId) => CustomerFields(userId)
            .Concat(new[] { ("Specialty", "Backend"), ("University", "NNU") }).ToArray();

        public static readonly WriteRoute[] All =
        {
            new("CustomerProfile.Create", s => Form(HttpMethod.Post, "/api/CustomerProfile", CustomerFields(s.FreshCustomer.Id)),
                s => s.FreshCustomer, s => new[] { s.Programmer }),
            new("CustomerProfile.Update", s => Form(HttpMethod.Put, $"/api/CustomerProfile/{s.Owner.Id}", ("City", "Changed")),
                s => s.Owner, s => new[] { s.Other, s.Programmer }),
            new("ProgrammerProfile.Create", s => Form(HttpMethod.Post, "/api/ProgrammerProfile", ProgrammerFields(s.FreshProgrammer.Id)),
                s => s.FreshProgrammer, s => new[] { s.Owner }),
            new("ProgrammerProfile.Update", s => Form(HttpMethod.Put, $"/api/ProgrammerProfile/{s.Programmer.Id}", ("City", "Changed")),
                s => s.Programmer, s => new[] { s.OtherProgrammer, s.Owner }),
            new("ProgrammerProfile.UploadCv", s => File($"/api/ProgrammerProfile/{s.Programmer.Id}/cv", "cv", "cv.pdf"),
                s => s.Programmer, s => new[] { s.OtherProgrammer, s.Owner }),
            new("ProgrammerProfile.DeleteCv", s => Json(HttpMethod.Delete, $"/api/ProgrammerProfile/{s.Programmer.Id}/cv"),
                s => s.Programmer, s => new[] { s.OtherProgrammer, s.Owner }),
            new("ProgrammerProfile.UploadCertificate", s => File($"/api/ProgrammerProfile/{s.Programmer.Id}/certificate", "certificate", "cert.pdf"),
                s => s.Programmer, s => new[] { s.OtherProgrammer, s.Owner }),
            new("ProgrammerProfile.DeleteCertificate", s => Json(HttpMethod.Delete, $"/api/ProgrammerProfile/{s.Programmer.Id}/certificate"),
                s => s.Programmer, s => new[] { s.OtherProgrammer, s.Owner }),
            new("Notifications.Read", s => Json(HttpMethod.Post, $"/api/Notifications/{s.NotificationId}/read"),
                s => s.Owner, s => new[] { s.Other, s.Programmer }, FallbackCase: "TokenlessRequest"),
            new("Posts.Create", s => Form(HttpMethod.Post, "/api/Posts", ("UserId", s.Owner.Id.ToString()), ("Content", "Need an app")),
                s => s.Owner, _ => Array.Empty<Account>()),
            new("Posts.Delete", s => Json(HttpMethod.Delete, $"/api/Posts/{s.PostId}?userId={s.Owner.Id}&isAdmin=true"),
                s => s.Owner, s => new[] { s.Other, s.Programmer }, HttpStatusCode.OK),
            new("Posts.Like", s => Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/like", new { userId = s.Owner.Id }),
                s => s.Owner, _ => Array.Empty<Account>(), HttpStatusCode.OK),
            new("Posts.Comment", s => Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/comments", new { userId = s.Owner.Id, content = "Hello" }),
                s => s.Owner, _ => Array.Empty<Account>(), HttpStatusCode.OK),
            new("Posts.DeleteComment", s => Json(HttpMethod.Delete, $"/api/Posts/comments/{s.CommentId}?userId={s.Other.Id}&isAdmin=true"),
                s => s.Other, s => new[] { s.FreshCustomer, s.Programmer }, HttpStatusCode.OK),
            new("Posts.Apply", s => Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/apply", new { programmerId = s.OtherProgrammer.Id, proposal = "I can build it" }),
                s => s.OtherProgrammer, s => new[] { s.Other }),
            new("Posts.Applications", s => Json(HttpMethod.Get, $"/api/Posts/{s.PostId}/applications?requesterId={s.Owner.Id}"),
                s => s.Owner, s => new[] { s.Other, s.Programmer }),
            new("Posts.Accept", s => Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/applications/{s.ApplicationId}/accept?requesterId={s.Owner.Id}"),
                s => s.Owner, s => new[] { s.Other, s.Programmer }),
            new("Support.Send", s => Json(HttpMethod.Post, "/api/Support", new { userId = s.Owner.Id, name = "Owner", email = s.Owner.Email, subject = "Help", message = "Question" }),
                s => s.Owner, _ => Array.Empty<Account>()),
            new("Support.MarkReplyRead", s => Json(HttpMethod.Post, $"/api/Support/{s.MessageId}/mark-reply-read"),
                s => s.Owner, s => new[] { s.Other, s.Programmer }, FallbackCase: "TokenlessRequest"),
        };

        public static IEnumerable<object[]> Names => All.Select(r => new object[] { r.Name });

        public static WriteRoute Get(string name) => All.Single(r => r.Name == name);

        public static async Task<WriteScenario> ScenarioAsync(DevLinkApiFactory factory, HttpClient client)
        {
            var owner = await AdminRoutes.AccountAsync(factory, client, "Customer");
            var other = await AdminRoutes.AccountAsync(factory, client, "Customer");
            var freshCustomer = await AdminRoutes.AccountAsync(factory, client, "Customer");
            var programmer = await AdminRoutes.AccountAsync(factory, client, "Programmer");
            var otherProgrammer = await AdminRoutes.AccountAsync(factory, client, "Programmer");
            var freshProgrammer = await AdminRoutes.AccountAsync(factory, client, "Programmer");
            var admin = await AdminRoutes.AccountAsync(factory, client, "Admin");

            int postId = 0, commentId = 0, applicationId = 0, notificationId = 0, messageId = 0;
            await factory.WithDbAsync(async db =>
            {
                db.CustomerProfiles.Add(new CustomerProfile { UserId = owner.Id, Nickname = "Owner", Country = "PS", City = "Nablus", PhoneNumber = "0590000001" });
                foreach (var p in new[] { programmer, otherProgrammer })
                {
                    db.ProgrammerProfiles.Add(new ProgrammerProfile
                    {
                        UserId = p.Id, Nickname = "Prog", Country = "PS", City = "Nablus", PhoneNumber = "0590000002", Specialty = "Backend", University = "NNU",
                        CV = new byte[] { 1 }, CVName = "cv.pdf", Certificate = new byte[] { 1 }, CertificateName = "cert.pdf", CertificateType = "application/pdf", IsVerified = true
                    });
                }

                var post = new Post { UserId = owner.Id, Content = "Need a small website", Status = "Approved" };
                var notification = new Notification { UserId = owner.Id, Title = "T", Message = "M", Type = "like" };
                var message = new SupportMessage { UserId = owner.Id, Name = "Owner", Email = owner.Email, Subject = "Help", Message = "Question", Status = "Replied", AdminReply = "Answer" };
                db.Posts.Add(post);
                db.Notifications.Add(notification);
                db.SupportMessages.Add(message);
                await db.SaveChangesAsync();

                var comment = new PostComment { PostId = post.Id, UserId = other.Id, Content = "Nice" };
                var application = new PostApplication { PostId = post.Id, ProgrammerId = programmer.Id, Proposal = "Hire me", Status = "Pending" };
                db.PostComments.Add(comment);
                db.PostApplications.Add(application);
                await db.SaveChangesAsync();

                postId = post.Id;
                commentId = comment.Id;
                applicationId = application.Id;
                notificationId = notification.Id;
                messageId = message.Id;
            });

            return new WriteScenario(owner, other, freshCustomer, programmer, otherProgrammer, freshProgrammer, admin, postId, commentId, applicationId, notificationId, messageId);
        }

        public static Task<HttpResponseMessage> SendAsync(HttpClient client, HttpRequestMessage request, string? token)
        {
            if (token != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return client.SendAsync(request);
        }
    }

    // D-11 data: an approved post owned by a programmer, with an application from another programmer.
    public static class ProgrammerOwnedPost
    {
        public static async Task<(int PostId, int ApplicationId)> CreateAsync(DevLinkApiFactory factory, WriteScenario s)
        {
            int postId = 0, applicationId = 0;
            await factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = s.Programmer.Id, Content = "Programmer post", Status = "Approved" };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                var application = new PostApplication { PostId = post.Id, ProgrammerId = s.OtherProgrammer.Id, Proposal = "Older row", Status = "Pending" };
                db.PostApplications.Add(application);
                await db.SaveChangesAsync();
                postId = post.Id;
                applicationId = application.Id;
            });
            return (postId, applicationId);
        }

        public static async Task AssertUnchangedAsync(DevLinkApiFactory factory, int postId, int applicationId)
        {
            await factory.WithDbAsync(async db =>
            {
                Assert.Equal("Pending", (await db.PostApplications.AsNoTracking().SingleAsync(a => a.Id == applicationId)).Status);
                Assert.False((await db.Posts.AsNoTracking().SingleAsync(p => p.Id == postId)).IsClosed);
            });
        }
    }

    public class WriteRouteAuthorizationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public WriteRouteAuthorizationTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<WriteScenario> Scenario() => WriteRoutes.ScenarioAsync(_factory, _client);

        private Task<HttpResponseMessage> Send(HttpRequestMessage request, Account? caller) =>
            WriteRoutes.SendAsync(_client, request, caller?.Token);

        [Theory]
        [MemberData(nameof(WriteRoutes.Names), MemberType = typeof(WriteRoutes))]
        public async Task T_7B_01_enforced_anonymous_other_user_and_wrong_role_are_refused(string name)
        {
            var route = WriteRoutes.Get(name);
            var s = await Scenario();

            var anonymous = await Send(route.Build(s), null);
            Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
            Assert.Equal("UNAUTHENTICATED", await AdminRoutes.ErrorCode(anonymous));

            var invalid = await WriteRoutes.SendAsync(_client, route.Build(s), "not-a-valid-token");
            Assert.Equal(HttpStatusCode.Unauthorized, invalid.StatusCode);

            foreach (var caller in route.Refused(s))
            {
                var refused = await Send(route.Build(s), caller);
                Assert.Equal(HttpStatusCode.Forbidden, refused.StatusCode);
                Assert.Equal("FORBIDDEN", await AdminRoutes.ErrorCode(refused));
            }
        }

        [Theory]
        [MemberData(nameof(WriteRoutes.Names), MemberType = typeof(WriteRoutes))]
        public async Task T_7B_02_enforced_the_rightful_caller_succeeds(string name)
        {
            var route = WriteRoutes.Get(name);
            var s = await Scenario();

            var response = await Send(route.Build(s), route.Actor(s));

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Theory]
        [MemberData(nameof(WriteRoutes.Names), MemberType = typeof(WriteRoutes))]
        public async Task T_7B_03_enforced_admin_outcome(string name)
        {
            var route = WriteRoutes.Get(name);
            var s = await Scenario();

            var response = await Send(route.Build(s), s.Admin);

            Assert.Equal(route.AdminStatus, response.StatusCode);
        }

        // ---------------- spoofing: the token decides, client values are ignored ----------------

        [Fact]
        public async Task T_7B_10_delete_with_spoofed_userId_and_isAdmin_is_refused_and_changes_nothing()
        {
            var s = await Scenario();

            var post = await Send(WriteRoutes.Json(HttpMethod.Delete, $"/api/Posts/{s.PostId}?userId={s.Owner.Id}&isAdmin=true"), s.Other);
            var comment = await Send(WriteRoutes.Json(HttpMethod.Delete, $"/api/Posts/comments/{s.CommentId}?userId={s.Other.Id}&isAdmin=true"), s.Programmer);

            Assert.Equal(HttpStatusCode.Forbidden, post.StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, comment.StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.False((await db.Posts.AsNoTracking().SingleAsync(p => p.Id == s.PostId)).IsDeleted);
                Assert.True(await db.PostComments.AnyAsync(c => c.Id == s.CommentId));
            });
        }

        [Fact]
        public async Task T_7B_11_client_ids_in_bodies_are_ignored_the_action_belongs_to_the_token()
        {
            var s = await Scenario();

            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Get("Posts.Like").Build(s), s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Get("Posts.Comment").Build(s), s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Get("Posts.Create").Build(s), s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/apply", new { programmerId = s.Programmer.Id, proposal = "As someone else" }), s.OtherProgrammer)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Form(HttpMethod.Post, "/api/CustomerProfile", ("UserId", s.Owner.Id.ToString()), ("Nickname", "Spoof"), ("Country", "PS"), ("City", "X"), ("PhoneNumber", "1")), s.FreshCustomer)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                Assert.True(await db.PostLikes.AnyAsync(l => l.PostId == s.PostId && l.UserId == s.Other.Id));
                Assert.False(await db.PostLikes.AnyAsync(l => l.PostId == s.PostId && l.UserId == s.Owner.Id));
                Assert.False(await db.PostComments.AnyAsync(c => c.PostId == s.PostId && c.UserId == s.Owner.Id));
                Assert.Equal(1, await db.Posts.CountAsync(p => p.UserId == s.Owner.Id));
                Assert.True(await db.Posts.AnyAsync(p => p.UserId == s.Other.Id));
                Assert.True(await db.PostApplications.AnyAsync(a => a.PostId == s.PostId && a.ProgrammerId == s.OtherProgrammer.Id));
                Assert.True(await db.CustomerProfiles.AnyAsync(p => p.UserId == s.FreshCustomer.Id && p.Nickname == "Spoof"));
                Assert.Equal("Owner", (await db.CustomerProfiles.AsNoTracking().SingleAsync(p => p.UserId == s.Owner.Id)).Nickname);
            });
        }

        [Fact]
        public async Task T_7B_12_accept_and_applications_ignore_a_spoofed_requesterId()
        {
            var s = await Scenario();

            Assert.Equal(HttpStatusCode.Forbidden, (await Send(WriteRoutes.Get("Posts.Accept").Build(s), s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await Send(WriteRoutes.Get("Posts.Applications").Build(s), s.Other)).StatusCode);

            await _factory.WithDbAsync(async db =>
                Assert.Equal("Pending", (await db.PostApplications.AsNoTracking().SingleAsync(a => a.Id == s.ApplicationId)).Status));
        }

        [Fact]
        public async Task T_7B_13_support_sender_comes_from_the_account()
        {
            var s = await Scenario();

            var response = await Send(WriteRoutes.Json(HttpMethod.Post, "/api/Support",
                new { userId = s.Other.Id, name = "Spoofed", email = "spoofed@example.test", subject = "Mine", message = "From the owner" }), s.Owner);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                var message = await db.SupportMessages.AsNoTracking().SingleAsync(m => m.Subject == "Mine" && m.Email == s.Owner.Email);
                Assert.Equal(s.Owner.Id, message.UserId);
                Assert.Equal("Owner", message.Name);
            });

            // No name or email needed from a signed-in client; a programmer may send, too (D-7).
            var noSender = await Send(WriteRoutes.Json(HttpMethod.Post, "/api/Support", new { subject = "Hi", message = "Question" }), s.Programmer);
            Assert.Equal(HttpStatusCode.OK, noSender.StatusCode);
        }

        // ---------------- business rules ----------------

        [Fact]
        public async Task T_7B_20_post_create_is_always_pending_a_client_status_is_ignored()
        {
            var s = await Scenario();

            var response = await Send(WriteRoutes.Form(HttpMethod.Post, "/api/Posts", ("Content", "Client says approved"), ("Status", "Approved"), ("status", "Approved")), s.Owner);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            await _factory.WithDbAsync(async db =>
                Assert.Equal("Pending", (await db.Posts.AsNoTracking().SingleAsync(p => p.Content == "Client says approved" && p.UserId == s.Owner.Id)).Status));
            var feed = await (await SessionApiFactory.GetWithToken(_client, $"/api/Posts/feed?userId={s.Owner.Id}", s.Owner.Token)).Content.ReadAsStringAsync();
            Assert.DoesNotContain("Client says approved", feed);
        }

        [Fact]
        public void T_7B_20b_the_service_is_the_only_post_creation_path_and_sets_pending_explicitly()
        {
            var backend = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "backend"));
            var creators = Directory.GetFiles(backend, "*.cs", SearchOption.AllDirectories)
                .Where(f => !f.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}") && !f.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}") && !f.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}"))
                .Where(f => System.Text.RegularExpressions.Regex.IsMatch(System.IO.File.ReadAllText(f), @"new Post\b"))
                .Select(Path.GetFileName)
                .ToList();

            Assert.Equal(new[] { "PostService.cs" }, creators);
            Assert.Contains("Status = \"Pending\"", System.IO.File.ReadAllText(Path.Combine(backend, "Services", "PostService.cs")));
        }

        [Fact]
        public async Task T_7B_21_comment_delete_author_post_owner_or_admin()
        {
            var s = await Scenario();

            // Comment by Other on Owner's post: the post owner may delete it.
            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Json(HttpMethod.Delete, $"/api/Posts/comments/{s.CommentId}"), s.Owner)).StatusCode);
            await _factory.WithDbAsync(async db => Assert.False(await db.PostComments.AnyAsync(c => c.Id == s.CommentId)));
        }

        [Fact]
        public async Task T_7B_22_apply_rules()
        {
            var s = await Scenario();
            int programmerPost = 0, pendingPost = 0;
            await _factory.WithDbAsync(async db =>
            {
                var own = new Post { UserId = s.OtherProgrammer.Id, Content = "My own", Status = "Approved" };
                var pending = new Post { UserId = s.Owner.Id, Content = "Not reviewed", Status = "Pending" };
                db.Posts.AddRange(own, pending);
                await db.SaveChangesAsync();
                programmerPost = own.Id;
                pendingPost = pending.Id;
            });

            Task<HttpResponseMessage> Apply(int postId) =>
                Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{postId}/apply", new { proposal = "I can build it" }), s.OtherProgrammer);

            var own = await Apply(programmerPost);
            Assert.Equal(HttpStatusCode.BadRequest, own.StatusCode);
            Assert.Contains("own post", await own.Content.ReadAsStringAsync());

            var pending = await Apply(pendingPost);
            Assert.Equal(HttpStatusCode.BadRequest, pending.StatusCode);
            Assert.Contains("not open", await pending.Content.ReadAsStringAsync());

            Assert.Equal(HttpStatusCode.OK, (await Apply(s.PostId)).StatusCode);
            var twice = await Apply(s.PostId);
            Assert.Equal(HttpStatusCode.BadRequest, twice.StatusCode);
            await _factory.WithDbAsync(async db =>
                Assert.Equal(1, await db.PostApplications.CountAsync(a => a.PostId == s.PostId && a.ProgrammerId == s.OtherProgrammer.Id)));
        }

        [Fact]
        public async Task T_D11_01_enforced_apply_to_a_programmer_owned_post_is_refused()
        {
            var s = await Scenario();
            var (postId, _) = await ProgrammerOwnedPost.CreateAsync(_factory, s);

            var response = await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{postId}/apply", new { proposal = "I can build it" }), s.FreshProgrammer);

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Contains("not open for applications", await response.Content.ReadAsStringAsync());
            await _factory.WithDbAsync(async db => Assert.False(await db.PostApplications.AnyAsync(a => a.PostId == postId && a.ProgrammerId == s.FreshProgrammer.Id)));
        }

        [Fact]
        public async Task T_D11_02_enforced_a_programmer_post_owner_cannot_accept_the_customer_owner_can()
        {
            var s = await Scenario();
            var (postId, applicationId) = await ProgrammerOwnedPost.CreateAsync(_factory, s);

            var programmer = await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{postId}/applications/{applicationId}/accept"), s.Programmer);

            Assert.Equal(HttpStatusCode.Forbidden, programmer.StatusCode);
            Assert.Equal("FORBIDDEN", await AdminRoutes.ErrorCode(programmer));
            await ProgrammerOwnedPost.AssertUnchangedAsync(_factory, postId, applicationId);

            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/applications/{s.ApplicationId}/accept"), s.Owner)).StatusCode);
        }

        [Fact]
        public async Task T_7B_22b_parallel_applications_leave_one_row_and_no_server_error()
        {
            var s = await Scenario();

            var responses = await Task.WhenAll(Enumerable.Range(0, 5).Select(_ =>
                Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/apply", new { proposal = "Parallel" }), s.OtherProgrammer)));

            Assert.Single(responses, r => r.StatusCode == HttpStatusCode.OK);
            Assert.All(responses, r => Assert.True(r.StatusCode is HttpStatusCode.OK or HttpStatusCode.BadRequest, $"{(int)r.StatusCode}"));
            await _factory.WithDbAsync(async db =>
                Assert.Equal(1, await db.PostApplications.CountAsync(a => a.PostId == s.PostId && a.ProgrammerId == s.OtherProgrammer.Id)));
        }

        [Fact]
        public async Task T_7B_23_accept_only_an_application_of_that_post()
        {
            var s = await Scenario();
            int otherPost = 0;
            await _factory.WithDbAsync(async db =>
            {
                var post = new Post { UserId = s.Owner.Id, Content = "Second post", Status = "Approved" };
                db.Posts.Add(post);
                await db.SaveChangesAsync();
                otherPost = post.Id;
            });

            var wrongPost = await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{otherPost}/applications/{s.ApplicationId}/accept"), s.Owner);

            Assert.Equal(HttpStatusCode.BadRequest, wrongPost.StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal("Pending", (await db.PostApplications.AsNoTracking().SingleAsync(a => a.Id == s.ApplicationId)).Status);
                Assert.False((await db.Posts.AsNoTracking().SingleAsync(p => p.Id == otherPost)).IsClosed);
            });

            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{s.PostId}/applications/{s.ApplicationId}/accept"), s.Owner)).StatusCode);
            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal("Accepted", (await db.PostApplications.AsNoTracking().SingleAsync(a => a.Id == s.ApplicationId)).Status);
                Assert.True((await db.Posts.AsNoTracking().SingleAsync(p => p.Id == s.PostId)).IsClosed);
            });
        }

        [Theory]
        [InlineData("upload", true)]
        [InlineData("delete", true)]
        [InlineData("form", true)]
        [InlineData("cv", false)]
        public async Task T_VF_01_certificate_changes_reset_verification_a_cv_does_not(string action, bool resets)
        {
            var s = await Scenario();
            var request = action switch
            {
                "upload" => WriteRoutes.File($"/api/ProgrammerProfile/{s.Programmer.Id}/certificate", "certificate", "new.pdf"),
                "delete" => WriteRoutes.Json(HttpMethod.Delete, $"/api/ProgrammerProfile/{s.Programmer.Id}/certificate"),
                "form" => FormWithCertificate(s.Programmer.Id),
                _ => WriteRoutes.File($"/api/ProgrammerProfile/{s.Programmer.Id}/cv", "cv", "new.pdf")
            };

            Assert.Equal(HttpStatusCode.OK, (await Send(request, s.Programmer)).StatusCode);

            await _factory.WithDbAsync(async db =>
                Assert.Equal(!resets, (await db.ProgrammerProfiles.AsNoTracking().SingleAsync(p => p.UserId == s.Programmer.Id)).IsVerified));
        }

        private static HttpRequestMessage FormWithCertificate(int userId)
        {
            var form = new MultipartFormDataContent();
            form.Add(new ByteArrayContent(TestFiles.Pdf), "Certificate", "new.pdf");
            return new HttpRequestMessage(HttpMethod.Put, $"/api/ProgrammerProfile/{userId}") { Content = form };
        }

        [Fact]
        public async Task T_7B_24_likes_and_comments_need_an_approved_post()
        {
            var s = await Scenario();
            int pendingPost = 0;
            await _factory.WithDbAsync(async db =>
            {
                var pending = new Post { UserId = s.Owner.Id, Content = "Not reviewed", Status = "Pending" };
                db.Posts.Add(pending);
                await db.SaveChangesAsync();
                pendingPost = pending.Id;
            });

            Assert.Equal(HttpStatusCode.BadRequest, (await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{pendingPost}/like", new { }), s.Other)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await Send(WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{pendingPost}/comments", new { content = "Hi" }), s.Other)).StatusCode);
        }

        [Fact]
        public async Task T_7B_25_suspended_accounts_keep_support_but_nothing_else()
        {
            var s = await Scenario();
            await _factory.WithDbAsync(async db => await db.Users.Where(u => u.Id == s.Owner.Id)
                .ExecuteUpdateAsync(u => u.SetProperty(x => x.Status, UserStatus.Suspended)));
            ((Services.Auth.SessionStateCache)_factory.Services.GetService(typeof(Services.Auth.SessionStateCache))!).Invalidate(s.Owner.Id);

            var like = await Send(WriteRoutes.Get("Posts.Like").Build(s), s.Owner);
            Assert.Equal(HttpStatusCode.Forbidden, like.StatusCode);
            Assert.Equal("ACCOUNT_SUSPENDED", await AdminRoutes.ErrorCode(like));

            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Get("Support.Send").Build(s), s.Owner)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await Send(WriteRoutes.Get("Support.MarkReplyRead").Build(s), s.Owner)).StatusCode);
        }

        [Fact]
        public async Task T_7B_26_support_limit_5_per_hour_and_subject_length()
        {
            var s = await Scenario();
            HttpRequestMessage Message(string subject = "Help") => WriteRoutes.Json(HttpMethod.Post, "/api/Support", new { subject, message = "Question" });

            Assert.Equal(HttpStatusCode.BadRequest, (await Send(Message(new string('x', 201)), s.Other)).StatusCode);

            for (var i = 0; i < 5; i++)
            {
                Assert.Equal(HttpStatusCode.OK, (await Send(Message(), s.Other)).StatusCode);
            }

            var limited = await Send(Message(), s.Other);

            Assert.Equal((HttpStatusCode)429, limited.StatusCode);
            Assert.Equal("RATE_LIMITED", await AdminRoutes.ErrorCode(limited));
            Assert.True(limited.Headers.Contains("Retry-After"));
            await _factory.WithDbAsync(async db => Assert.Equal(5, await db.SupportMessages.CountAsync(m => m.UserId == s.Other.Id)));
        }
    }

    public class WriteRouteFallbackTests : IClassFixture<DevFallbackApiFactory>
    {
        private readonly DevFallbackApiFactory _factory;
        private readonly HttpClient _client;

        public WriteRouteFallbackTests(DevFallbackApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Theory]
        [MemberData(nameof(WriteRoutes.Names), MemberType = typeof(WriteRoutes))]
        public async Task T_7B_04_tokenless_acts_with_the_client_id_and_is_logged_tokens_stay_enforced(string name)
        {
            var route = WriteRoutes.Get(name);
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            // A token is present → fully enforced, never the fallback.
            foreach (var caller in route.Refused(s))
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await WriteRoutes.SendAsync(_client, route.Build(s), caller.Token)).StatusCode);
            }

            Assert.Equal(HttpStatusCode.Unauthorized, (await WriteRoutes.SendAsync(_client, route.Build(s), "not-a-valid-token")).StatusCode);

            var marker = $"Auth.DevFallbackUsed {route.FallbackCase}";
            var before = _factory.Logs.Entries.Count(e => e.Message.Contains(marker));

            var tokenless = await WriteRoutes.SendAsync(_client, route.Build(s), null);

            Assert.Equal(HttpStatusCode.OK, tokenless.StatusCode);
            var logs = _factory.Logs.Entries.Where(e => e.Message.Contains("Auth.DevFallbackUsed")).ToList();
            Assert.True(logs.Count(e => e.Message.Contains(marker)) > before);
            // Case and route template only: no ids, emails or query strings.
            Assert.All(logs, e =>
            {
                Assert.DoesNotContain(route.Actor(s).Email, e.Message);
                Assert.DoesNotContain("?", e.Message);
                Assert.DoesNotContain($"/{route.Actor(s).Id}", e.Message);
            });
        }

        [Fact]
        public async Task T_D11_03_fallback_apply_to_a_programmer_owned_post_is_refused()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var (postId, _) = await ProgrammerOwnedPost.CreateAsync(_factory, s);

            var response = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, $"/api/Posts/{postId}/apply",
                new { programmerId = s.FreshProgrammer.Id, proposal = "I can build it" }), null);

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Contains("not open for applications", await response.Content.ReadAsStringAsync());
        }

        [Fact]
        public async Task T_D11_04_fallback_a_programmer_post_owner_cannot_accept_the_customer_owner_can()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var (postId, applicationId) = await ProgrammerOwnedPost.CreateAsync(_factory, s);

            var tokenless = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post,
                $"/api/Posts/{postId}/applications/{applicationId}/accept?requesterId={s.Programmer.Id}"), null);
            var withToken = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post,
                $"/api/Posts/{postId}/applications/{applicationId}/accept"), s.Programmer.Token);

            Assert.Equal(HttpStatusCode.Forbidden, tokenless.StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, withToken.StatusCode);
            await ProgrammerOwnedPost.AssertUnchangedAsync(_factory, postId, applicationId);

            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Get("Posts.Accept").Build(s), null)).StatusCode);
        }

        [Fact]
        public async Task T_7B_04b_tokenless_isAdmin_true_is_ignored()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            var post = await _client.DeleteAsync($"/api/Posts/{s.PostId}?userId={s.Other.Id}&isAdmin=true");
            var comment = await _client.DeleteAsync($"/api/Posts/comments/{s.CommentId}?userId={s.FreshCustomer.Id}&isAdmin=true");

            Assert.Equal(HttpStatusCode.Forbidden, post.StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, comment.StatusCode);
        }

        [Fact]
        public async Task T_7B_04c_a_token_wins_over_the_client_id_in_fallback_mode_too()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Get("Posts.Like").Build(s), s.Other.Token)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                Assert.True(await db.PostLikes.AnyAsync(l => l.PostId == s.PostId && l.UserId == s.Other.Id));
                Assert.False(await db.PostLikes.AnyAsync(l => l.PostId == s.PostId && l.UserId == s.Owner.Id));
            });
        }

        [Fact]
        public async Task T_7B_04d_one_log_line_per_request()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var template = "api/Posts/{id}/like";
            bool Mine(Infrastructure.CapturedLog e) => e.Message.Contains("Auth.DevFallbackUsed IdentityFromClient") && e.Message.Contains(template);
            var before = _factory.Logs.Entries.Count(Mine);

            await WriteRoutes.SendAsync(_client, WriteRoutes.Get("Posts.Like").Build(s), null);

            Assert.Equal(before + 1, _factory.Logs.Entries.Count(Mine));
        }
    }

    public class WriteRouteRemoteFallbackTests : IClassFixture<DevFallbackRemoteApiFactory>
    {
        private readonly DevFallbackRemoteApiFactory _factory;

        public WriteRouteRemoteFallbackTests(DevFallbackRemoteApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [MemberData(nameof(WriteRoutes.Names), MemberType = typeof(WriteRoutes))]
        public async Task T_7B_05_non_loopback_clients_never_get_the_fallback(string name)
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            var response = await WriteRoutes.SendAsync(client, WriteRoutes.Get(name).Build(s), null);

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
    }

    public class WriteRouteDevDefaultTests : IClassFixture<DevDefaultApiFactory>
    {
        private readonly DevDefaultApiFactory _factory;

        public WriteRouteDevDefaultTests(DevDefaultApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("Posts.Delete")]
        [InlineData("Posts.Create")]
        [InlineData("ProgrammerProfile.UploadCv")]
        [InlineData("Notifications.Read")]
        public async Task T_7B_05b_development_without_the_switch_is_enforced(string name)
        {
            var client = _factory.CreateClient();
            var s = await WriteRoutes.ScenarioAsync(_factory, client);

            Assert.Equal(HttpStatusCode.Unauthorized, (await WriteRoutes.SendAsync(client, WriteRoutes.Get(name).Build(s), null)).StatusCode);
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }
    }
}
