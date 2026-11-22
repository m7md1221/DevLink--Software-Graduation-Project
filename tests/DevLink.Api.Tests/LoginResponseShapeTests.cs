using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DevLink.Api.Tests.Infrastructure;

namespace DevLink.Api.Tests
{
    // T-LG-BC-01/02: backward compatibility of POST /api/Auth/login (M2.4a).
    // The baseline below was recorded from the implementation BEFORE M2.4a (commit fb991b8), and this
    // test was run green against that implementation. Every baseline field must keep its name and JSON
    // type; new fields may only be added.
    public class LoginResponseShapeTests : IClassFixture<DevLinkApiFactory>
    {
        private static readonly Dictionary<string, string> SuccessBaseline = new()
        {
            ["message"] = "string",
            ["userId"] = "number",
            ["userType"] = "string",
            ["email"] = "string",
            ["hasProfile"] = "boolean",
            ["hasProgrammerProfile"] = "boolean"
        };

        private static readonly Dictionary<string, string> FailureBaseline = new()
        {
            ["message"] = "string"
        };

        private readonly DevLinkApiFactory _factory;
        private readonly HttpClient _client;

        public LoginResponseShapeTests(DevLinkApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private static string Kind(JsonElement value) => value.ValueKind switch
        {
            JsonValueKind.True or JsonValueKind.False => "boolean",
            JsonValueKind.Number => "number",
            JsonValueKind.String => "string",
            JsonValueKind.Null => "null",
            JsonValueKind.Object => "object",
            JsonValueKind.Array => "array",
            _ => "undefined"
        };

        private static void AssertContainsBaseline(Dictionary<string, string> baseline, JsonElement body)
        {
            foreach (var (name, kind) in baseline)
            {
                Assert.True(body.TryGetProperty(name, out var value), $"baseline field '{name}' is missing");
                Assert.Equal(kind, Kind(value));
            }
        }

        [Fact]
        public async Task T_LG_BC_01_successful_login_keeps_every_baseline_field_and_type()
        {
            var email = ApiTestHelpers.UniqueEmail("shape");
            var userId = await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");

            var response = await ApiTestHelpers.LoginAsync(_client, email, "Secret123", "Customer");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            AssertContainsBaseline(SuccessBaseline, body);

            // Same values as before for the same account.
            Assert.Equal("Login successful", body.GetProperty("message").GetString());
            Assert.Equal(userId, body.GetProperty("userId").GetInt32());
            Assert.Equal("Customer", body.GetProperty("userType").GetString());
            Assert.Equal(email, body.GetProperty("email").GetString());
            Assert.False(body.GetProperty("hasProfile").GetBoolean());
            Assert.False(body.GetProperty("hasProgrammerProfile").GetBoolean());
        }

        [Fact]
        public async Task T_LG_BC_02_failed_login_keeps_status_401_and_a_message()
        {
            var response = await ApiTestHelpers.LoginAsync(_client, ApiTestHelpers.UniqueEmail("nobody"), "whatever1", "Customer");

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            AssertContainsBaseline(FailureBaseline, await response.Content.ReadFromJsonAsync<JsonElement>());
        }
    }
}
