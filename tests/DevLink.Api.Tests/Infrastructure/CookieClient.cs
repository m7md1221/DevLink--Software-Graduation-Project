using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DevLink.Api.Tests.Infrastructure
{
    // Explicit cookie handling for refresh-session tests: cookies are read from Set-Cookie and sent
    // by hand, so flags can be asserted and an old cookie value can be replayed on purpose.
    public static class CookieClient
    {
        public const string CookieName = "devlink_rt";

        public static HttpClient Create(WebApplicationFactory<Program> factory) =>
            factory.CreateClient(new WebApplicationFactoryClientOptions
            {
                BaseAddress = new Uri("https://localhost"),
                HandleCookies = false,
                AllowAutoRedirect = false
            });

        public static HttpRequestMessage Post(
            string path,
            object? body = null,
            string? cookie = null,
            string? client = "web",
            string? origin = TestSecuritySettings.Origin,
            string contentType = "application/json",
            string? bearer = null,
            string? referer = null,
            string? fetchSite = null)
        {
            var request = new HttpRequestMessage(HttpMethod.Post, path)
            {
                Content = contentType == "application/json"
                    ? JsonContent.Create(body ?? new { })
                    : new StringContent(JsonSerializer.Serialize(body ?? new { }), Encoding.UTF8, contentType)
            };
            if (cookie != null) request.Headers.Add("Cookie", $"{CookieName}={cookie}");
            if (client != null) request.Headers.Add("X-DevLink-Client", client);
            if (origin != null) request.Headers.Add("Origin", origin);
            if (referer != null) request.Headers.Add("Referer", referer);
            if (fetchSite != null) request.Headers.Add("Sec-Fetch-Site", fetchSite);
            if (bearer != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer);
            return request;
        }

        public static string? SetCookieLine(HttpResponseMessage response) =>
            response.Headers.TryGetValues("Set-Cookie", out var values)
                ? values.FirstOrDefault(v => v.StartsWith(CookieName + "=", StringComparison.Ordinal))
                : null;

        // The cookie value set by the response, or null if it sets none (or deletes it).
        public static string? CookieValue(HttpResponseMessage response)
        {
            var line = SetCookieLine(response);
            if (line == null) return null;
            var value = line.Substring(CookieName.Length + 1).Split(';')[0];
            return value.Length == 0 ? null : value;
        }

        public static bool DeletesCookie(HttpResponseMessage response)
        {
            var line = SetCookieLine(response);
            return line != null && line.StartsWith(CookieName + "=;", StringComparison.Ordinal) &&
                   line.Contains("expires=Thu, 01 Jan 1970", StringComparison.OrdinalIgnoreCase);
        }

        public static async Task<JsonElement> Json(HttpResponseMessage response) =>
            JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

        public static async Task<string?> ErrorCode(HttpResponseMessage response)
        {
            var text = await response.Content.ReadAsStringAsync();
            if (string.IsNullOrWhiteSpace(text)) return null;
            return JsonDocument.Parse(text).RootElement.TryGetProperty("errorCode", out var code) ? code.GetString() : null;
        }
    }
}
