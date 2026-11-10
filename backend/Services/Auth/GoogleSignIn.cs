using System.Security.Cryptography;
using DataBase;
using Microsoft.EntityFrameworkCore;
using Services.Security;

namespace Services.Auth
{
    public enum GoogleSignInOutcome
    {
        Success,
        InvalidToken,
        Unavailable,
        LinkRequired,
        SignUpRequired,
        AdminRefused,
        WrongPortal,
        LockedOut
    }

    public sealed record GoogleSignInResult(GoogleSignInOutcome Outcome, LoginResult? Login = null, bool IsNewUser = false, TimeSpan? RetryAfter = null);

    public enum GoogleLinkOutcome
    {
        Success,
        AlreadyLinked,
        InvalidToken,
        Unavailable,
        WrongPassword,
        LockedOut,
        EmailMismatch,
        SubjectInUse,
        AccountHasOtherGoogle,
        AdminRefused,
        NotFound
    }

    public sealed record GoogleLinkResult(GoogleLinkOutcome Outcome, AccessToken? Token = null, TimeSpan? RetryAfter = null);

    // ============================================================
    // Google sign-in and explicit linking (M2_AUTH_DESIGN §6.3, Q11, Q13).
    // Accounts are found by GoogleSubject only, never by email. An email
    // that already has an account is never linked automatically: the owner
    // signs in with the password and links Google from there. Admins never
    // use Google (Q13). A successful sign-in starts the same session as a
    // password login.
    // ============================================================
    public class GoogleSignInService
    {
        public const string ConnectedEmailSubject = "Google sign-in was connected to your DevLink account";
        public const string ConnectedEmailBody =
            "Google sign-in was just connected to your DevLink account, and your other sessions were signed out.\n\n" +
            "If this wasn't you, reset your password now and contact DevLink support.";

        private readonly AppDbContext _db;
        private readonly IGoogleTokenValidator _validator;
        private readonly LoginService _login;
        private readonly RefreshSessionService _sessions;
        private readonly PasswordService _passwords;
        private readonly TokenService _tokens;
        private readonly SessionStateCache _sessionCache;
        private readonly SecurityEventFactory _events;
        private readonly EmailQueue _emails;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;

        public GoogleSignInService(
            AppDbContext db,
            IGoogleTokenValidator validator,
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
            _validator = validator;
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

        public async Task<GoogleSignInResult> SignInAsync(
            string idToken, string userType, bool signUp, string clientType, bool issueRefreshToken, bool issueDownloadBinding,
            HttpContext http, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var token = await _validator.ValidateAsync(idToken, cancellationToken);
            if (token.Outcome != GoogleTokenOutcome.Valid)
            {
                await RecordAsync(http, SecurityEventOutcome.Failure, now, null, token.Reason, clientType, null, cancellationToken);
                return new GoogleSignInResult(token.Outcome is GoogleTokenOutcome.Unavailable or GoogleTokenOutcome.NotConfigured
                    ? GoogleSignInOutcome.Unavailable
                    : GoogleSignInOutcome.InvalidToken);
            }

            var google = token.Identity!;

            // 1. Subject known: that account, whatever its email is now.
            var user = await _db.Users.FirstOrDefaultAsync(u => u.GoogleSubject == google.Subject, cancellationToken);
            if (user != null)
            {
                if (user.UserType == "Admin")
                {
                    await RecordAsync(http, SecurityEventOutcome.Blocked, now, user.Id, "Admin", clientType, google.Email, cancellationToken);
                    return new GoogleSignInResult(GoogleSignInOutcome.AdminRefused);
                }

                if (user.LockoutEndAt > now)
                {
                    await RecordAsync(http, SecurityEventOutcome.Blocked, now, user.Id, "Locked", clientType, google.Email, cancellationToken);
                    return new GoogleSignInResult(GoogleSignInOutcome.LockedOut, RetryAfter: user.LockoutEndAt.Value - now);
                }

                if (!string.Equals(user.UserType, userType, StringComparison.Ordinal))
                {
                    await RecordAsync(http, SecurityEventOutcome.Failure, now, user.Id, "WrongPortal", clientType, google.Email, cancellationToken);
                    return new GoogleSignInResult(GoogleSignInOutcome.WrongPortal);
                }

                // Suspended accounts too: they get a restricted session, as with a password (§7.4).
                var login = await _login.StartSessionAsync(user, clientType, issueRefreshToken, issueDownloadBinding, SecurityEventTypes.GoogleLogin, http, cancellationToken);
                return new GoogleSignInResult(GoogleSignInOutcome.Success, login);
            }

            // 2. Unknown subject, email already has an account: never linked automatically (Q11).
            if (await _db.Users.AnyAsync(u => u.Email == google.Email, cancellationToken))
            {
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, null, "LinkRequired", clientType, google.Email, cancellationToken, SecurityEventTypes.GoogleLinkRequired);
                return new GoogleSignInResult(GoogleSignInOutcome.LinkRequired);
            }

            // 4. Unknown subject, new email, from the sign-in screen.
            if (!signUp)
            {
                await RecordAsync(http, SecurityEventOutcome.Failure, now, null, "NoAccount", clientType, google.Email, cancellationToken);
                return new GoogleSignInResult(GoogleSignInOutcome.SignUpRequired);
            }

            // 3. Unknown subject, new email, sign-up: a Customer or Programmer account (never Admin) holding the subject.
            var created = new User { Email = google.Email, UserType = userType, GoogleSubject = google.Subject };
            created.PasswordHash = _passwords.Hash(created, Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
            _db.Users.Add(created);
            _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.AccountCreated, SecurityEventOutcome.Success, now, reason: "Google", clientType: clientType, email: google.Email));
            try
            {
                await _db.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException)
            {
                // A parallel request created the same email or subject first (unique indexes): treat as an existing account.
                _db.ChangeTracker.Clear();
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, null, "LinkRequired", clientType, google.Email, cancellationToken, SecurityEventTypes.GoogleLinkRequired);
                return new GoogleSignInResult(GoogleSignInOutcome.LinkRequired);
            }

