using System.Security.Cryptography;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // T-RT-10 + KI-42: the cleanup service expires and deletes sessions/tokens and applies the R3 retention.
    public class SessionCleanupTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;

        public SessionCleanupTests(SessionApiFactory factory)
        {
            _factory = factory;
            factory.CreateClient();
        }

        private SessionCleanupService Cleanup =>
            _factory.Services.GetServices<IHostedService>().OfType<SessionCleanupService>().Single();

        private static AuthSession Session(int userId, DateTime created, DateTime absolute, string status = AuthSessionStatus.Active, DateTime? revokedAt = null) => new()
        {
            Id = Guid.NewGuid(), UserId = userId, ClientType = "web", Status = status,
            CreatedAt = created, LastRefreshedAt = created, AbsoluteExpiresAt = absolute, RevokedAt = revokedAt,
            RevokeReason = revokedAt == null ? null : "Logout"
        };

        private static RefreshToken Token(Guid sessionId, string status, DateTime created, DateTime expires) => new()
        {
            SessionId = sessionId, TokenHash = RandomNumberGenerator.GetBytes(32), Status = status, CreatedAt = created, ExpiresAt = expires
        };

        [Fact]
        public async Task T_RT_10_cleanup_expires_deletes_and_erases_ip_prefixes_but_never_touches_live_sessions()
        {
            var now = DateTime.UtcNow;
            var user = new User { Email = ApiTestHelpers.UniqueEmail("cleanup"), PasswordHash = "x", UserType = "Customer" };
            AuthSession live = null!, oldButLive = null!, absoluteExpired = null!, idleExpired = null!, legacyStale = null!, ended31 = null!, ended10 = null!;
            long eventIp15 = 0, eventIp5 = 0, event91 = 0;

            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(user);
                await db.SaveChangesAsync();

                live = Session(user.Id, now.AddHours(-1), now.AddDays(29));
                oldButLive = Session(user.Id, now.AddDays(-25), now.AddDays(5));            // old, still valid
                absoluteExpired = Session(user.Id, now.AddDays(-31), now.AddMinutes(-1));
                idleExpired = Session(user.Id, now.AddDays(-9), now.AddDays(21));
                legacyStale = Session(user.Id, now.AddMinutes(-20), now.AddDays(30));      // no refresh tokens (today's app)
                ended31 = Session(user.Id, now.AddDays(-40), now.AddDays(-10), AuthSessionStatus.Revoked, now.AddDays(-31));
                ended10 = Session(user.Id, now.AddDays(-12), now.AddDays(18), AuthSessionStatus.Revoked, now.AddDays(-10));
                db.AuthSessions.AddRange(live, oldButLive, absoluteExpired, idleExpired, legacyStale, ended31, ended10);
                await db.SaveChangesAsync();

                db.RefreshTokens.AddRange(
                    Token(live.Id, RefreshTokenStatus.Active, now.AddHours(-1), now.AddDays(6)),
                    Token(oldButLive.Id, RefreshTokenStatus.Rotated, now.AddDays(-25), now.AddDays(-18)),
                    Token(oldButLive.Id, RefreshTokenStatus.Active, now.AddDays(-1), now.AddDays(5)),
                    Token(absoluteExpired.Id, RefreshTokenStatus.Active, now.AddDays(-2), now.AddDays(5)),
                    Token(idleExpired.Id, RefreshTokenStatus.Active, now.AddDays(-9), now.AddDays(-2)),
                    Token(ended31.Id, RefreshTokenStatus.Rotated, now.AddDays(-40), now.AddDays(-33)),
                    Token(ended31.Id, RefreshTokenStatus.Revoked, now.AddDays(-33), now.AddDays(-26)),
                    Token(ended10.Id, RefreshTokenStatus.Revoked, now.AddDays(-12), now.AddDays(-5)));

                var events = new[]
                {
                    new SecurityEvent { OccurredAt = now.AddDays(-15), EventType = "Auth.LoginFailed", Outcome = "Failure", UserId = user.Id, IpPrefix = "198.51.100.0/24" },
                    new SecurityEvent { OccurredAt = now.AddDays(-5), EventType = "Auth.LoginFailed", Outcome = "Failure", UserId = user.Id, IpPrefix = "198.51.100.0/24" },
                    new SecurityEvent { OccurredAt = now.AddDays(-91), EventType = "Auth.LoginSucceeded", Outcome = "Success", UserId = user.Id }
                };
                db.SecurityEvents.AddRange(events);
                await db.SaveChangesAsync();
                (eventIp15, eventIp5, event91) = (events[0].Id, events[1].Id, events[2].Id);
            });

            await Cleanup.RunOnceAsync(CancellationToken.None);

            await _factory.WithDbAsync(async db =>
            {
                async Task<string?> StatusOf(AuthSession s) =>
                    await db.AuthSessions.AsNoTracking().Where(x => x.Id == s.Id).Select(x => x.Status).SingleOrDefaultAsync();

                Assert.Equal(AuthSessionStatus.Active, await StatusOf(live));
                Assert.Equal(AuthSessionStatus.Active, await StatusOf(oldButLive));
                Assert.Equal(2, await db.RefreshTokens.CountAsync(t => t.SessionId == oldButLive.Id)); // history of a live session kept
                Assert.Equal(AuthSessionStatus.Expired, await StatusOf(absoluteExpired));
                Assert.Equal(AuthSessionStatus.Expired, await StatusOf(idleExpired));
                Assert.Equal(AuthSessionStatus.Expired, await StatusOf(legacyStale));
                Assert.False(await db.RefreshTokens.AnyAsync(t => t.SessionId == absoluteExpired.Id && t.Status == RefreshTokenStatus.Active));

                Assert.Null(await StatusOf(ended31)); // deleted with its tokens
                Assert.False(await db.RefreshTokens.AnyAsync(t => t.SessionId == ended31.Id));
                Assert.Equal(AuthSessionStatus.Revoked, await StatusOf(ended10)); // ended < 30 days ago: kept
                Assert.Equal(1, await db.RefreshTokens.CountAsync(t => t.SessionId == ended10.Id));

                Assert.Null((await db.SecurityEvents.AsNoTracking().SingleAsync(e => e.Id == eventIp15)).IpPrefix);           // > 14 days: erased
                Assert.Equal("198.51.100.0/24", (await db.SecurityEvents.AsNoTracking().SingleAsync(e => e.Id == eventIp5)).IpPrefix);
                Assert.False(await db.SecurityEvents.AnyAsync(e => e.Id == event91));                                            // > 90 days: deleted
            });
        }
    }
}
