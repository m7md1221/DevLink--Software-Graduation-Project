using System.Security.Cryptography;
using System.Text;
using DataBase;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Services.Security;

namespace Services.Auth
{
    public enum RefreshOutcome
    {
        Success,
        Expired,
        Revoked,
        ReuseDetected
    }

    public sealed record IssuedRefreshToken(string RawToken, DateTime ExpiresAt);

    public sealed record RefreshResult(
        RefreshOutcome Outcome,
        User? User = null,
        AuthSession? Session = null,
        AccessToken? AccessToken = null,
        IssuedRefreshToken? RefreshToken = null);

    // The web refresh-token cookie (M2_AUTH_DESIGN §4.1). Sent by the browser only to /api/Auth/session/*.
    public static class RefreshCookie
    {
        public const string Name = "devlink_rt";
        public const string Path = "/api/Auth/session";

        public static void Append(HttpResponse response, IssuedRefreshToken token, DateTime now)
        {
            response.Cookies.Append(Name, token.RawToken, new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Path = Path,
                // Rounded up, so the cookie never disappears before the token it carries expires.
                MaxAge = token.ExpiresAt > now ? TimeSpan.FromSeconds(Math.Ceiling((token.ExpiresAt - now).TotalSeconds)) : TimeSpan.Zero,
                IsEssential = true
            });
        }

