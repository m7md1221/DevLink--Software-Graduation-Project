using DataBase;
using Microsoft.EntityFrameworkCore;

namespace Services.Auth
{
    public sealed record CleanupSummary(
        int SessionsExpired, int SessionsDeleted, int TokensDeleted, int IpPrefixesErased, int EventsDeleted, int CodesDeleted,
        int ReadNotificationsDeleted = 0, int UnreadNotificationsDeleted = 0);

    // Notification retention (M2.10, decision R4): read notifications are deleted 180 days after they were
    // created, unread ones after 365, so nothing a user hasn't seen disappears quickly. 0 turns a rule off.
    public class NotificationRetentionOptions
    {
        public const string SectionName = "Notifications";

        public int ReadRetentionDays { get; set; } = 180;

        public int UnreadRetentionDays { get; set; } = 365;
    }

    // ============================================================
    // Periodic cleanup (M2.4b; M2_AUTH_DESIGN §3.3, §3.4, §6.4, R3):
    //  - ends sessions past their absolute or idle lifetime (and legacy
    //    access-token-only sessions once their access token can no longer be valid);
    //  - deletes ended sessions and their tokens 30 days after they ended
    //    (never rows of a live session, so reuse stays detectable);
    //  - erases SecurityEvents.IpPrefix after 14 days and deletes events after 90 days (KI-42);
    //  - deletes one-time codes 24 h after expiry;
    //  - deletes notifications past their retention (M2.10).
    // Every foreign key is NO ACTION, so tokens are deleted before their sessions.
    // ============================================================
    public class SessionCleanupService : BackgroundService
    {
        public static readonly TimeSpan EndedSessionRetention = TimeSpan.FromDays(30);
        public static readonly TimeSpan IpPrefixRetention = TimeSpan.FromDays(14);
        public static readonly TimeSpan EventRetention = TimeSpan.FromDays(90);
        public static readonly TimeSpan CodeRetention = TimeSpan.FromHours(24);

        // A session without refresh tokens (legacy client) is useless once its last access token expired.
        private static readonly TimeSpan LegacySessionLifetime =
            TimeSpan.FromMinutes(JwtOptions.MaxAccessTokenMinutes) + JwtOptions.ClockSkew;

        private readonly IServiceScopeFactory _scopes;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;
        private readonly TimeSpan _interval;
        private readonly NotificationRetentionOptions _notifications = new();

        public SessionCleanupService(IServiceScopeFactory scopes, TimeProvider time, ILoggerFactory loggers, IConfiguration configuration)
        {
            _scopes = scopes;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
            _interval = TimeSpan.FromMinutes(Math.Max(1, configuration.GetValue("Auth:CleanupIntervalMinutes", 60)));
            configuration.GetSection(NotificationRetentionOptions.SectionName).Bind(_notifications);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var timer = new PeriodicTimer(_interval);
            try
            {
                while (await timer.WaitForNextTickAsync(stoppingToken))
                {
                    try
                    {
                        await RunOnceAsync(stoppingToken);
                    }
                    catch (Exception ex) when (ex is not OperationCanceledException)
                    {
                        _logger.LogError("Auth.CleanupFailed {FailureType}", ex.GetType().Name);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Host shutting down.
            }
        }

        public async Task<CleanupSummary> RunOnceAsync(CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var sessions = scope.ServiceProvider.GetRequiredService<RefreshSessionService>();
            var cache = scope.ServiceProvider.GetRequiredService<SessionStateCache>();

            // 1. End sessions that can no longer be used.
            var legacyCutoff = now - LegacySessionLifetime;
            var toExpire = db.AuthSessions.Where(s => s.Status == AuthSessionStatus.Active && (
                s.AbsoluteExpiresAt <= now ||
                (db.RefreshTokens.Any(t => t.SessionId == s.Id) &&
                 !db.RefreshTokens.Any(t => t.SessionId == s.Id && t.Status == RefreshTokenStatus.Active && t.ExpiresAt > now)) ||
                (!db.RefreshTokens.Any(t => t.SessionId == s.Id) && s.CreatedAt <= legacyCutoff)));
            var affectedUsers = await toExpire.Select(s => s.UserId).Distinct().ToListAsync(cancellationToken);
            var expired = await sessions.EndSessionsAsync(toExpire, AuthSessionStatus.Expired, "Expired", now, cancellationToken);
            foreach (var userId in affectedUsers)
            {
                cache.Invalidate(userId);
            }

            // 2. Delete sessions that ended more than 30 days ago, tokens first.
            var deleteBefore = now - EndedSessionRetention;
            var oldSessions = db.AuthSessions.Where(s => s.Status != AuthSessionStatus.Active && s.RevokedAt != null && s.RevokedAt < deleteBefore);
            var tokensDeleted = await db.RefreshTokens
                .Where(t => oldSessions.Any(s => s.Id == t.SessionId))
                .ExecuteDeleteAsync(cancellationToken);
            var sessionsDeleted = await oldSessions.ExecuteDeleteAsync(cancellationToken);

            // 3. R3: erase IP prefixes after 14 days, events after 90 days.
            var ipCutoff = now - IpPrefixRetention;
            var ipErased = await db.SecurityEvents
                .Where(e => e.IpPrefix != null && e.OccurredAt < ipCutoff)
                .ExecuteUpdateAsync(s => s.SetProperty(e => e.IpPrefix, (string?)null), cancellationToken);
            var eventsDeleted = await db.SecurityEvents
                .Where(e => e.OccurredAt < now - EventRetention)
                .ExecuteDeleteAsync(cancellationToken);

            // 4. One-time codes (used from M2.5).
            var codesDeleted = await db.OneTimeCodes
                .Where(c => c.ExpiresAt < now - CodeRetention)
                .ExecuteDeleteAsync(cancellationToken);

            // 5. Notifications (M2.10): read and unread have separate limits; a value of 0 or less keeps them.
            var readDeleted = _notifications.ReadRetentionDays > 0
                ? await db.Notifications
                    .Where(n => n.IsRead && n.CreatedAt < now.AddDays(-_notifications.ReadRetentionDays))
                    .ExecuteDeleteAsync(cancellationToken)
                : 0;
            var unreadDeleted = _notifications.UnreadRetentionDays > 0
                ? await db.Notifications
                    .Where(n => !n.IsRead && n.CreatedAt < now.AddDays(-_notifications.UnreadRetentionDays))
                    .ExecuteDeleteAsync(cancellationToken)
                : 0;

            var summary = new CleanupSummary(expired, sessionsDeleted, tokensDeleted, ipErased, eventsDeleted, codesDeleted, readDeleted, unreadDeleted);
            _logger.LogInformation("Auth.Cleanup {Summary}", summary);
            return summary;
        }
    }
}
