using DataBase;
using Microsoft.EntityFrameworkCore;
using Services.Security;

namespace Services.Auth
{
    public enum PasswordChangeOutcome
    {
        Success,
        WrongPassword,
        LockedOut,
        NoPassword,
        PolicyFailed,
        NotFound
    }

    public sealed record PasswordChangeResult(
        PasswordChangeOutcome Outcome, AccessToken? Token = null, TimeSpan? RetryAfter = null, string? PolicyError = null);

    // ============================================================
    // POST change-password (M2.11b; FR-AUTH-11; M2_AUTH_DESIGN §3.6, C7).
    // The signed-in user proves the current password; a wrong one counts
    // toward the account lockout exactly like a failed login. The new
    // password follows the sign-up/reset policy. On success, in one
    // transaction: new hash, new security stamp, every OTHER session
    // revoked (PasswordChanged) and a security event; then the cache is
    // cleared, a notice email is queued and the current session gets a new
    // access token (its old one carries the old stamp).
    // Accounts created with Google have no password (HasPassword = false)
    // and are told to use password reset instead.
    // ============================================================
    public class PasswordChangeService
    {
        public const string NoticeSubject = "Your DevLink password was changed";
        public const string NoticeBody =
            "Your DevLink password was just changed, and your other sessions were signed out.\n\n" +
            "If this wasn't you, reset your password now and contact DevLink support.";

        private readonly AppDbContext _db;
        private readonly LoginService _login;
        private readonly RefreshSessionService _sessions;
        private readonly PasswordService _passwords;
        private readonly TokenService _tokens;
        private readonly SessionStateCache _sessionCache;
        private readonly SecurityEventFactory _events;
        private readonly EmailQueue _emails;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;

        public PasswordChangeService(
            AppDbContext db,
            LoginService login,
            RefreshSessionService sessions,
            PasswordService passwords,
            TokenService tokens,
            SessionStateCache sessionCache,
            SecurityEventFactory events,
            EmailQueue emails,
            TimeProvider time,
            ILoggerFactory loggers)
        {
            _db = db;
            _login = login;
            _sessions = sessions;
            _passwords = passwords;
            _tokens = tokens;
            _sessionCache = sessionCache;
            _events = events;
            _emails = emails;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        public async Task<PasswordChangeResult> ChangeAsync(
            int userId, Guid sessionId, string currentPassword, string newPassword, string clientType, HttpContext http, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            if (user == null)
            {
                return new PasswordChangeResult(PasswordChangeOutcome.NotFound);
            }

            if (user.LockoutEndAt > now)
            {
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, user, sessionId, "Locked", clientType, cancellationToken);
                return new PasswordChangeResult(PasswordChangeOutcome.LockedOut, RetryAfter: user.LockoutEndAt.Value - now);
            }

            // Checked before the password, so a Google-only account never builds up lockout failures here.
            if (!user.HasPassword)
            {
                await RecordAsync(http, SecurityEventOutcome.Failure, now, user, sessionId, "NoPassword", clientType, cancellationToken);
                return new PasswordChangeResult(PasswordChangeOutcome.NoPassword);
            }

            if (_passwords.Verify(user, user.PasswordHash, currentPassword ?? "") == PasswordCheckResult.Failed)
            {
                await _login.RecordPasswordFailureAsync(user, "ChangePasswordWrongPassword", clientType, http, cancellationToken);
                return new PasswordChangeResult(PasswordChangeOutcome.WrongPassword);
            }

            var policyError = _passwords.ValidatePolicy(newPassword ?? "", user.Email);
            if (policyError != null)
            {
                await RecordAsync(http, SecurityEventOutcome.Failure, now, user, sessionId, "Policy", clientType, cancellationToken);
                return new PasswordChangeResult(PasswordChangeOutcome.PolicyFailed, PolicyError: policyError);
            }

            int ended;
            await using (var transaction = await _db.Database.BeginTransactionAsync(cancellationToken))
            {
                user.PasswordHash = _passwords.Hash(user, newPassword!);
                user.HasPassword = true;
                user.SecurityStamp = User.NewSecurityStamp();
                user.FailedLoginCount = 0;
                user.LockoutEndAt = null;
                await _db.SaveChangesAsync(cancellationToken);

                ended = await _sessions.EndSessionsAsync(
                    _db.AuthSessions.Where(s => s.UserId == user.Id && s.Id != sessionId), AuthSessionStatus.Revoked, "PasswordChanged", now, cancellationToken);

                var evt = _events.Create(http, SecurityEventTypes.PasswordChanged, SecurityEventOutcome.Success, now, user.Id, sessionId,
                    clientType: clientType, email: user.Email);
                evt.Details = System.Text.Json.JsonSerializer.Serialize(new { sessionsEnded = ended });
                _db.SecurityEvents.Add(evt);
                await _db.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
            }

            _sessionCache.Invalidate(user.Id);

            // The change stands even if the notice can't be queued (the queue logs the drop).
            var noticeQueued = _emails.Enqueue(user.Email, NoticeSubject, NoticeBody);
            _logger.LogInformation("Auth.PasswordChanged user {UserId} sessions ended {Count} notice queued {Queued}", user.Id, ended, noticeQueued);

            return new PasswordChangeResult(PasswordChangeOutcome.Success,
                _tokens.CreateAccessToken(new AccessTokenRequest(user.Id, user.UserType, user.SecurityStamp, sessionId)));
        }

        private async Task RecordAsync(HttpContext http, string outcome, DateTime now, User user, Guid sessionId, string reason, string clientType,
            CancellationToken cancellationToken)
        {
            _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.PasswordChanged, outcome, now, user.Id, sessionId,
                reason: reason, clientType: clientType, email: user.Email));
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogWarning("Auth.PasswordChanged {Outcome} {Reason} user {UserId}", outcome, reason, user.Id);
        }
    }
}
