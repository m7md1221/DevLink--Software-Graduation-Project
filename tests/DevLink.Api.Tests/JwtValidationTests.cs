using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // T-JWT-01…05 and T-CS-07 (M2_AUTH_DESIGN §3.2, §4.2) against the test-only probe endpoint.
    public class JwtValidationTests : IClassFixture<DefaultHostApiFactory>
    {
        private const string MeRoute = "/__tests/auth/me";

        private readonly HostOnlyApiFactory _factory;
        private readonly HttpClient _client;

        public JwtValidationTests(DefaultHostApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private TokenMinter Minter(Func<TokenMinter, TokenMinter>? change = null)
        {
            var minter = new TokenMinter { KeyBase64 = _factory.SigningKey };
            return change == null ? minter : change(minter);
        }

        private async Task<HttpResponseMessage> GetWithToken(string token, string route = MeRoute)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, route);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return await _client.SendAsync(request);
        }

        private static async Task AssertProblem(HttpResponseMessage response, HttpStatusCode status, string errorCode)
        {
            Assert.Equal(status, response.StatusCode);
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);

            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(errorCode, body.GetProperty("errorCode").GetString());
            Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("message").GetString()));
            Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("traceId").GetString()));
        }

        // ---------- T-JWT-01: valid tokens, claims, expiry ----------

        [Fact]
        public async Task T_JWT_01_token_from_TokenService_is_accepted_with_expected_claims_and_no_email()
        {
            var tokens = _factory.Services.GetRequiredService<TokenService>();
            var sessionId = Guid.NewGuid();
            var issued = tokens.CreateAccessToken(new AccessTokenRequest(7, "Programmer", "stamp-7", sessionId));

            var header = new JsonWebToken(issued.Token);
            Assert.Equal("at+jwt", header.Typ);
            Assert.Equal("HS256", header.Alg);
            Assert.Equal(TestSecuritySettings.KeyId, header.Kid);
            Assert.InRange(header.ValidTo - header.IssuedAt, TimeSpan.FromMinutes(15), TimeSpan.FromMinutes(15));

            var response = await GetWithToken(issued.Token);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var body = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("7", body.GetProperty("name").GetString());
            var claims = body.GetProperty("claims");
            Assert.Equal("7", claims.GetProperty("sub").GetString());
            Assert.Equal("Programmer", claims.GetProperty("role").GetString());
            Assert.Equal("stamp-7", claims.GetProperty("sstamp").GetString());
            Assert.Equal(sessionId.ToString(), claims.GetProperty("sid").GetString());
            Assert.True(claims.TryGetProperty("jti", out _));
            Assert.False(claims.TryGetProperty("email", out _));
            Assert.DoesNotContain("@", header.EncodedPayload);
        }

        [Fact]
        public async Task T_JWT_01_expired_token_returns_401_TOKEN_EXPIRED()
        {
            var token = Minter(m => m with { IssuedAgo = TimeSpan.FromMinutes(20) }).Mint();

            var response = await GetWithToken(token);

            await AssertProblem(response, HttpStatusCode.Unauthorized, "TOKEN_EXPIRED");
            Assert.Contains("invalid_token", response.Headers.WwwAuthenticate.ToString());
        }

        [Fact]
        public async Task T_JWT_01_clock_skew_is_at_most_30_seconds()
        {
            // Expired 10 s ago: inside the 30 s skew. Expired 60 s ago: rejected (the default 5 min would accept it).
            var withinSkew = Minter(m => m with { IssuedAgo = TimeSpan.FromMinutes(15) + TimeSpan.FromSeconds(10) }).Mint();
            var beyondSkew = Minter(m => m with { IssuedAgo = TimeSpan.FromMinutes(16) }).Mint();

            Assert.Equal(HttpStatusCode.OK, (await GetWithToken(withinSkew)).StatusCode);
            await AssertProblem(await GetWithToken(beyondSkew), HttpStatusCode.Unauthorized, "TOKEN_EXPIRED");
        }

        [Fact]
        public async Task T_JWT_01_missing_token_returns_401_UNAUTHENTICATED()
        {
            var response = await _client.GetAsync(MeRoute);

            await AssertProblem(response, HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
            Assert.Equal("Bearer", response.Headers.WwwAuthenticate.ToString());
        }

        [Fact]
        public async Task T_JWT_01_role_comes_from_the_role_claim()
        {
            var customer = Minter(m => m with { Role = "Customer" }).Mint();
            var admin = Minter(m => m with { Role = "Admin" }).Mint();

            await AssertProblem(await GetWithToken(customer, "/__tests/auth/admin"), HttpStatusCode.Forbidden, "FORBIDDEN");
            Assert.Equal(HttpStatusCode.OK, (await GetWithToken(admin, "/__tests/auth/admin")).StatusCode);
        }

        // ---------- T-JWT-02: signature ----------

        [Fact]
        public async Task T_JWT_02_token_signed_with_another_key_is_rejected()
        {
            var token = Minter(m => m with { KeyBase64 = TestSecuritySettings.NewSigningKey() }).Mint();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        [Fact]
        public async Task T_JWT_02_tampered_payload_is_rejected()
        {
            var parts = Minter().Mint(userId: 5).Split('.');
            var forgedPayload = Base64UrlEncoder.Encode(
                Base64UrlEncoder.DecodeBytes(parts[1]).Select(b => b == (byte)'5' ? (byte)'6' : b).ToArray());

            var response = await GetWithToken($"{parts[0]}.{forgedPayload}.{parts[2]}");

            await AssertProblem(response, HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        // ---------- T-JWT-03: issuer and audience ----------

        [Theory]
        [InlineData("Someone.Else", "DevLink.Clients")]
        [InlineData("DevLink.Api", "Other.Audience")]
        public async Task T_JWT_03_wrong_issuer_or_audience_is_rejected(string issuer, string audience)
        {
            var token = Minter(m => m with { Issuer = issuer, Audience = audience }).Mint();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        // ---------- T-JWT-04: algorithms ----------

        [Fact]
        public async Task T_JWT_04_unsigned_alg_none_token_is_rejected()
        {
            var token = Minter().MintUnsigned();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        [Theory]
        [InlineData(SecurityAlgorithms.HmacSha384)]
        [InlineData(SecurityAlgorithms.HmacSha512)]
        public async Task T_JWT_04_other_hmac_algorithms_with_the_right_key_are_rejected(string algorithm)
        {
            var token = Minter(m => m with { Algorithm = algorithm }).Mint();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        // ---------- T-JWT-05: token type and lifetime ----------

        [Theory]
        [InlineData("JWT")]
        [InlineData("id+jwt")]
        public async Task T_JWT_05_wrong_token_type_is_rejected(string type)
        {
            var token = Minter(m => m with { TokenType = type }).Mint();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        [Fact]
        public async Task T_JWT_05_lifetime_longer_than_15_minutes_is_rejected()
        {
            var token = Minter(m => m with { Lifetime = TimeSpan.FromMinutes(20) }).Mint();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        [Fact]
        public async Task T_JWT_05_token_without_iat_is_rejected()
        {
            var token = Minter(m => m with { IncludeIssuedAt = false }).Mint();

            await AssertProblem(await GetWithToken(token), HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        // ---------- T-CS-07: tokens are read from the Authorization header only ----------

        [Fact]
        public async Task T_CS_07_token_in_a_cookie_is_ignored()
        {
            var token = Minter().Mint();
            using var request = new HttpRequestMessage(HttpMethod.Get, MeRoute);
            request.Headers.Add("Cookie", $"devlink_rt={token}; access_token={token}");

            var response = await _client.SendAsync(request);

            await AssertProblem(response, HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }

        [Fact]
        public async Task T_CS_07_token_in_the_query_string_is_ignored()
        {
            var token = Minter().Mint();

            var response = await _client.GetAsync($"{MeRoute}?access_token={token}");

            await AssertProblem(response, HttpStatusCode.Unauthorized, "UNAUTHENTICATED");
        }
    }
}