            var session = await _login.StartSessionAsync(created, clientType, issueRefreshToken, issueDownloadBinding, SecurityEventTypes.GoogleLogin, http, cancellationToken);
            return new GoogleSignInResult(GoogleSignInOutcome.Success, session, IsNewUser: true);
        }

        // POST google-link: the signed-in owner proves the password again; the Google email must be the account email
        // and the subject must be free. Then the stamp rotates, other sessions end, and this session gets a new token.
        public async Task<GoogleLinkResult> LinkAsync(
            int userId, Guid sessionId, string idToken, string currentPassword, string clientType, HttpContext http, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            if (user == null)
            {
                return new GoogleLinkResult(GoogleLinkOutcome.NotFound);
            }

            if (user.UserType == "Admin")
            {
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, user.Id, "Admin", clientType, null, cancellationToken, SecurityEventTypes.GoogleLinked);
                return new GoogleLinkResult(GoogleLinkOutcome.AdminRefused);
            }

            if (user.LockoutEndAt > now)
            {
                return new GoogleLinkResult(GoogleLinkOutcome.LockedOut, RetryAfter: user.LockoutEndAt.Value - now);
            }

            var check = _passwords.Verify(user, user.PasswordHash, currentPassword ?? "");
            if (check == PasswordCheckResult.Failed)
            {
                await _login.RecordPasswordFailureAsync(user, "GoogleLinkWrongPassword", clientType, http, cancellationToken);
                return new GoogleLinkResult(GoogleLinkOutcome.WrongPassword);
            }

            var token = await _validator.ValidateAsync(idToken, cancellationToken);
            if (token.Outcome != GoogleTokenOutcome.Valid)
            {
                await RecordAsync(http, SecurityEventOutcome.Failure, now, user.Id, token.Reason, clientType, null, cancellationToken, SecurityEventTypes.GoogleLinked);
                return new GoogleLinkResult(token.Outcome is GoogleTokenOutcome.Unavailable or GoogleTokenOutcome.NotConfigured
                    ? GoogleLinkOutcome.Unavailable
                    : GoogleLinkOutcome.InvalidToken);
            }

            var google = token.Identity!;
            if (user.GoogleSubject == google.Subject)
            {
                return new GoogleLinkResult(GoogleLinkOutcome.AlreadyLinked);
            }

            if (user.GoogleSubject != null)
            {
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, user.Id, "OtherGoogleLinked", clientType, null, cancellationToken, SecurityEventTypes.GoogleLinked);
                return new GoogleLinkResult(GoogleLinkOutcome.AccountHasOtherGoogle);
            }

            if (!string.Equals(google.Email, SecurityKeys.NormalizeEmail(user.Email), StringComparison.Ordinal))
            {
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, user.Id, "EmailMismatch", clientType, null, cancellationToken, SecurityEventTypes.GoogleLinked);
                return new GoogleLinkResult(GoogleLinkOutcome.EmailMismatch);
            }

            if (await _db.Users.AnyAsync(u => u.GoogleSubject == google.Subject, cancellationToken))
            {
                await RecordAsync(http, SecurityEventOutcome.Blocked, now, user.Id, "SubjectInUse", clientType, null, cancellationToken, SecurityEventTypes.GoogleLinked);
                return new GoogleLinkResult(GoogleLinkOutcome.SubjectInUse);
            }

            await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
            if (check == PasswordCheckResult.SuccessRehashNeeded)
            {
                user.PasswordHash = _passwords.Hash(user, currentPassword!);
            }

            user.GoogleSubject = google.Subject;
            user.SecurityStamp = User.NewSecurityStamp();
            user.FailedLoginCount = 0;
            try
            {
                await _db.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException)
            {
                // Another account linked the same subject at the same moment (unique index).
                await transaction.RollbackAsync(cancellationToken);
                _db.ChangeTracker.Clear();
                return new GoogleLinkResult(GoogleLinkOutcome.SubjectInUse);
            }

            var ended = await _sessions.EndSessionsAsync(
                _db.AuthSessions.Where(s => s.UserId == user.Id && s.Id != sessionId), AuthSessionStatus.Revoked, "GoogleLinked", now, cancellationToken);
            var evt = _events.Create(http, SecurityEventTypes.GoogleLinked, SecurityEventOutcome.Success, now, user.Id, sessionId, clientType: clientType, email: user.Email);
            evt.Details = System.Text.Json.JsonSerializer.Serialize(new { sessionsEnded = ended });
            _db.SecurityEvents.Add(evt);
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _sessionCache.Invalidate(user.Id);
            _emails.Enqueue(user.Email, ConnectedEmailSubject, ConnectedEmailBody);
            _logger.LogInformation("Auth.GoogleLinked user {UserId} sessions ended {Count}", user.Id, ended);

            return new GoogleLinkResult(GoogleLinkOutcome.Success,
                _tokens.CreateAccessToken(new AccessTokenRequest(user.Id, user.UserType, user.SecurityStamp, sessionId)));
        }

        private async Task RecordAsync(HttpContext http, string outcome, DateTime now, int? userId, string? reason, string clientType, string? email,
            CancellationToken cancellationToken, string eventType = SecurityEventTypes.GoogleLogin)
        {
            _db.SecurityEvents.Add(_events.Create(http, eventType, outcome, now, userId, reason: reason, clientType: clientType, email: email));
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogWarning("{EventType} {Outcome} {Reason} user {UserId}", eventType, outcome, reason, userId);
        }
    }
}