        public static void Delete(HttpResponse response)
        {
            response.Cookies.Delete(Name, new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Path = Path
            });
        }
    }

    // ============================================================
    // Refresh tokens and session families (M2.4b; M2_AUTH_DESIGN §3.3,
    // §3.4, §3.6). Raw tokens are 256-bit random values; only their
    // SHA-256 is stored, one row per token, never overwritten.
    // ============================================================
    public class RefreshSessionService
    {
        public static readonly TimeSpan CustomerIdleLifetime = TimeSpan.FromDays(7);
        public static readonly TimeSpan AdminIdleLifetime = TimeSpan.FromHours(8);

        // Reuse alert limits (§6.5, Q12; owner rule 2026-11-04: at most one per session family per hour).
        public static readonly TimeSpan AlertWindowPerSession = TimeSpan.FromHours(1);
        public static readonly TimeSpan AlertWindowPerUser = TimeSpan.FromHours(24);
        public const int MaxAlertsPerUser = 3;

        public const string ReuseAlertSubject = "Security notice for your DevLink account";
        public const string ReuseAlertBody =
            "We signed you out of one DevLink session because of unusual activity with your sign-in. " +
            "If you recently signed in on another device or had a connection problem, you can ignore this message. " +
            "Otherwise, sign in and change your password.\n\nDevLink Team";

        private readonly AppDbContext _db;
        private readonly TokenService _tokens;
        private readonly SessionStateCache _sessionCache;
        private readonly SecurityEventFactory _events;
        private readonly EmailQueue _emails;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;

        public RefreshSessionService(
            AppDbContext db,
            TokenService tokens,
            SessionStateCache sessionCache,
            SecurityEventFactory events,
            EmailQueue emails,
            TimeProvider time,
            ILoggerFactory loggers)
        {
            _db = db;
            _tokens = tokens;
            _sessionCache = sessionCache;
            _events = events;
            _emails = emails;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        public static TimeSpan IdleLifetimeFor(string userType) =>
            userType == "Admin" ? AdminIdleLifetime : CustomerIdleLifetime;

        public static byte[] Hash(string rawToken) => SHA256.HashData(Encoding.ASCII.GetBytes(rawToken));

        // Adds (does not save) a new Active token for a session. Used at login and on rotation.
        public IssuedRefreshToken AddToken(AuthSession session, string userType, DateTime now, long? parentTokenId, out RefreshToken entity)
        {
            var raw = Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(32));
            var idleEnd = now + IdleLifetimeFor(userType);
            entity = new RefreshToken
            {
                SessionId = session.Id,
                TokenHash = Hash(raw),
                Status = RefreshTokenStatus.Active,
                CreatedAt = now,
                ExpiresAt = idleEnd < session.AbsoluteExpiresAt ? idleEnd : session.AbsoluteExpiresAt,
                ParentTokenId = parentTokenId
            };
            _db.RefreshTokens.Add(entity);
            return new IssuedRefreshToken(raw, entity.ExpiresAt);
        }

        // Strict single-use rotation (§3.4). Row locks serialize concurrent use of the same token.
        public async Task<RefreshResult> RefreshAsync(string rawToken, HttpContext http, string clientType, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var hash = Hash(rawToken);

            await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

            var token = await _db.RefreshTokens
                .FromSqlInterpolated($"SELECT * FROM [RefreshTokens] WITH (UPDLOCK, ROWLOCK) WHERE [TokenHash] = {hash}")
                .SingleOrDefaultAsync(cancellationToken);
            if (token == null)
            {
                return new RefreshResult(RefreshOutcome.Expired);
            }

            var session = await _db.AuthSessions
                .FromSqlInterpolated($"SELECT * FROM [AuthSessions] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {token.SessionId}")
                .SingleAsync(cancellationToken);

            if (session.Status != AuthSessionStatus.Active)
            {
                // The session already ended (logout, expiry, earlier reuse): nothing left to revoke.
                _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.EndedSessionTokenPresented, SecurityEventOutcome.Blocked, now,
                    session.UserId, session.Id, session.Status, clientType));
                await _db.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return new RefreshResult(RefreshOutcome.Revoked);
            }

            if (token.Status == RefreshTokenStatus.Rotated)
            {
                return await HandleReuseAsync(token, session, http, clientType, now, transaction, cancellationToken);
            }

            if (token.Status != RefreshTokenStatus.Active)
            {
                return new RefreshResult(RefreshOutcome.Revoked);
            }

            if (token.ExpiresAt <= now || session.AbsoluteExpiresAt <= now)
            {
                await EndSessionsAsync(_db.AuthSessions.Where(s => s.Id == session.Id), AuthSessionStatus.Expired, "Expired", now, cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                _sessionCache.Invalidate(session.UserId);
                return new RefreshResult(RefreshOutcome.Expired);
            }

            var user = await _db.Users.SingleAsync(u => u.Id == session.UserId, cancellationToken);

            // Old row → Rotated (kept for reuse detection), then the one new Active row, then the link.
            token.Status = RefreshTokenStatus.Rotated;
            token.ConsumedAt = now;
            session.LastRefreshedAt = now;
            await _db.SaveChangesAsync(cancellationToken);

            var issued = AddToken(session, user.UserType, now, token.Id, out var successor);
            await _db.SaveChangesAsync(cancellationToken);

            token.ReplacedByTokenId = successor.Id;
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            var access = _tokens.CreateAccessToken(new AccessTokenRequest(user.Id, user.UserType, user.SecurityStamp, session.Id));
            _logger.LogDebug("Auth.SessionRefreshed user {UserId}", user.Id);
            return new RefreshResult(RefreshOutcome.Success, user, session, access, issued);
        }

        private async Task<RefreshResult> HandleReuseAsync(
            RefreshToken token, AuthSession session, HttpContext http, string clientType, DateTime now,
            Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction transaction, CancellationToken cancellationToken)
        {
            // A rotated token came back: revoke the whole family, including the active successor.
            await EndSessionsAsync(_db.AuthSessions.Where(s => s.Id == session.Id), AuthSessionStatus.Revoked, "ReuseDetected", now, cancellationToken);

            var rotatedAgo = token.ConsumedAt.HasValue ? (int)(now - token.ConsumedAt.Value).TotalSeconds : (int?)null;
            var evt = _events.Create(http, SecurityEventTypes.RefreshTokenReuse, SecurityEventOutcome.Blocked, now,
                session.UserId, session.Id, clientType: clientType);
            evt.TargetType = "RefreshToken";
            evt.TargetId = token.Id.ToString();
            evt.Details = System.Text.Json.JsonSerializer.Serialize(new { rotatedAgoSeconds = rotatedAgo });
            _db.SecurityEvents.Add(evt);
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _sessionCache.Invalidate(session.UserId);
            _logger.LogWarning("Auth.RefreshTokenReuse user {UserId} session {SessionId} rotatedAgoSeconds {RotatedAgo}",
                session.UserId, session.Id, rotatedAgo);

            await QueueReuseAlertAsync(session, http, clientType, now, cancellationToken);
            return new RefreshResult(RefreshOutcome.ReuseDetected);
        }

        // Generic security notice to the account owner (§6.5). Runs after the revocation committed and never affects it.
        // The email holds no token, IP, device, time detail or session id. Limits are counted from SecurityEvents.
        private async Task QueueReuseAlertAsync(AuthSession session, HttpContext http, string clientType, DateTime now, CancellationToken cancellationToken)
        {
            try
            {
                var sinceSession = now - AlertWindowPerSession;
                var sinceUser = now - AlertWindowPerUser;
                var alerts = _db.SecurityEvents.Where(e => e.EventType == SecurityEventTypes.ReuseAlertQueued && e.Outcome == SecurityEventOutcome.Success);
                var limited = await alerts.AnyAsync(e => e.SessionId == session.Id && e.OccurredAt > sinceSession, cancellationToken) ||
                              await alerts.CountAsync(e => e.UserId == session.UserId && e.OccurredAt > sinceUser, cancellationToken) >= MaxAlertsPerUser;

                var email = await _db.Users.Where(u => u.Id == session.UserId).Select(u => u.Email).SingleOrDefaultAsync(cancellationToken);
                var outcome = limited || email == null
                    ? SecurityEventOutcome.Blocked
                    : _emails.Enqueue(email, ReuseAlertSubject, ReuseAlertBody) ? SecurityEventOutcome.Success : SecurityEventOutcome.Failure;

                _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.ReuseAlertQueued, outcome, now, session.UserId, session.Id,
                    reason: limited ? "AlertLimit" : email == null ? "NoAccount" : outcome == SecurityEventOutcome.Failure ? "QueueFull" : null,
                    clientType: clientType));
                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Auth.ReuseAlert user {UserId} outcome {Outcome}", session.UserId, outcome);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError("Auth.ReuseAlertFailed {FailureType}", ex.GetType().Name);
            }
        }

        // Ends the given sessions and revokes their active tokens (rotated rows keep their status for forensics).
        public async Task<int> EndSessionsAsync(IQueryable<AuthSession> sessions, string status, string reason, DateTime now, CancellationToken cancellationToken)
        {
            var active = sessions.Where(s => s.Status == AuthSessionStatus.Active);
            var ids = await active.Select(s => s.Id).ToListAsync(cancellationToken);
            if (ids.Count == 0)
            {
                return 0;
            }

            await _db.RefreshTokens
                .Where(t => ids.Contains(t.SessionId) && t.Status == RefreshTokenStatus.Active)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(t => t.Status, RefreshTokenStatus.Revoked)
                    .SetProperty(t => t.RevokedAt, now), cancellationToken);

            return await _db.AuthSessions
                .Where(s => ids.Contains(s.Id) && s.Status == AuthSessionStatus.Active)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(x => x.Status, status)
                    .SetProperty(x => x.RevokedAt, now)
                    .SetProperty(x => x.RevokeReason, reason), cancellationToken);
        }

        // Current session only. Identified by its refresh token (cookie/body) or, failing that, the access token's sid.
        public async Task LogoutAsync(string? rawToken, Guid? sessionId, HttpContext http, string clientType, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            if (!string.IsNullOrEmpty(rawToken))
            {
                var hash = Hash(rawToken);
                sessionId = await _db.RefreshTokens.Where(t => t.TokenHash == hash).Select(t => (Guid?)t.SessionId).FirstOrDefaultAsync(cancellationToken)
                            ?? sessionId;
            }

            if (sessionId == null)
            {
                return;
            }

            var userId = await _db.AuthSessions.Where(s => s.Id == sessionId).Select(s => (int?)s.UserId).FirstOrDefaultAsync(cancellationToken);
            if (userId == null)
            {
                return;
            }

            var ended = await EndSessionsAsync(_db.AuthSessions.Where(s => s.Id == sessionId), AuthSessionStatus.Revoked, "Logout", now, cancellationToken);
            if (ended > 0)
            {
                _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.Logout, SecurityEventOutcome.Success, now, userId, sessionId, clientType: clientType));
                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Auth.Logout user {UserId}", userId);
            }

            _sessionCache.Invalidate(userId.Value);
        }

        // Every session of the user: rotate the security stamp (kills all access tokens) and revoke all families.
        public async Task LogoutAllAsync(int userId, HttpContext http, string clientType, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

            await _db.Users.Where(u => u.Id == userId)
                .ExecuteUpdateAsync(s => s.SetProperty(u => u.SecurityStamp, User.NewSecurityStamp()), cancellationToken);
            var ended = await EndSessionsAsync(_db.AuthSessions.Where(s => s.UserId == userId), AuthSessionStatus.Revoked, "LogoutAll", now, cancellationToken);

            var evt = _events.Create(http, SecurityEventTypes.LogoutAll, SecurityEventOutcome.Success, now, userId, clientType: clientType);
            evt.Details = System.Text.Json.JsonSerializer.Serialize(new { sessionsEnded = ended });
            _db.SecurityEvents.Add(evt);
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _sessionCache.Invalidate(userId);
            _logger.LogInformation("Auth.LogoutAll user {UserId} sessions {Count}", userId, ended);
        }
    }
}
