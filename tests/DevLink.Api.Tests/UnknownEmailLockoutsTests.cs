using Services.Auth;

namespace DevLink.Api.Tests
{
    // T-UL-01…04 (fold-in F1): the in-memory tracker for unknown-email failures is bounded and expires.
    public class UnknownEmailLockoutsTests
    {
        private static readonly DateTime Start = new(2026, 11, 4, 12, 0, 0, DateTimeKind.Utc);

        [Fact]
        public void T_UL_01_spraying_random_emails_never_exceeds_the_size_limit()
        {
            var tracker = new UnknownEmailLockouts(maxEntries: 1_000);

            for (var i = 0; i < 25_000; i++)
            {
                tracker.RegisterFailure($"spray{i}@example.test", Start.AddMilliseconds(i));
                Assert.True(tracker.Count <= 1_000, $"count {tracker.Count} after {i + 1} emails");
            }
        }

        [Fact]
        public void T_UL_02_entries_expire_24_hours_after_the_last_failure()
        {
            var tracker = new UnknownEmailLockouts(maxEntries: 100);
            for (var i = 0; i < 4; i++) tracker.RegisterFailure("ghost@example.test", Start);

            // Within 24 h the 5th failure still locks; after 24 h the count starts again from zero.
            var later = Start + UnknownEmailLockouts.Forget + TimeSpan.FromMinutes(1);
            Assert.False(tracker.RegisterFailure("ghost@example.test", later));
            Assert.Null(tracker.LockedFor("ghost@example.test", later));

            var expiredOnly = new UnknownEmailLockouts(maxEntries: 100);
            expiredOnly.RegisterFailure("old@example.test", Start);
            Assert.Null(expiredOnly.LockedFor("old@example.test", later)); // read of an expired entry removes it
            Assert.Equal(0, expiredOnly.Count);
        }

        [Fact]
        public void T_UL_03_when_full_expired_entries_are_evicted_before_recent_ones()
        {
            var tracker = new UnknownEmailLockouts(maxEntries: 10);
            for (var i = 0; i < 5; i++) tracker.RegisterFailure($"old{i}@example.test", Start);
            var now = Start + UnknownEmailLockouts.Forget + TimeSpan.FromHours(1);
            for (var i = 0; i < 5; i++) tracker.RegisterFailure($"recent{i}@example.test", now);

            // Full: the next new email evicts the 5 expired entries, not the recent ones.
            for (var i = 0; i < 4; i++) tracker.RegisterFailure("recent0@example.test", now);
            tracker.RegisterFailure("newcomer@example.test", now);

            Assert.NotNull(tracker.LockedFor("recent0@example.test", now)); // its lock survived
            Assert.True(tracker.Count <= 10);
        }

        [Fact]
        public void T_UL_04_lockout_still_works_within_the_limit()
        {
            var tracker = new UnknownEmailLockouts(maxEntries: 100);
            for (var i = 0; i < 4; i++) Assert.False(tracker.RegisterFailure("target@example.test", Start));

            Assert.True(tracker.RegisterFailure("target@example.test", Start));
            Assert.Equal(LoginService.LockoutDuration, tracker.LockedFor("target@example.test", Start));
            Assert.Null(tracker.LockedFor("target@example.test", Start + LoginService.LockoutDuration + TimeSpan.FromSeconds(1)));
        }
    }
}
