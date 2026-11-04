using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DevLink.Api.Tests.Infrastructure;
using Services;

namespace DevLink.Api.Tests
{
    // An email sender that fails unexpectedly, to force an unhandled exception.
    public class ThrowingEmailSender : IEmailSender
    {
        public bool SendEmail(string toEmail, string subject, string body, string senderName = "DevLink") =>
            throw new InvalidOperationException("Simulated SMTP failure: SELECT secret FROM somewhere");

        public Task<bool> SendEmailAsync(string toEmail, string subject, string body, string senderName = "DevLink") =>
            throw new InvalidOperationException("Simulated SMTP failure");
    }

    public class ThrowingEmailApiFactory : DevLinkApiFactory
    {
        public ThrowingEmailApiFactory()
        {
            EmailSenderOverride = new ThrowingEmailSender();
        }
    }

    public class ErrorHandlingTests : IClassFixture<ThrowingEmailApiFactory>
    {
        private readonly HttpClient _client;

        public ErrorHandlingTests(ThrowingEmailApiFactory factory)
        {
            _client = factory.CreateClient();
        }

        // Since M2.5a email is sent from a background queue, so a failing sender no longer fails the
        // request; the unhandled exception now comes from a test-only route.
        [Fact]
        public async Task Unhandled_exception_returns_sanitized_problem_details()
        {
            var response = await _client.GetAsync("/__tests/auth/boom");

            Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);

            var raw = await response.Content.ReadAsStringAsync();
            var body = JsonDocument.Parse(raw).RootElement;

            Assert.Equal(500, body.GetProperty("status").GetInt32());
            Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("traceId").GetString()));
            Assert.DoesNotContain("Exception", raw);
            Assert.DoesNotContain("SELECT", raw);
            Assert.DoesNotContain(" at ", raw);
        }

        [Fact]
        public async Task Handled_validation_errors_keep_their_existing_shape()
        {
            var response = await _client.GetAsync("/api/Posts/feed");

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("userId is required", body.GetProperty("message").GetString());
        }
    }
}
