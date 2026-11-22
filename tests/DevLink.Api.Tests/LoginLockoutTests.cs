using System.Net;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // T-LG-06…08: lockout after 5 consecutive failures, for 15 minutes, identical for unknown emails.
    // Own fixture: these tests move the clock forward.
    public class LoginLockoutTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public LoginLockoutTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<HttpResponseMessage> Login(string email, string password) =>
            SessionApiFactory.LoginAsync(_client, email, password, "Customer");

        [Fact]
        public async Task T_LG_06_five_failures_lock_the_account_for_15_minutes()
        {
            var email = ApiTestHelpers.UniqueEmail("lock");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");

            for (var i = 1; i <= 5; i++)
            {
                Assert.Equal(HttpStatusCode.Unauthorized, (await Login(email, "Wrong-pass1")).StatusCode);
            }

            // Locked: even the correct password is refused, without being checked.
            var locked = await Login(email, "Secret123");
            Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
            Assert.Equal("ACCOUNT_LOCKED", await SessionApiFactory.ErrorCode(locked));
            Assert.InRange(int.Parse(locked.Headers.GetValues("Retry-After").Single()), 840, 900);

            await _factory.WithDbAsync(async db =>
            {
                var user = await db.Users.AsNoTracking().SingleAsync(u => u.Email == email);
                Assert.NotNull(user.LockoutEndAt);
                Assert.Equal(0, user.FailedLoginCount);
                Assert.Contains(await db.SecurityEvents.AsNoTracking().Where(e => e.UserId == user.Id).ToListAsync(),
                    e => e.EventType == "Auth.LockedOut" && e.IpPrefix == SessionApiFactory.ClientIpPrefix);
            });

            _factory.Time.Advance(TimeSpan.FromMinutes(16));
            try
            {
                Assert.Equal(HttpStatusCode.OK, (await Login(email, "Secret123")).StatusCode);
                await _factory.WithDbAsync(async db =>
                {
                    var user = await db.Users.AsNoTracking().SingleAsync(u => u.Email == email);
                    Assert.Null(user.LockoutEndAt);
                    Assert.Equal(0, user.FailedLoginCount);
                });
            }
            finally
            {
                _factory.Time.Advance(TimeSpan.FromMinutes(-16)); // shared fixture clock
            }
        }

        [Fact]
        public async Task T_LG_07_unknown_emails_get_the_same_lockout_sequence()
        {
            var email = ApiTestHelpers.UniqueEmail("ghost-lock");

            for (var i = 1; i <= 5; i++)
            {
                var r = await Login(email, "Whatever1");
                Assert.Equal(HttpStatusCode.Unauthorized, r.StatusCode);
                Assert.Equal("INVALID_CREDENTIALS", await SessionApiFactory.ErrorCode(r));
            }

            var locked = await Login(email, "Whatever1");
            Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
            Assert.Equal("ACCOUNT_LOCKED", await SessionApiFactory.ErrorCode(locked));
            Assert.True(locked.Headers.Contains("Retry-After"));

            _factory.Time.Advance(TimeSpan.FromMinutes(16));
            try
            {
                Assert.Equal(HttpStatusCode.Unauthorized, (await Login(email, "Whatever1")).StatusCode);
            }
            finally
            {
                _factory.Time.Advance(TimeSpan.FromMinutes(-16)); // shared fixture clock
            }
        }

        [Fact]
        public async Task T_LG_08_a_successful_login_resets_the_failure_count()
        {
            var email = ApiTestHelpers.UniqueEmail("reset");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");

            for (var i = 0; i < 4; i++) await Login(email, "Wrong-pass1");
            Assert.Equal(HttpStatusCode.OK, (await Login(email, "Secret123")).StatusCode);
            for (var i = 0; i < 4; i++) await Login(email, "Wrong-pass1");

            Assert.Equal(HttpStatusCode.OK, (await Login(email, "Secret123")).StatusCode);
            await _factory.WithDbAsync(async db =>
                Assert.Equal(0, (await db.Users.AsNoTracking().SingleAsync(u => u.Email == email)).FailedLoginCount));
        }
    }
}
