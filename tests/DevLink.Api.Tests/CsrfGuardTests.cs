using System.Net;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // T-CS-01…06: the CSRF guard on endpoints that read or set the refresh cookie (M2_AUTH_DESIGN §4.2).
    public class CsrfGuardTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public CsrfGuardTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private async Task<string> CookieAsync()
        {
            var email = ApiTestHelpers.UniqueEmail("csrf");
            await ApiTestHelpers.RegisterAsync(_factory.CreateClient(), _factory.Emails, email, "Secret123", "Customer");
            var response = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }));
            return CookieClient.CookieValue(response)!;
        }

        private async Task AssertRejected(HttpRequestMessage request)
        {
            var response = await _client.SendAsync(request);
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            Assert.Equal("CSRF_FAILED", await CookieClient.ErrorCode(response));
            Assert.Null(CookieClient.CookieValue(response));
        }

        [Fact]
        public async Task T_CS_01_missing_origin_and_referer_is_rejected()
        {
            await AssertRejected(CookieClient.Post("/api/Auth/session/refresh", cookie: await CookieAsync(), origin: null));
        }

        [Theory]
        [InlineData("https://evil.example")]
        [InlineData("http://127.0.0.1:5200")]
        [InlineData("https://app.devlink.test.evil.example")]
        [InlineData("null")]
        public async Task T_CS_02_03_unlisted_or_null_origin_is_rejected(string origin)
        {
            await AssertRejected(CookieClient.Post("/api/Auth/session/refresh", cookie: await CookieAsync(), origin: origin));
        }

        [Fact]
        public async Task T_CS_04_missing_client_header_is_rejected()
        {
            await AssertRejected(CookieClient.Post("/api/Auth/session/refresh", cookie: await CookieAsync(), client: null));
        }

        [Theory]
        [InlineData("text/plain")]
        [InlineData("application/x-www-form-urlencoded")]
        public async Task T_CS_05_non_json_content_type_is_rejected(string contentType)
        {
            var cookie = await CookieAsync();

            // Rejected before the cookie is read: 415 from model binding (or 403 from the guard).
            var response = await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie, contentType: contentType));
            Assert.Contains(response.StatusCode, new[] { HttpStatusCode.UnsupportedMediaType, HttpStatusCode.Forbidden });
            Assert.Null(CookieClient.CookieValue(response));

            // The token was not consumed: a proper request still rotates it.
            Assert.Equal(HttpStatusCode.OK, (await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie))).StatusCode);
        }

        [Fact]
        public async Task T_CS_06_cross_site_fetch_metadata_is_rejected_and_referer_fallback_works()
        {
            var cookie = await CookieAsync();
            await AssertRejected(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie, fetchSite: "cross-site"));
            await AssertRejected(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie, origin: null, referer: "https://evil.example/page"));

            // No Origin but an allowlisted Referer, same-site fetch: accepted.
            var ok = await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie, origin: null,
                referer: TestSecuritySettings.Origin + "/some/page", fetchSite: "same-site"));
            Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        }

        [Fact]
        public async Task T_CS_06_cookie_issuing_login_and_logout_are_guarded_too_and_rejections_are_audited()
        {
            var email = ApiTestHelpers.UniqueEmail("csrf-login");
            await ApiTestHelpers.RegisterAsync(_factory.CreateClient(), _factory.Emails, email, "Secret123", "Customer");

            await AssertRejected(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }, origin: "https://evil.example"));
            await AssertRejected(CookieClient.Post("/api/Auth/session/logout", cookie: await CookieAsync(), origin: "https://evil.example"));

            await _factory.WithDbAsync(async db =>
            {
                var rejected = await db.SecurityEvents.AsNoTracking().Where(e => e.EventType == "Auth.CsrfRejected").ToListAsync();
                Assert.NotEmpty(rejected);
                Assert.All(rejected, e => Assert.Equal(SessionApiFactory.ClientIpPrefix, e.IpPrefix));
            });
        }
    }
}
