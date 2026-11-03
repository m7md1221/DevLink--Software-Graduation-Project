using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Services;

namespace DevLink.Api.Tests
{
    public class PasswordHashingTests : IClassFixture<DevLinkApiFactory>
    {
        private readonly DevLinkApiFactory _factory;
        private readonly HttpClient _client;

        public PasswordHashingTests(DevLinkApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<string> StoredPasswordAsync(string email)
        {
            string stored = "";
            await _factory.WithDbAsync(async db =>
            {
                stored = await db.Users
                    .Where(u => u.Email == email)
                    .Select(u => u.PasswordHash)
                    .SingleAsync();
            });
            return stored;
        }

        [Fact]
        public async Task Signup_stores_an_identity_hash_not_the_password()
        {
            var email = ApiTestHelpers.UniqueEmail("hash");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");

            var stored = await StoredPasswordAsync(email);

            Assert.NotEqual("Secret123", stored);
            Assert.True(PasswordService.IsIdentityHash(stored));
        }

        [Fact]
        public async Task Legacy_plaintext_account_can_log_in_and_is_rehashed()
        {
            var email = ApiTestHelpers.UniqueEmail("legacy");
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(new User { Email = email, PasswordHash = "OldPlain1", UserType = "Customer" });
                await db.SaveChangesAsync();
            });

            var first = await ApiTestHelpers.LoginAsync(_client, email, "OldPlain1", "Customer");
            Assert.Equal(HttpStatusCode.OK, first.StatusCode);

            var stored = await StoredPasswordAsync(email);
            Assert.True(PasswordService.IsIdentityHash(stored));

            var second = await ApiTestHelpers.LoginAsync(_client, email, "OldPlain1", "Customer");
            Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        }

        [Fact]
        public async Task Legacy_plaintext_account_with_wrong_password_is_rejected_and_unchanged()
        {
            var email = ApiTestHelpers.UniqueEmail("legacywrong");
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(new User { Email = email, PasswordHash = "OldPlain1", UserType = "Programmer" });
                await db.SaveChangesAsync();
            });

            var login = await ApiTestHelpers.LoginAsync(_client, email, "oldplain1", "Programmer");

            Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
            Assert.Equal("OldPlain1", await StoredPasswordAsync(email));
        }

        [Fact]
        public async Task Login_ignores_email_case_and_surrounding_spaces()
        {
            var email = ApiTestHelpers.UniqueEmail("case");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");

            var login = await ApiTestHelpers.LoginAsync(_client, "  " + email.ToUpper() + " ", "Secret123", "Customer");

            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        }

        [Fact]
        public async Task Signup_with_too_short_password_is_rejected()
        {
            var email = ApiTestHelpers.UniqueEmail("short");
            await _client.PostAsJsonAsync("/api/Auth/send-code", new { email });
            var code = _factory.Emails.LatestCodeFor(email);
            await _client.PostAsJsonAsync("/api/Auth/verify-code", new { email, code });

            var signup = await _client.PostAsJsonAsync("/api/Auth/signup",
                new { email, password = "abc", userType = "Customer" });

            Assert.Equal(HttpStatusCode.BadRequest, signup.StatusCode);
        }

        [Fact]
        public async Task Password_reset_stores_a_hash_and_new_password_works()
        {
            var email = ApiTestHelpers.UniqueEmail("reset");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");

            await _client.PostAsJsonAsync("/api/Auth/send-reset-code", new { email });
            var code = _factory.Emails.LatestCodeFor(email);
            var verify = await _client.PostAsJsonAsync("/api/Auth/verify-reset-code", new { email, code });
            Assert.Equal(HttpStatusCode.OK, verify.StatusCode);

            var reset = await _client.PostAsJsonAsync("/api/Auth/reset-password",
                new { email, newPassword = "NewSecret456" });
            Assert.Equal(HttpStatusCode.OK, reset.StatusCode);

            Assert.True(PasswordService.IsIdentityHash(await StoredPasswordAsync(email)));
            Assert.Equal(HttpStatusCode.OK,
                (await ApiTestHelpers.LoginAsync(_client, email, "NewSecret456", "Customer")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized,
                (await ApiTestHelpers.LoginAsync(_client, email, "Secret123", "Customer")).StatusCode);
        }

        [Fact]
        public async Task Admin_user_management_create_and_update_store_hashes()
        {
            var email = ApiTestHelpers.UniqueEmail("managed");

            var create = await _client.PostAsJsonAsync("/api/Admin/users",
                new { email, password = "Managed123", userType = "Customer" });
            Assert.Equal(HttpStatusCode.OK, create.StatusCode);
            Assert.True(PasswordService.IsIdentityHash(await StoredPasswordAsync(email)));

            int id = 0;
            await _factory.WithDbAsync(async db =>
                id = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync());

            var update = await _client.PutAsJsonAsync($"/api/Admin/users/{id}", new { password = "Changed456" });
            Assert.Equal(HttpStatusCode.OK, update.StatusCode);
            Assert.True(PasswordService.IsIdentityHash(await StoredPasswordAsync(email)));
            Assert.Equal(HttpStatusCode.OK,
                (await ApiTestHelpers.LoginAsync(_client, email, "Changed456", "Customer")).StatusCode);
        }
    }

    // Pure unit tests (no database).
    public class PasswordServiceTests
    {
        private static PasswordService CreateService(int? minLength = null)
        {
            var settings = new Dictionary<string, string?>();
            if (minLength.HasValue)
            {
                settings["Auth:MinPasswordLength"] = minLength.Value.ToString();
            }

            var configuration = new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
            return new PasswordService(configuration);
        }

        [Theory]
        [InlineData("password")]
        [InlineData("Secret123")]
        [InlineData("QUJD")] // valid base64, but not an Identity hash
        [InlineData("")]
        public void Plaintext_values_are_not_identity_hashes(string value)
        {
            Assert.False(PasswordService.IsIdentityHash(value));
        }

        [Fact]
        public void Hash_then_verify_round_trips_and_rejects_wrong_password()
        {
            var service = CreateService();
            var user = new User { Email = "a@example.test", UserType = "Customer" };

            var hash = service.Hash(user, "Secret123");

            Assert.True(PasswordService.IsIdentityHash(hash));
            Assert.Equal(PasswordCheckResult.Success, service.Verify(user, hash, "Secret123"));
            Assert.Equal(PasswordCheckResult.Failed, service.Verify(user, hash, "secret123"));
        }

        [Fact]
        public void Minimum_length_defaults_to_6_and_is_configurable()
        {
            Assert.Null(CreateService().ValidatePolicy("abcdef"));
            Assert.NotNull(CreateService().ValidatePolicy("abcde"));
            Assert.NotNull(CreateService(10).ValidatePolicy("abcdefghi"));
        }
    }
}
