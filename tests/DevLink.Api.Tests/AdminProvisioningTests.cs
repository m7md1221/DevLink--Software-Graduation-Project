using System.Net;
using System.Net.Http.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Services;

namespace DevLink.Api.Tests
{
    public class AdminProvisioningTests : IClassFixture<DevLinkApiFactory>
    {
        private readonly DevLinkApiFactory _factory;
        private readonly HttpClient _client;

        public AdminProvisioningTests(DevLinkApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<AdminSeedResult> SeedAsync(string email, string password)
        {
            AdminSeedResult result = null!;
            await _factory.WithDbAsync(async db =>
            {
                var passwords = _factory.Services.GetRequiredService<PasswordService>();
                result = await AdminSeeder.SeedAsync(db, passwords, email, password);
            });
            return result;
        }

        private async Task<int> IdOfAsync(string email)
        {
            int id = 0;
            await _factory.WithDbAsync(async db =>
                id = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync());
            return id;
        }

        [Fact]
        public async Task Api_cannot_create_an_admin()
        {
            var email = ApiTestHelpers.UniqueEmail("wannabe");

            var response = await _client.PostAsJsonAsync("/api/Admin/users",
                new { email, password = "Admin1234", userType = "Admin" });

            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            await _factory.WithDbAsync(async db =>
                Assert.False(await db.Users.AnyAsync(u => u.Email == email)));
        }

        [Fact]
        public async Task Api_cannot_promote_a_user_to_admin()
        {
            var email = ApiTestHelpers.UniqueEmail("promote");
            await _client.PostAsJsonAsync("/api/Admin/users", new { email, password = "User1234", userType = "Customer" });
            var id = await IdOfAsync(email);

            var response = await _client.PutAsJsonAsync($"/api/Admin/users/{id}", new { userType = "Admin" });

            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            await _factory.WithDbAsync(async db =>
                Assert.Equal("Customer", (await db.Users.SingleAsync(u => u.Id == id)).UserType));
        }

        [Fact]
        public async Task Api_cannot_change_or_delete_an_existing_admin()
        {
            var email = ApiTestHelpers.UniqueEmail("admin");
            Assert.True((await SeedAsync(email, "Admin1234")).Success);
            var id = await IdOfAsync(email);

            var update = await _client.PutAsJsonAsync($"/api/Admin/users/{id}", new { password = "Hijack123" });
            var delete = await _client.DeleteAsync($"/api/Admin/users/{id}");

            Assert.Equal(HttpStatusCode.Forbidden, update.StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, delete.StatusCode);
            Assert.Equal(HttpStatusCode.OK,
                (await ApiTestHelpers.LoginAsync(_client, email, "Admin1234", "Admin")).StatusCode);
        }

        [Fact]
        public async Task Seeder_creates_a_hashed_admin_who_can_log_in()
        {
            var email = ApiTestHelpers.UniqueEmail("seeded");

            var result = await SeedAsync(email, "Admin1234");

            Assert.True(result.Success);
            await _factory.WithDbAsync(async db =>
            {
                var admin = await db.Users.SingleAsync(u => u.Email == email);
                Assert.Equal("Admin", admin.UserType);
                Assert.True(PasswordService.IsIdentityHash(admin.PasswordHash));
            });
            Assert.Equal(HttpStatusCode.OK,
                (await ApiTestHelpers.LoginAsync(_client, email, "Admin1234", "Admin")).StatusCode);
        }

        [Fact]
        public async Task Seeder_is_idempotent_and_does_not_change_an_existing_admin_password()
        {
            var email = ApiTestHelpers.UniqueEmail("twice");
            await SeedAsync(email, "Admin1234");

            var second = await SeedAsync(email, "Different99");

            Assert.True(second.Success);
            await _factory.WithDbAsync(async db =>
                Assert.Equal(1, await db.Users.CountAsync(u => u.Email == email)));
            Assert.Equal(HttpStatusCode.OK,
                (await ApiTestHelpers.LoginAsync(_client, email, "Admin1234", "Admin")).StatusCode);
        }

        [Fact]
        public async Task Seeder_refuses_to_take_over_a_non_admin_account()
        {
            var email = ApiTestHelpers.UniqueEmail("taken");
            await _client.PostAsJsonAsync("/api/Admin/users", new { email, password = "User1234", userType = "Programmer" });

            var result = await SeedAsync(email, "Admin1234");

            Assert.False(result.Success);
            await _factory.WithDbAsync(async db =>
                Assert.Equal("Programmer", (await db.Users.SingleAsync(u => u.Email == email)).UserType));
        }

        [Fact]
        public async Task Seeder_rejects_a_password_that_violates_the_policy()
        {
            var result = await SeedAsync(ApiTestHelpers.UniqueEmail("weak"), "abc");

            Assert.False(result.Success);
        }
    }
}
