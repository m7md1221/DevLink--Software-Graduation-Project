using System.Diagnostics;
using System.Net;
using DataBase;
using DevLink.Api.Tests.Infrastructure;

namespace DevLink.Api.Tests
{
    // Timing measurements must not compete with other test classes for CPU.
    [CollectionDefinition("Timing", DisableParallelization = true)]
    public class TimingCollection
    {
    }

    // T-LG-05: unknown email, wrong password (PBKDF2 account) and wrong password (legacy plaintext
    // account) take the same time: each costs one PBKDF2 check and is padded to at least 300 ms.
    [Collection("Timing")]
    public class LoginTimingTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public LoginTimingTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private async Task<double> TimeFailure(string email)
        {
            var watch = Stopwatch.StartNew();
            var response = await SessionApiFactory.LoginAsync(_client, email, "Wrong-pass1", "Customer");
            watch.Stop();
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            return watch.Elapsed.TotalMilliseconds;
        }

        private static double Median(List<double> values)
        {
            values.Sort();
            return values[values.Count / 2];
        }

        [Fact]
        public async Task T_LG_05_failed_logins_take_the_same_time_whatever_the_reason()
        {
            // Two accounts per kind, so no account reaches the 5-failure lockout (3 attempts each).
            var hashed = new List<string>();
            var legacy = new List<string>();
            for (var i = 0; i < 2; i++)
            {
                var email = ApiTestHelpers.UniqueEmail($"timing-hashed{i}");
                await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");
                hashed.Add(email);
                legacy.Add(ApiTestHelpers.UniqueEmail($"timing-legacy{i}"));
            }

            await _factory.WithDbAsync(async db =>
            {
                db.Users.AddRange(legacy.Select(e => new User { Email = e, PasswordHash = "plain-pass-1", UserType = "Customer" }));
                await db.SaveChangesAsync();
            });

            await TimeFailure(ApiTestHelpers.UniqueEmail("warmup")); // JIT and connection warm-up, not measured

            var unknownTimes = new List<double>();
            var hashedTimes = new List<double>();
            var legacyTimes = new List<double>();

            // Interleaved rounds: any background load affects the three kinds equally.
            for (var round = 0; round < 6; round++)
            {
                unknownTimes.Add(await TimeFailure(ApiTestHelpers.UniqueEmail("timing-unknown")));
                hashedTimes.Add(await TimeFailure(hashed[round % 2]));
                legacyTimes.Add(await TimeFailure(legacy[round % 2]));
            }

            var medians = new[] { Median(unknownTimes), Median(hashedTimes), Median(legacyTimes) };
            var report = $"medians unknown={medians[0]:F0} hashed={medians[1]:F0} legacy={medians[2]:F0} ms";

            Assert.All(medians, m => Assert.True(m >= 290, report));
            Assert.True(medians.Max() - medians.Min() < 150, report);
        }
    }
}
