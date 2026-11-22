using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Web;
using DataBase;
using DataBase.Models;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Services.Files;

namespace DevLink.Api.Tests
{
    public static class TestFiles
    {
        public static readonly byte[] Png = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3 };
        public static readonly byte[] Jpeg = { 0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3 };
        public static readonly byte[] Webp = Encoding.ASCII.GetBytes("RIFF\u0001\u0002\u0003\u0004WEBPVP8 ");
        public static readonly byte[] Pdf = Encoding.ASCII.GetBytes("%PDF-1.7\nsynthetic document");
        public static readonly byte[] Gif = Encoding.ASCII.GetBytes("GIF89a....");
        public static readonly byte[] Svg = Encoding.UTF8.GetBytes("<svg xmlns=\"http://www.w3.org/2000/svg\"><script>alert(1)</script></svg>");
        public static readonly byte[] Html = Encoding.UTF8.GetBytes("<!doctype html><script>alert(1)</script>");
    }

    public sealed record WebSession(string Token, string Binding, string Refresh);

    public static class FileTestHelpers
    {
        public const string Password = "Matrix-Pass-42";

        private static string Cookie(HttpResponseMessage response, string name) =>
            response.Headers.GetValues("Set-Cookie").Single(v => v.StartsWith(name + "=", StringComparison.Ordinal))
                .Substring(name.Length + 1).Split(';')[0];

        public static async Task<WebSession> WebLoginAsync(SessionApiFactory factory, Account account, string userType, string? password = null)
        {
            using var client = CookieClient.Create(factory);
            var login = await client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = account.Email, password = password ?? Password, userType }));
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            var body = await CookieClient.Json(login);
            return new WebSession(body.GetProperty("accessToken").GetString()!, Cookie(login, DownloadBindingCookie.Name), Cookie(login, CookieClient.CookieName));
        }

        public static async Task<HttpResponseMessage> IssueAsync(HttpClient client, int programmerId, string kind, string? token)
        {
            return await WriteRoutes.SendAsync(client, WriteRoutes.Json(HttpMethod.Post, $"/api/ProgrammerProfile/{programmerId}/{kind}/link"), token);
        }

        public static async Task<string> LinkAsync(HttpClient client, int programmerId, string token, string kind = "cv")
        {
            var response = await IssueAsync(client, programmerId, kind, token);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return new Uri((await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("url").GetString()!).PathAndQuery;
        }

        public static Task<HttpResponseMessage> ConsumeAsync(HttpClient client, string link, string? binding)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, link);
            if (binding != null) request.Headers.Add("Cookie", $"{DownloadBindingCookie.Name}={binding}");
            return client.SendAsync(request);
        }

        public static HttpRequestMessage Upload(HttpMethod method, string path, string field, byte[] data, string fileName, string? declared = null)
        {
            var form = new MultipartFormDataContent();
            var content = new ByteArrayContent(data);
            if (declared != null) content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(declared);
            form.Add(content, field, fileName);
            return new HttpRequestMessage(method, path) { Content = form };
        }

        public static void AssertExpired(HttpResponseMessage response)
        {
            Assert.Equal(HttpStatusCode.Gone, response.StatusCode);
            Assert.Contains("no-store", response.Headers.CacheControl!.ToString());
        }
    }

    // ============================================================
    // T-DL-01…11: CV and certificate download links (M2_AUTH_DESIGN §5.1, §10.4).
    // ============================================================
    public class DownloadLinkTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        // A class fixture shares the clock: every test starts from real time, or tokens would look issued in the future.
        public DownloadLinkTests(SessionApiFactory factory)
        {
            factory.Time.Reset();
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private async Task<(WriteScenario S, WebSession Web, string Link)> OwnerLinkAsync()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var web = await FileTestHelpers.WebLoginAsync(_factory, s.Owner, "Customer");
            return (s, web, await FileTestHelpers.LinkAsync(_client, s.Programmer.Id, web.Token));
        }

        [Theory]
        [InlineData("cv")]
        [InlineData("certificate")]
        public async Task T_DL_01_only_the_programmer_an_admin_or_a_customer_they_applied_to_get_a_link(string kind)
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            foreach (var allowed in new[] { s.Programmer, s.Admin, s.Owner })
            {
                Assert.Equal(HttpStatusCode.OK, (await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, kind, allowed.Token)).StatusCode);
            }

            foreach (var refused in new[] { s.Other, s.OtherProgrammer })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, kind, refused.Token)).StatusCode);
            }

            Assert.Equal(HttpStatusCode.Unauthorized, (await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, kind, null)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == s.Owner.Id)).Status = UserStatus.Suspended;
                await db.SaveChangesAsync();
            });
            _factory.Services.GetRequiredService<Services.Auth.SessionStateCache>().Invalidate(s.Owner.Id);

            var suspended = await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, kind, s.Owner.Token);
            Assert.Equal(HttpStatusCode.Forbidden, suspended.StatusCode);
            Assert.Equal("ACCOUNT_SUSPENDED", await CookieClient.ErrorCode(suspended));
        }

        [Fact]
        public async Task T_DL_02_a_link_works_once()
        {
            var (_, web, link) = await OwnerLinkAsync();

            Assert.Equal(HttpStatusCode.OK, (await FileTestHelpers.ConsumeAsync(_client, link, web.Binding)).StatusCode);
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_03_two_parallel_uses_give_exactly_one_file()
        {
            var (_, web, link) = await OwnerLinkAsync();

            var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => FileTestHelpers.ConsumeAsync(_client, link, web.Binding)));

            Assert.Equal(1, results.Count(r => r.StatusCode == HttpStatusCode.OK));
            Assert.Equal(7, results.Count(r => r.StatusCode == HttpStatusCode.Gone));
        }

        [Fact]
        public async Task T_DL_04_a_link_lives_for_60_seconds()
        {
            var (_, web, link) = await OwnerLinkAsync();
            _factory.Time.Advance(TimeSpan.FromSeconds(55));
            Assert.Equal(HttpStatusCode.OK, (await FileTestHelpers.ConsumeAsync(_client, link, web.Binding)).StatusCode);

            _factory.Time.Reset();
            var (_, web2, link2) = await OwnerLinkAsync();
            _factory.Time.Advance(TimeSpan.FromSeconds(61));
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link2, web2.Binding));
        }

        [Fact]
        public async Task T_DL_05a_logout_kills_the_link()
        {
            var (_, web, link) = await OwnerLinkAsync();
            var logout = await _client.SendAsync(CookieClient.Post("/api/Auth/session/logout", cookie: web.Refresh));
            Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
            Assert.Contains(logout.Headers.GetValues("Set-Cookie"), v => v.StartsWith(DownloadBindingCookie.Name + "=;", StringComparison.Ordinal));

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_05b_logout_all_kills_the_link()
        {
            var (_, web, link) = await OwnerLinkAsync();
            Assert.Equal(HttpStatusCode.NoContent, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Post, "/api/Auth/logout-all"), web.Token)).StatusCode);

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_05c_a_password_reset_kills_the_link()
        {
            var (s, web, link) = await OwnerLinkAsync();
            var resetToken = await ApiTestHelpers.VerifyResetAsync(_client, _factory.Emails, s.Owner.Email);
            var reset = await _client.PostAsJsonAsync("/api/Auth/reset-password", new { email = s.Owner.Email, newPassword = "Fresh-Reset-Pass-71", resetToken });
            Assert.Equal(HttpStatusCode.OK, reset.StatusCode);

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_05d_refresh_token_reuse_kills_the_link()
        {
            var (_, web, link) = await OwnerLinkAsync();
            Assert.Equal(HttpStatusCode.OK, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: web.Refresh))).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: web.Refresh))).StatusCode);

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_05e_an_admin_revocation_kills_the_link()
        {
            var (s, web, link) = await OwnerLinkAsync();
            var admin = await ApiTestHelpers.AdminClientAsync(_factory);
            Assert.Equal(HttpStatusCode.OK, (await admin.PostAsJsonAsync($"/api/Admin/users/{s.Owner.Id}/suspend", new { reason = "Test" })).StatusCode);

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_06_the_link_only_works_in_the_browser_of_that_session()
        {
            var (s, web, link) = await OwnerLinkAsync();
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, null));

            var link2 = await FileTestHelpers.LinkAsync(_client, s.Programmer.Id, web.Token);
            var someoneElse = await FileTestHelpers.WebLoginAsync(_factory, s.Other, "Customer");
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link2, someoneElse.Binding));

            var link3 = await FileTestHelpers.LinkAsync(_client, s.Programmer.Id, web.Token);
            var sameUserOtherSession = await FileTestHelpers.WebLoginAsync(_factory, s.Owner, "Customer");
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link3, sameUserOtherSession.Binding));

            // A session with no binding (a client without the web header) can't consume links.
            var link4 = await FileTestHelpers.LinkAsync(_client, s.Programmer.Id, s.Owner.Token);
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link4, web.Binding));
        }

        [Fact]
        public async Task T_DL_07a_a_suspended_recipient_loses_the_link()
        {
            var (s, web, link) = await OwnerLinkAsync();
            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == s.Owner.Id)).Status = UserStatus.Suspended;
                await db.SaveChangesAsync();
            });

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_07b_a_recipient_who_lost_the_right_loses_the_link()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var web = await FileTestHelpers.WebLoginAsync(_factory, s.Admin, "Admin");
            var link = await FileTestHelpers.LinkAsync(_client, s.Programmer.Id, web.Token);
            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == s.Admin.Id)).UserType = "Customer";
                await db.SaveChangesAsync();
            });

            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));
        }

        [Fact]
        public async Task T_DL_08_replacing_or_deleting_the_file_kills_the_link()
        {
            var (s, web, link) = await OwnerLinkAsync();
            var replaced = await WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Post, $"/api/ProgrammerProfile/{s.Programmer.Id}/cv", "cv", TestFiles.Pdf, "new.pdf"), s.Programmer.Token);
            Assert.Equal(HttpStatusCode.OK, replaced.StatusCode);
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));

            var link2 = await FileTestHelpers.LinkAsync(_client, s.Programmer.Id, web.Token);
            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Delete, $"/api/ProgrammerProfile/{s.Programmer.Id}/cv"), s.Programmer.Token)).StatusCode);
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link2, web.Binding));
        }

        [Fact]
        public async Task T_DL_09_headers()
        {
            var (s, web, link) = await OwnerLinkAsync();
            var issued = await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, "cv", web.Token);
            Assert.True(issued.Headers.CacheControl!.NoStore);
            Assert.Equal(60, (await issued.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("expiresInSeconds").GetInt32());

            var file = await FileTestHelpers.ConsumeAsync(_client, link, web.Binding);

            Assert.Equal(HttpStatusCode.OK, file.StatusCode);
            Assert.True(file.Headers.CacheControl!.NoStore);
            Assert.True(file.Headers.CacheControl.Private);
            Assert.Equal("no-referrer", file.Headers.GetValues("Referrer-Policy").Single());
            Assert.Equal("nosniff", file.Headers.GetValues("X-Content-Type-Options").Single());
            Assert.Equal("attachment", file.Content.Headers.ContentDisposition!.DispositionType);
            Assert.Equal("application/pdf", file.Content.Headers.ContentType!.MediaType);
        }

        [Fact]
        public async Task T_DL_09b_a_stored_html_certificate_is_never_served_as_html()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            await _factory.WithDbAsync(async db =>
            {
                var profile = await db.ProgrammerProfiles.SingleAsync(p => p.UserId == s.Programmer.Id);
                profile.Certificate = TestFiles.Html;
                profile.CertificateType = "text/html";
                profile.CertificateName = "evil\".html";
                await db.SaveChangesAsync();
            });

            var direct = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, $"/api/ProgrammerProfile/{s.Programmer.Id}/certificate"), s.Owner.Token);

            Assert.Equal("application/octet-stream", direct.Content.Headers.ContentType!.MediaType);
            Assert.Equal("attachment", direct.Content.Headers.ContentDisposition!.DispositionType);
            Assert.EndsWith(".bin", direct.Content.Headers.ContentDisposition.FileName!.Trim('"'));
            Assert.True(direct.Headers.CacheControl!.NoStore);
        }

        [Fact]
        public async Task T_DL_10_tokens_and_cookies_are_never_logged()
        {
            var (s, web, link) = await OwnerLinkAsync();
            var token = HttpUtility.ParseQueryString(new Uri("https://x" + link).Query)["t"]!;
            Assert.Equal(HttpStatusCode.OK, (await FileTestHelpers.ConsumeAsync(_client, link, web.Binding)).StatusCode);
            FileTestHelpers.AssertExpired(await FileTestHelpers.ConsumeAsync(_client, link, web.Binding));

            Assert.DoesNotContain(token, _factory.Logs.AllText);
            Assert.DoesNotContain(web.Binding, _factory.Logs.AllText);

            await _factory.WithDbAsync(async db =>
            {
                var events = await db.SecurityEvents.AsNoTracking().ToListAsync();
                Assert.DoesNotContain(events, e => (e.Details ?? "").Contains(token) || (e.Details ?? "").Contains(web.Binding));

                var downloaded = events.Single(e => e.EventType == "Files.Downloaded" && e.UserId == s.Owner.Id);
                Assert.Contains($"cv:{s.Programmer.Id}", downloaded.Details);
                Assert.Null(downloaded.IpPrefix);
            });
        }

        [Fact]
        public async Task T_DL_11_issuing_links_is_limited()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            for (var i = 0; i < DownloadLinkStore.MaxPerTenMinutes; i++)
            {
                Assert.Equal(HttpStatusCode.OK, (await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, "cv", s.Programmer.Token)).StatusCode);
            }

            var refused = await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, "cv", s.Programmer.Token);
            Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
            Assert.Equal("RATE_LIMITED", await CookieClient.ErrorCode(refused));

            // Per user: someone else is not affected.
            Assert.Equal(HttpStatusCode.OK, (await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, "cv", s.Admin.Token)).StatusCode);
        }

        [Fact]
        public void T_DL_11b_the_daily_limit_applies_across_windows()
        {
            var store = new DownloadLinkStore();
            var now = new DateTime(2026, 11, 5, 0, 0, 0, DateTimeKind.Utc);
            for (var i = 0; i < DownloadLinkStore.MaxPerDay; i++)
            {
                Assert.True(store.TryCountIssue(1, now.AddMinutes(i)));
            }

            Assert.False(store.TryCountIssue(1, now.AddMinutes(100)));
            Assert.True(store.TryCountIssue(1, now.AddDays(1).AddMinutes(10)));
        }

        [Fact]
        public async Task T_LG_cookie_flags_only_web_sessions_get_the_binding_cookie()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var web = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = s.Owner.Email, password = FileTestHelpers.Password, userType = "Customer" }));
            var line = web.Headers.GetValues("Set-Cookie").Single(v => v.StartsWith(DownloadBindingCookie.Name + "=", StringComparison.Ordinal)).ToLowerInvariant();
            Assert.Contains("httponly", line);
            Assert.Contains("secure", line);
            Assert.Contains("samesite=strict", line);
            Assert.Contains("path=/api/files", line);

            var mobile = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = s.Owner.Email, password = FileTestHelpers.Password, userType = "Customer" }, client: "mobile", origin: null));
            Assert.False(mobile.Headers.Contains("Set-Cookie"));

            var legacy = await ApiTestHelpers.LoginAsync(_client, s.Owner.Email, FileTestHelpers.Password, "Customer");
            Assert.False(legacy.Headers.Contains("Set-Cookie"));

            await _factory.WithDbAsync(async db =>
            {
                var sessions = await db.AuthSessions.AsNoTracking().Where(x => x.UserId == s.Owner.Id).OrderByDescending(x => x.CreatedAt).Take(2).ToListAsync();
                Assert.All(sessions, x => Assert.Null(x.DownloadBindingHash));
            });
        }
    }

    // ============================================================
    // T-IM-01…07: signed image URLs (M2_AUTH_DESIGN §5.2, C5).
    // ============================================================
    public class SignedImageTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public SignedImageTests(SessionApiFactory factory)
        {
            factory.Time.Reset();
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<(WriteScenario S, int ImageId)> ScenarioWithImagesAsync(string postStatus = "Approved")
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            int imageId = 0;
            await _factory.WithDbAsync(async db =>
            {
                (await db.CustomerProfiles.SingleAsync(p => p.UserId == s.Owner.Id)).ProfileImage = TestFiles.Png;
                (await db.ProgrammerProfiles.SingleAsync(p => p.UserId == s.Programmer.Id)).ProfileImage = TestFiles.Jpeg;
                (await db.Posts.SingleAsync(p => p.Id == s.PostId)).Status = postStatus;
                var image = new PostImage { PostId = s.PostId, ImageData = TestFiles.Webp, ContentType = "image/webp" };
                db.PostImages.Add(image);
                await db.SaveChangesAsync();
                imageId = image.Id;
            });
            return (s, imageId);
        }

        private MediaUrlSigner Signer => _factory.Services.GetRequiredService<MediaUrlSigner>();

        private static long ExpOf(string url) => long.Parse(HttpUtility.ParseQueryString(url.Split('?')[1])["exp"]!);

        private async Task<JsonElement> FeedPostAsync(WriteScenario s, Account viewer)
        {
            var feed = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, $"/api/Posts/feed?userId={viewer.Id}&pageSize=50"), viewer.Token);
            Assert.Equal(HttpStatusCode.OK, feed.StatusCode);
            return (await feed.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == s.PostId);
        }

        private static string[] Routes(WriteScenario s, int imageId) => new[]
        {
            $"/api/Posts/image/{imageId}",
            $"/api/Posts/user/{s.Owner.Id}/avatar",
            $"/api/CustomerProfile/{s.Owner.Id}/image",
            $"/api/ProgrammerProfile/{s.Programmer.Id}/image"
        };

        [Fact]
        public async Task T_IM_01_no_signature_and_no_token_is_refused_on_all_four_routes()
        {
            var (s, imageId) = await ScenarioWithImagesAsync();

            foreach (var route in Routes(s, imageId))
            {
                var response = await _client.GetAsync(route);
                Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
                Assert.Equal("UNAUTHENTICATED", await CookieClient.ErrorCode(response));
                Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, route), s.Other.Token)).StatusCode);
            }
        }

        [Fact]
        public async Task T_IM_02_a_url_from_an_api_response_works_without_a_token_and_has_the_right_headers()
        {
            var (s, _) = await ScenarioWithImagesAsync();
            var post = await FeedPostAsync(s, s.Other);

            var avatar = await _client.GetAsync(post.GetProperty("avatarUrl").GetString());
            var image = await _client.GetAsync(post.GetProperty("images")[0].GetProperty("url").GetString());

            Assert.Equal(HttpStatusCode.OK, avatar.StatusCode);
            Assert.Equal("image/png", avatar.Content.Headers.ContentType!.MediaType);
            Assert.Equal(HttpStatusCode.OK, image.StatusCode);
            Assert.Equal("image/webp", image.Content.Headers.ContentType!.MediaType);
            foreach (var response in new[] { avatar, image })
            {
                Assert.True(response.Headers.CacheControl!.Private);
                Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
                Assert.False(response.Headers.CacheControl.Public);
            }
        }

        [Fact]
        public async Task T_IM_02b_the_same_signature_works_on_every_avatar_route_of_that_user()
        {
            var (s, _) = await ScenarioWithImagesAsync();
            var query = Signer.AvatarPath(s.Owner.Id).Split('?')[1];

            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/CustomerProfile/{s.Owner.Id}/image?{query}")).StatusCode);

            var otherUser = await _client.GetAsync($"/api/ProgrammerProfile/{s.Programmer.Id}/image?{query}");
            Assert.Equal(HttpStatusCode.Forbidden, otherUser.StatusCode);
        }

        [Fact]
        public async Task T_IM_03_07_a_url_is_valid_until_its_expiry_and_refused_after()
        {
            var (s, _) = await ScenarioWithImagesAsync();
            var url = Signer.AvatarPath(s.Owner.Id);
            var remaining = ExpOf(url) - _factory.Time.GetUtcNow().ToUnixTimeSeconds();
            Assert.InRange(remaining, 600, 1200);

            _factory.Time.Advance(TimeSpan.FromSeconds(remaining - 5));
            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(url)).StatusCode);

            _factory.Time.Advance(TimeSpan.FromSeconds(6));
            var expired = await _client.GetAsync(url);
            Assert.Equal(HttpStatusCode.Forbidden, expired.StatusCode);
            Assert.Equal("FORBIDDEN", await CookieClient.ErrorCode(expired));
        }

        [Fact]
        public async Task T_IM_04_a_tampered_url_is_refused()
        {
            var (s, imageId) = await ScenarioWithImagesAsync();
            var url = Signer.PostImagePath(imageId);
            var exp = ExpOf(url);
            var sig = HttpUtility.ParseQueryString(url.Split('?')[1])["sig"]!;
            var flipped = (sig[0] == 'A' ? 'B' : 'A') + sig[1..];
            var otherImage = Signer.AvatarPath(s.Owner.Id).Split('?')[1];

            foreach (var tampered in new[]
            {
                $"/api/Posts/image/{imageId}?exp={exp}&sig={flipped}",
                $"/api/Posts/image/{imageId}?exp={exp + 600}&sig={sig}",
                $"/api/Posts/image/{imageId + 1}?exp={exp}&sig={sig}",
                $"/api/Posts/image/{imageId}?{otherImage}",
                $"/api/Posts/image/{imageId}?exp={exp}",
                $"/api/Posts/image/{imageId}?sig={sig}",
                $"/api/Posts/image/{imageId}?exp=abc&sig={sig}",
                $"/api/Posts/image/{imageId}?exp={exp}&sig=%%%"
            })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync(tampered)).StatusCode);
            }

            // A bad signature is refused even with a valid token.
            Assert.Equal(HttpStatusCode.Forbidden, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, $"/api/Posts/image/{imageId}?exp={exp}&sig={flipped}"), s.Other.Token)).StatusCode);
        }

        [Fact]
        public async Task T_IM_05_suspended_or_deleted_authors_and_deleted_posts_give_404()
        {
            var (s, imageId) = await ScenarioWithImagesAsync();
            var avatar = Signer.AvatarPath(s.Owner.Id);
            var image = Signer.PostImagePath(imageId);
            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(avatar)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == s.Owner.Id)).Status = UserStatus.Suspended;
                await db.SaveChangesAsync();
            });
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync(avatar)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/CustomerProfile/{s.Owner.Id}/image?{avatar.Split('?')[1]}")).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync(image)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == s.Owner.Id)).Status = UserStatus.Active;
                (await db.Posts.SingleAsync(p => p.Id == s.PostId)).IsDeleted = true;
                await db.SaveChangesAsync();
            });
            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(avatar)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync(image)).StatusCode);
        }

        [Theory]
        [InlineData("Pending")]
        [InlineData("Rejected")]
        public async Task T_IM_06_an_unapproved_post_image_is_only_for_its_owner_and_admins(string status)
        {
            var (s, imageId) = await ScenarioWithImagesAsync(status);
            var route = $"/api/Posts/image/{imageId}";

            Assert.Equal(HttpStatusCode.NotFound, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, route), s.Other.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, route), s.Programmer.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, route), s.Owner.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, route), s.Admin.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync(route)).StatusCode);
        }

        [Fact]
        public async Task T_IM_06b_the_admin_pending_list_carries_working_signed_urls()
        {
            var (s, imageId) = await ScenarioWithImagesAsync("Pending");
            var pending = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, "/api/Posts/pending"), s.Admin.Token);
            var post = (await pending.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("posts").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == s.PostId);
            var url = post.GetProperty("images")[0].GetProperty("url").GetString()!;

            Assert.StartsWith($"/api/Posts/image/{imageId}?exp=", url);
            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(url)).StatusCode);
        }

        [Fact]
        public async Task T_IM_07_urls_are_identical_within_a_bucket_and_change_in_the_next()
        {
            var (s, _) = await ScenarioWithImagesAsync();

            // Away from a bucket edge, then two calls through the API.
            var intoBucket = _factory.Time.GetUtcNow().ToUnixTimeSeconds() % 600;
            if (intoBucket > 540)
            {
                _factory.Time.Advance(TimeSpan.FromSeconds(600 - intoBucket + 1));
            }

            var first = (await FeedPostAsync(s, s.Other)).GetProperty("avatarUrl").GetString()!;
            var second = (await FeedPostAsync(s, s.FreshCustomer)).GetProperty("avatarUrl").GetString()!;
            Assert.Equal(first, second);

            _factory.Time.Advance(TimeSpan.FromMinutes(10));
            var next = Signer.AvatarPath(s.Owner.Id);
            Assert.NotEqual(first, next);
            Assert.Equal(ExpOf(first) + 600, ExpOf(next));
        }

        [Fact]
        public async Task T_IM_07b_signatures_are_never_logged()
        {
            var (s, imageId) = await ScenarioWithImagesAsync();
            var url = Signer.PostImagePath(imageId);
            var sig = HttpUtility.ParseQueryString(url.Split('?')[1])["sig"]!;

            Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(url)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync(url + "x")).StatusCode);

            Assert.DoesNotContain(sig, _factory.Logs.AllText);
        }

        [Fact]
        public async Task T_IM_08_the_type_comes_from_the_bytes_and_other_stored_content_is_not_served()
        {
            var (s, imageId) = await ScenarioWithImagesAsync();
            await _factory.WithDbAsync(async db =>
            {
                var image = await db.PostImages.SingleAsync(i => i.Id == imageId);
                image.ContentType = "text/html";
                await db.SaveChangesAsync();
                (await db.CustomerProfiles.SingleAsync(p => p.UserId == s.Owner.Id)).ProfileImage = TestFiles.Svg;
                await db.SaveChangesAsync();
            });

            var image = await _client.GetAsync(Signer.PostImagePath(imageId));
            Assert.Equal("image/webp", image.Content.Headers.ContentType!.MediaType);
            Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync(Signer.AvatarPath(s.Owner.Id))).StatusCode);
        }

        [Fact]
        public async Task T_IM_09_every_response_that_shows_an_image_carries_a_signed_url()
        {
            var (s, _) = await ScenarioWithImagesAsync();
            await _factory.WithDbAsync(async db =>
            {
                (await db.ProgrammerProfiles.SingleAsync(p => p.UserId == s.Programmer.Id)).ProfileImage = TestFiles.Png;
                db.PostComments.Add(new PostComment { PostId = s.PostId, UserId = s.Programmer.Id, Content = "Interested" });
                await db.SaveChangesAsync();
            });

            async Task<JsonElement> Get(string path, Account caller)
            {
                var response = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, path), caller.Token);
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);
                return await response.Content.ReadFromJsonAsync<JsonElement>();
            }

            static void AssertSigned(string? url) => Assert.Contains("?exp=", url);

            AssertSigned((await Get("/api/Auth/me", s.Owner)).GetProperty("avatarUrl").GetString());
            AssertSigned((await Get($"/api/CustomerProfile/{s.Owner.Id}", s.Owner)).GetProperty("avatarUrl").GetString());
            AssertSigned((await Get($"/api/ProgrammerProfile/{s.Programmer.Id}", s.Owner)).GetProperty("avatarUrl").GetString());
            AssertSigned((await Get($"/api/Posts/profile/{s.Owner.Id}", s.Other)).GetProperty("avatarUrl").GetString());
            AssertSigned((await Get($"/api/Posts/{s.PostId}/applications?requesterId={s.Owner.Id}", s.Owner)).EnumerateArrayOrProperty("applications").First().GetProperty("programmerAvatarUrl").GetString());
            AssertSigned((await Get("/api/ProgrammerProfile/all", s.Admin)).EnumerateArray().First(p => p.GetProperty("userId").GetInt32() == s.Programmer.Id).GetProperty("avatarUrl").GetString());
            AssertSigned((await Get($"/api/Posts/{s.PostId}/comments", s.Owner)).EnumerateArrayOrProperty("comments").Single(c => c.GetProperty("userId").GetInt32() == s.Programmer.Id).GetProperty("avatarUrl").GetString());

            var post = await FeedPostAsync(s, s.Other);
            AssertSigned(post.GetProperty("authorImage").GetString());
        }

        [Fact]
        public async Task T_IM_10_no_file_issue_or_image_route_is_reachable_with_a_refresh_or_binding_cookie_alone()
        {
            var (s, imageId) = await ScenarioWithImagesAsync();
            var web = await FileTestHelpers.WebLoginAsync(_factory, s.Owner, "Customer");

            var request = new HttpRequestMessage(HttpMethod.Get, $"/api/Posts/image/{imageId}");
            request.Headers.Add("Cookie", $"{DownloadBindingCookie.Name}={web.Binding}");
            Assert.Equal(HttpStatusCode.Unauthorized, (await _client.SendAsync(request)).StatusCode);
        }
    }

    public static class JsonElementExtensions
    {
        public static IEnumerable<JsonElement> EnumerateArrayOrProperty(this JsonElement element, string property) =>
            element.ValueKind == JsonValueKind.Array ? element.EnumerateArray() : element.GetProperty(property).EnumerateArray();
    }

    // ---------------- T-SW-09: the development fallback for images and documents ----------------

    public class ImageFallbackTests : IClassFixture<DevFallbackApiFactory>
    {
        private readonly DevFallbackApiFactory _factory;
        private readonly HttpClient _client;

        public ImageFallbackTests(DevFallbackApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Fact]
        public async Task T_SW_09_unsigned_tokenless_images_work_and_are_logged_with_no_personal_data()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            int imageId = 0, pendingImage = 0;
            await _factory.WithDbAsync(async db =>
            {
                (await db.CustomerProfiles.SingleAsync(p => p.UserId == s.Owner.Id)).ProfileImage = TestFiles.Png;
                (await db.ProgrammerProfiles.SingleAsync(p => p.UserId == s.Programmer.Id)).ProfileImage = TestFiles.Jpeg;
                var image = new PostImage { PostId = s.PostId, ImageData = TestFiles.Png, ContentType = "image/png" };
                var pending = new Post { UserId = s.Owner.Id, Content = "Pending", Status = "Pending" };
                db.PostImages.Add(image);
                db.Posts.Add(pending);
                await db.SaveChangesAsync();
                var pendingImageRow = new PostImage { PostId = pending.Id, ImageData = TestFiles.Png, ContentType = "image/png" };
                db.PostImages.Add(pendingImageRow);
                await db.SaveChangesAsync();
                imageId = image.Id;
                pendingImage = pendingImageRow.Id;
            });

            foreach (var route in new[]
            {
                $"/api/Posts/image/{imageId}", $"/api/Posts/image/{pendingImage}", $"/api/Posts/user/{s.Owner.Id}/avatar",
                $"/api/CustomerProfile/{s.Owner.Id}/image", $"/api/ProgrammerProfile/{s.Programmer.Id}/image"
            })
            {
                Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync(route)).StatusCode);
            }

            var logged = _factory.Logs.Entries.Where(e => e.Message.Contains("Auth.DevFallbackUsed ImageWithoutSignature")).ToList();
            Assert.NotEmpty(logged);
            Assert.All(logged, e =>
            {
                Assert.DoesNotContain(s.Owner.Email, e.Message);
                Assert.DoesNotContain($"/{s.Owner.Id}/", e.Message);
                Assert.Contains("{", e.Message);
            });
        }

        [Fact]
        public async Task T_SW_09b_the_fallback_never_accepts_a_bad_signature_or_a_bad_token_and_responses_stay_unsigned_for_tokenless_callers()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            await _factory.WithDbAsync(async db =>
            {
                (await db.CustomerProfiles.SingleAsync(p => p.UserId == s.Owner.Id)).ProfileImage = TestFiles.Png;
                await db.SaveChangesAsync();
            });
            var route = $"/api/Posts/user/{s.Owner.Id}/avatar";

            Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync($"{route}?exp=1&sig=AAAA")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, route), "not-a-valid-token")).StatusCode);

            var profile = await (await _client.GetAsync($"/api/Posts/profile/{s.Owner.Id}")).Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(route, profile.GetProperty("avatarUrl").GetString());
        }

        [Fact]
        public async Task T_SW_08_tokenless_documents_still_work_but_download_and_issuing_a_link_needs_a_token()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            var direct = await _client.GetAsync($"/api/ProgrammerProfile/{s.Programmer.Id}/cv");
            Assert.Equal(HttpStatusCode.OK, direct.StatusCode);
            Assert.Equal("attachment", direct.Content.Headers.ContentDisposition!.DispositionType);

            Assert.Equal(HttpStatusCode.Unauthorized, (await FileTestHelpers.IssueAsync(_client, s.Programmer.Id, "cv", null)).StatusCode);
            Assert.Equal(HttpStatusCode.Gone, (await _client.GetAsync("/api/Files/download?t=unknown")).StatusCode);
        }
    }

    public class ImageRemoteFallbackTests : IClassFixture<DevFallbackRemoteApiFactory>
    {
        private readonly DevFallbackRemoteApiFactory _factory;

        public ImageRemoteFallbackTests(DevFallbackRemoteApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("/api/Posts/image/1")]
        [InlineData("/api/Posts/user/1/avatar")]
        [InlineData("/api/CustomerProfile/1/image")]
        [InlineData("/api/ProgrammerProfile/1/image")]
        public async Task T_SW_09c_non_loopback_clients_never_get_the_image_fallback(string route)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await _factory.CreateClient().GetAsync(route)).StatusCode);
        }
    }

    public class ImageDevDefaultTests : IClassFixture<DevDefaultApiFactory>
    {
        private readonly DevDefaultApiFactory _factory;

        public ImageDevDefaultTests(DevDefaultApiFactory factory)
        {
            _factory = factory;
        }

        [Theory]
        [InlineData("/api/Posts/image/1")]
        [InlineData("/api/Posts/user/1/avatar")]
        public async Task T_SW_09d_development_without_the_switch_is_enforced(string route)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await _factory.CreateClient().GetAsync(route)).StatusCode);
            Assert.DoesNotContain(_factory.Logs.Entries, e => e.Message.Contains("Auth.DevFallbackUsed"));
        }
    }

    // ---------------- Upload validation (M2.8) ----------------

    public class UploadValidationTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public UploadValidationTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<HttpResponseMessage> Put(string path, string field, byte[] data, string name, Account caller, string? declared = null) =>
            WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Put, path, field, data, name, declared), caller.Token);

        public static IEnumerable<object[]> BadImages => new[]
        {
            new object[] { TestFiles.Svg, "evil.svg", "image/svg+xml" },
            new object[] { TestFiles.Svg, "evil.png", "image/png" },
            new object[] { TestFiles.Html, "evil.jpg", "image/jpeg" },
            new object[] { TestFiles.Html, "evil.html", "text/html" },
            new object[] { TestFiles.Gif, "anim.gif", "image/gif" },
            new object[] { TestFiles.Pdf, "doc.png", "image/png" },
            new object[] { TestFiles.Png, "real-png.svg", "image/png" },
            new object[] { TestFiles.Png, "real-png.html", "image/png" },
            new object[] { new byte[] { 0xFF }, "short.jpg", "image/jpeg" }
        };

        [Theory]
        [MemberData(nameof(BadImages))]
        public async Task T_UP_01_avatars_refuse_anything_that_is_not_an_allowed_image(byte[] data, string name, string declared)
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            await _factory.WithDbAsync(async db =>
            {
                db.CustomerProfiles.Add(new CustomerProfile { UserId = s.Other.Id, Nickname = "Other", Country = "PS", City = "Nablus", PhoneNumber = "0590000009" });
                await db.SaveChangesAsync();
            });

            Assert.Equal(HttpStatusCode.BadRequest, (await Put($"/api/CustomerProfile/{s.Other.Id}", "ProfileImage", data, name, s.Other, declared)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await Put($"/api/ProgrammerProfile/{s.Programmer.Id}", "ProfileImage", data, name, s.Programmer, declared)).StatusCode);

            var form = FileTestHelpers.Upload(HttpMethod.Post, "/api/Posts", "Images", data, name, declared);
            Assert.Equal(HttpStatusCode.BadRequest, (await WriteRoutes.SendAsync(_client, form, s.Other.Token)).StatusCode);
        }

        [Theory]
        [InlineData("jpg")]
        [InlineData("png")]
        [InlineData("webp")]
        public async Task T_UP_02_allowed_images_are_stored_with_the_type_of_their_bytes_whatever_the_client_says(string kind)
        {
            var (data, type) = kind switch
            {
                "jpg" => (TestFiles.Jpeg, "image/jpeg"),
                "png" => (TestFiles.Png, "image/png"),
                _ => (TestFiles.Webp, "image/webp")
            };
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            Assert.Equal(HttpStatusCode.OK, (await Put($"/api/ProgrammerProfile/{s.Programmer.Id}", "ProfileImage", data, "blob", s.Programmer, "text/html")).StatusCode);

            await _factory.WithDbAsync(async db =>
                Assert.Equal(type, (await db.ProgrammerProfiles.AsNoTracking().SingleAsync(p => p.UserId == s.Programmer.Id)).ImageContentType));
        }

        [Fact]
        public async Task T_UP_03_size_limits()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var tooBigAvatar = TestFiles.Png.Concat(new byte[UploadValidator.MaxAvatarBytes]).ToArray();
            var tooBigDocument = TestFiles.Pdf.Concat(new byte[UploadValidator.MaxDocumentBytes]).ToArray();
            var tooBigPostImage = TestFiles.Png.Concat(new byte[UploadValidator.MaxPostImageBytes]).ToArray();

            Assert.Equal(HttpStatusCode.BadRequest, (await Put($"/api/ProgrammerProfile/{s.Programmer.Id}", "ProfileImage", tooBigAvatar, "a.png", s.Programmer)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Post, $"/api/ProgrammerProfile/{s.Programmer.Id}/cv", "cv", tooBigDocument, "a.pdf"), s.Programmer.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Post, $"/api/ProgrammerProfile/{s.Programmer.Id}/certificate", "certificate", tooBigDocument, "a.pdf"), s.Programmer.Token)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Post, "/api/Posts", "Images", tooBigPostImage, "a.png"), s.Owner.Token)).StatusCode);
        }

        public static IEnumerable<object[]> BadDocuments => new[]
        {
            new object[] { "cv", TestFiles.Html, "cv.pdf" },
            new object[] { "cv", TestFiles.Png, "cv.pdf" },
            new object[] { "cv", TestFiles.Pdf, "cv.html" },
            new object[] { "certificate", TestFiles.Html, "cert.pdf" },
            new object[] { "certificate", TestFiles.Svg, "cert.png" },
            new object[] { "certificate", TestFiles.Pdf, "cert.svg" },
            new object[] { "certificate", TestFiles.Png, "cert.pdf" },
            new object[] { "certificate", TestFiles.Webp, "cert.png" }
        };

        [Theory]
        [MemberData(nameof(BadDocuments))]
        public async Task T_UP_04_documents_refuse_wrong_content_and_nothing_changes(string kind, byte[] data, string name)
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);
            var upload = FileTestHelpers.Upload(HttpMethod.Post, $"/api/ProgrammerProfile/{s.Programmer.Id}/{kind}", kind, data, name);

            Assert.Equal(HttpStatusCode.BadRequest, (await WriteRoutes.SendAsync(_client, upload, s.Programmer.Token)).StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var profile = await db.ProgrammerProfiles.AsNoTracking().SingleAsync(p => p.UserId == s.Programmer.Id);
                Assert.Equal(new byte[] { 1 }, kind == "cv" ? profile.CV : profile.Certificate);
            });
        }

        [Fact]
        public async Task T_UP_05_valid_documents_are_stored_with_a_sanitized_name_and_a_type_from_the_bytes()
        {
            var s = await WriteRoutes.ScenarioAsync(_factory, _client);

            var cv = await WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Post, $"/api/ProgrammerProfile/{s.Programmer.Id}/cv", "cv", TestFiles.Pdf, "..\\..\\evil<name>.pdf"), s.Programmer.Token);
            var certificate = await WriteRoutes.SendAsync(_client, FileTestHelpers.Upload(HttpMethod.Post, $"/api/ProgrammerProfile/{s.Programmer.Id}/certificate", "certificate", TestFiles.Png, "شهادة.png", "text/html"), s.Programmer.Token);
            Assert.Equal(HttpStatusCode.OK, cv.StatusCode);
            Assert.Equal(HttpStatusCode.OK, certificate.StatusCode);

            await _factory.WithDbAsync(async db =>
            {
                var profile = await db.ProgrammerProfiles.AsNoTracking().SingleAsync(p => p.UserId == s.Programmer.Id);
                Assert.Equal("evilname.pdf", profile.CVName);
                Assert.Equal("شهادة.png", profile.CertificateName);
                Assert.Equal("image/png", profile.CertificateType);
            });

            var served = await WriteRoutes.SendAsync(_client, WriteRoutes.Json(HttpMethod.Get, $"/api/ProgrammerProfile/{s.Programmer.Id}/certificate"), s.Programmer.Token);
            Assert.Equal("image/png", served.Content.Headers.ContentType!.MediaType);
            Assert.Equal("شهادة.png", served.Content.Headers.ContentDisposition!.FileNameStar);
        }

        [Theory]
        [InlineData("cv.pdf", "cv.pdf")]
        [InlineData("../../etc/passwd.pdf", "passwd.pdf")]
        [InlineData("C:\\temp\\my cv.pdf", "my cv.pdf")]
        [InlineData("a\"b;c%d\r\ne.pdf", "abcde.pdf")]
        [InlineData("\u202Efdp.exe", "fdp.exe")]
        [InlineData("...", "fallback.pdf")]
        [InlineData("", "fallback.pdf")]
        [InlineData(null, "fallback.pdf")]
        public void T_UP_06_file_names_are_sanitized(string? input, string expected)
        {
            Assert.Equal(expected, UploadValidator.SafeFileName(input, "fallback.pdf"));
        }

        [Fact]
        public void T_UP_07_long_names_keep_their_extension_and_the_served_name_matches_the_type()
        {
            var name = UploadValidator.SafeFileName(new string('a', 300) + ".pdf", "x");
            Assert.Equal(UploadValidator.MaxFileNameLength, name.Length);
            Assert.EndsWith(".pdf", name);

            Assert.Equal("cv.pdf", UploadValidator.DownloadName("cv.pdf", UploadValidator.Pdf));
            Assert.Equal("page.pdf", UploadValidator.DownloadName("page.html", UploadValidator.Pdf));
            Assert.Equal("photo.jpeg", UploadValidator.DownloadName("photo.jpeg", UploadValidator.Jpeg));
            Assert.Equal("document.bin", UploadValidator.DownloadName(null, "application/octet-stream"));
        }

        [Fact]
        public void T_UP_08_type_detection_uses_only_the_first_bytes()
        {
            Assert.Equal(UploadValidator.Png, UploadValidator.SniffImage(TestFiles.Png));
            Assert.Equal(UploadValidator.Jpeg, UploadValidator.SniffImage(TestFiles.Jpeg));
            Assert.Equal(UploadValidator.Webp, UploadValidator.SniffImage(TestFiles.Webp));
            Assert.Null(UploadValidator.SniffImage(TestFiles.Svg));
            Assert.Null(UploadValidator.SniffImage(TestFiles.Html));
            Assert.Null(UploadValidator.SniffImage(TestFiles.Gif));
            Assert.Null(UploadValidator.SniffImage(ReadOnlySpan<byte>.Empty));
            Assert.Null(UploadValidator.SniffCertificate(TestFiles.Webp));
            Assert.Equal(UploadValidator.Pdf, UploadValidator.SniffCertificate(TestFiles.Pdf));
        }
    }

    // ---------------- T-JWT-06: Security:MediaUrlKey at start-up ----------------

    public class MediaKeyStartupTests
    {
        [Theory]
        [InlineData(null, "Security:MediaUrlKey is not configured")]
        [InlineData("", "Security:MediaUrlKey is not configured")]
        [InlineData("SET-WITH-DOTNET-USER-SECRETS", "still contains the placeholder")]
        [InlineData("not base64!", "is not valid base64")]
        [InlineData("c2hvcnQ=", "Security:MediaUrlKey is too short")]
        public void T_KEY_02_a_missing_or_weak_media_key_stops_startup(string? value, string expected)
        {
            using var factory = new HostOnlyApiFactory(overrides: new Dictionary<string, string?> { ["Security:MediaUrlKey"] = value });

            Assert.Contains(expected, factory.StartupFailure());
        }
    }
}
