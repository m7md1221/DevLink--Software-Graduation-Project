using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace DevLink.Api.Tests.Infrastructure
{
    public static class ApiTestHelpers
    {
        public static string UniqueEmail(string prefix = "user") =>
            $"{prefix}.{Guid.NewGuid():N}@example.test";

        // Runs the real registration flow: send-code -> verify-code (proof token) -> signup.
        public static async Task<int> RegisterAsync(
            HttpClient client,
            CapturingEmailSender emails,
            string email,
            string password,
            string userType)
        {
            var signupToken = await VerifyEmailAsync(client, emails, email);

            var signup = await client.PostAsJsonAsync("/api/Auth/signup", new { email, password, userType, signupToken });
            Assert.Equal(HttpStatusCode.OK, signup.StatusCode);

            var body = await signup.Content.ReadFromJsonAsync<JsonElement>();
            return body.GetProperty("userId").GetInt32();
        }

        // send-code -> verify-code; returns the signupToken.
        public static async Task<string> VerifyEmailAsync(HttpClient client, CapturingEmailSender emails, string email)
        {
            var before = emails.CodeCount(email);
            var send = await client.PostAsJsonAsync("/api/Auth/send-code", new { email });
            Assert.Equal(HttpStatusCode.OK, send.StatusCode);

            var code = emails.LatestCodeFor(email, before);

            var verify = await client.PostAsJsonAsync("/api/Auth/verify-code", new { email, code });
            Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
            return (await verify.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("signupToken").GetString()!;
        }

        // send-reset-code -> verify-reset-code; returns the resetToken.
        public static async Task<string> VerifyResetAsync(HttpClient client, CapturingEmailSender emails, string email)
        {
            var before = emails.CodeCount(email);
            var send = await client.PostAsJsonAsync("/api/Auth/send-reset-code", new { email });
            Assert.Equal(HttpStatusCode.OK, send.StatusCode);

            var code = emails.LatestCodeFor(email, before);

            var verify = await client.PostAsJsonAsync("/api/Auth/verify-reset-code", new { email, code });
            Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
            return (await verify.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("resetToken").GetString()!;
        }

        public static Task<HttpResponseMessage> LoginAsync(
            HttpClient client,
            string email,
            string password,
            string userType) =>
            client.PostAsJsonAsync("/api/Auth/login", new { email, password, userType });

        public const string TestAdminPassword = "Admin-Pass-91x";

        // M2.7a: admin routes need an Admin token. Admins can't be created through the API (Q10), so the
        // test admin is inserted directly and signs in through the normal login.
        public static async Task<(int Id, string Token)> AdminTokenAsync(DevLinkApiFactory factory, HttpClient client)
        {
            var email = UniqueEmail("test-admin");
            int id = 0;
            await factory.WithDbAsync(async db =>
            {
                var admin = new DataBase.User { Email = email, PasswordHash = TestAdminPassword, UserType = "Admin" };
                db.Users.Add(admin);
                await db.SaveChangesAsync();
                id = admin.Id;
            });

            var login = await LoginAsync(client, email, TestAdminPassword, "Admin");
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            return (id, (await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("accessToken").GetString()!);
        }

        // A client that sends an Admin access token with every request.
        public static async Task<HttpClient> AdminClientAsync(DevLinkApiFactory factory)
        {
            var client = factory.CreateClient();
            var (_, token) = await AdminTokenAsync(factory, client);
            client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
            return client;
        }
    }
}
