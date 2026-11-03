using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace DevLink.Api.Tests.Infrastructure
{
    public static class ApiTestHelpers
    {
        public static string UniqueEmail(string prefix = "user") =>
            $"{prefix}.{Guid.NewGuid():N}@example.test";

        // Runs the real registration flow: send-code -> verify-code -> signup.
        public static async Task<int> RegisterAsync(
            HttpClient client,
            CapturingEmailSender emails,
            string email,
            string password,
            string userType)
        {
            var send = await client.PostAsJsonAsync("/api/Auth/send-code", new { email });
            Assert.Equal(HttpStatusCode.OK, send.StatusCode);

            var code = emails.LatestCodeFor(email);

            var verify = await client.PostAsJsonAsync("/api/Auth/verify-code", new { email, code });
            Assert.Equal(HttpStatusCode.OK, verify.StatusCode);

            var signup = await client.PostAsJsonAsync("/api/Auth/signup", new { email, password, userType });
            Assert.Equal(HttpStatusCode.OK, signup.StatusCode);

            var body = await signup.Content.ReadFromJsonAsync<JsonElement>();
            return body.GetProperty("userId").GetInt32();
        }

        public static Task<HttpResponseMessage> LoginAsync(
            HttpClient client,
            string email,
            string password,
            string userType) =>
            client.PostAsJsonAsync("/api/Auth/login", new { email, password, userType });
    }
}
