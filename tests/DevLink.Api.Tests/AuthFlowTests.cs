using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DevLink.Api.Tests.Infrastructure;

namespace DevLink.Api.Tests
{
    // Characterization tests: lock in the current, working behaviour of the
    // registration and login endpoints before the security changes.
    public class AuthFlowTests : IClassFixture<DevLinkApiFactory>
    {
        private readonly DevLinkApiFactory _factory;
        private readonly HttpClient _client;

        public AuthFlowTests(DevLinkApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        [Fact]
        public async Task Register_then_login_with_correct_password_succeeds()
        {
            var email = ApiTestHelpers.UniqueEmail("customer");

            var userId = await ApiTestHelpers.RegisterAsync(
                _client, _factory.Emails, email, "Secret123", "Customer");

            var login = await ApiTestHelpers.LoginAsync(_client, email, "Secret123", "Customer");

            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            var body = await login.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(userId, body.GetProperty("userId").GetInt32());
            Assert.Equal("Customer", body.GetProperty("userType").GetString());
        }

        [Fact]
        public async Task Login_with_wrong_password_returns_401()
        {
            var email = ApiTestHelpers.UniqueEmail("programmer");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Programmer");

            var login = await ApiTestHelpers.LoginAsync(_client, email, "Wrong-password", "Programmer");

            Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
        }

        [Fact]
        public async Task Signup_without_verified_email_is_rejected()
        {
            var signup = await _client.PostAsJsonAsync("/api/Auth/signup", new
            {
                email = ApiTestHelpers.UniqueEmail("unverified"),
                password = "Secret123",
                userType = "Customer"
            });

            Assert.Equal(HttpStatusCode.BadRequest, signup.StatusCode);
        }

        [Fact]
        public async Task Verify_code_with_wrong_code_is_rejected()
        {
            var email = ApiTestHelpers.UniqueEmail("wrongcode");
            await _client.PostAsJsonAsync("/api/Auth/send-code", new { email });

            var verify = await _client.PostAsJsonAsync("/api/Auth/verify-code", new { email, code = "000000x" });

            Assert.Equal(HttpStatusCode.BadRequest, verify.StatusCode);
        }

        [Fact]
        public async Task Feed_without_userId_returns_400()
        {
            var response = await _client.GetAsync("/api/Posts/feed");

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }
    }
}
