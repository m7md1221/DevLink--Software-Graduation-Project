using System.Collections.Concurrent;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using DataBase;
using Microsoft.EntityFrameworkCore;
using Services.Security;

namespace Services.Auth
{
    public enum LoginOutcome
    {
        Success,
        InvalidCredentials,
        LockedOut
    }

    public sealed record LoginResult(
        LoginOutcome Outcome,
        User? User = null,
        AuthSession? Session = null,
        AccessToken? Token = null,
        TimeSpan? RetryAfter = null);

    // ============================================================
    // Same lockout behaviour for emails that have no account, kept in
    // memory (single instance, §3.7), so the response sequence for an
    // unknown email is indistinguishable from a real one.
    // ============================================================
    public class UnknownEmailLockouts
    {
        private sealed record Entry(int Failures, DateTime? LockedUntil, DateTime LastSeen);

        private static readonly TimeSpan Forget = TimeSpan.FromHours(24);
        private readonly ConcurrentDictionary<string, Entry> _entries = new();

        // Keyed by a hash, so plain email addresses are not kept in memory.
        private static string Key(string normalizedEmail) =>
            Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalizedEmail)));

        public TimeSpan? LockedFor(string normalizedEmail, DateTime now) =>
            _entries.TryGetValue(Key(normalizedEmail), out var e) && e.LockedUntil > now ? e.LockedUntil - now : null;

        // Returns true when this failure starts a lockout.
        public bool RegisterFailure(string normalizedEmail, DateTime now)
        {
            if (_entries.Count > 50_000)
            {
                foreach (var stale in _entries.Where(kv => now - kv.Value.LastSeen > Forget).Select(kv => kv.Key).ToList())
                {
                    _entries.TryRemove(stale, out _);
                }
            }

            var updated = _entries.AddOrUpdate(
                Key(normalizedEmail),
                _ => new Entry(1, null, now),
                (_, e) =>
                {
                    var failures = (now - e.LastSeen > Forget ? 0 : e.Failures) + 1;
                    return failures >= LoginService.MaxFailedAttempts
                        ? new Entry(0, now + LoginService.LockoutDuration, now)
                        : new Entry(failures, e.LockedUntil, now);
                });

            return updated.LockedUntil == now + LoginService.LockoutDuration;
        }
    }

    // ============================================================
    // Password login (M2.4a; M2_AUTH_DESIGN §6.1, §6.2, §3.4).
    // - 5 consecutive failures lock the account for 15 minutes
    //   (FailedLoginCount / LockoutEndAt; the same rule for unknown emails).
    // - Unknown email, wrong password and wrong portal give the same
    //   response; every path performs one PBKDF2 verification and every
    //   failure is padded to a minimum duration, so timing doesn't tell.
    // - Success creates an AuthSession and a 15-minute access token.
    //   Refresh tokens, cookies and logout arrive in M2.4b.
    // ============================================================
    public class LoginService
    {
        public const int MaxFailedAttempts = 5;
        public static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);
        public static readonly TimeSpan CustomerSessionLifetime = TimeSpan.FromDays(30);
        public static readonly TimeSpan AdminSessionLifetime = TimeSpan.FromHours(24);

        private static readonly User DummyUser = new() { Email = "", PasswordHash = "", UserType = "" };
        private static string? _dummyHash;

        private readonly AppDbContext _db;
        private readonly PasswordService _passwords;
        private readonly TokenService _tokens;
        private readonly SessionStateCache _sessionCache;
        private readonly UnknownEmailLockouts _unknownEmails;
        private readonly SecurityEventFactory _events;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;
        private readonly TimeSpan _minimumFailureDuration;

        public LoginService(
            AppDbContext db,
            PasswordService passwords,
            TokenService tokens,
            SessionStateCache sessionCache,
            UnknownEmailLockouts unknownEmails,
            SecurityEventFactory events,
            TimeProvider time,
            ILoggerFactory loggers,
            IConfiguration configuration)
        {
            _db = db;
            _passwords = passwords;
            _tokens = tokens;
            _sessionCache = sessionCache;
            _unknownEmails = unknownEmails;
            _events = events;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
            _minimumFailureDuration = TimeSpan.FromMilliseconds(
                configuration.GetValue("Auth:FailedLoginMinimumMilliseconds", 300));

            // A real PBKDF2 hash (same hasher and parameters as account hashes), for equal-cost checks.
            _dummyHash ??= passwords.Hash(DummyUser, Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
        }

        public async Task<LoginResult> LoginAsync(
            string email, string password, string userType, string clientType, HttpContext http, CancellationToken cancellationToken)
        {
            var stopwatch = Stopwatch.StartNew();
            var result = await LoginCoreAsync(email, password, userType, clientType, http, cancellationToken);

            if (result.Outcome != LoginOutcome.Success && stopwatch.Elapsed < _minimumFailureDuration)
            {
                await Task.Delay(_minimumFailureDuration - stopwatch.Elapsed, cancellationToken);
            }

            return result;
        }

        private async Task<LoginResult> LoginCoreAsync(
            string rawEmail, string password, string userType, string clientType, HttpContext http, CancellationToken cancellationToken)
        {
            var email = (rawEmail ?? string.Empty).Trim().ToLowerInvariant();
            password ??= string.Empty;
            var now = _time.GetUtcNow().UtcDateTime;

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email, cancellationToken);

            // ----- No account with this email -----
            if (user == null)
            {
                if (_unknownEmails.LockedFor(email, now) is { } unknownRetry)
                {
                    await RecordAsync(http, SecurityEventTypes.LockedOut, SecurityEventOutcome.Blocked, now, null, null, "UnknownEmail", clientType, cancellationToken);
                    return new LoginResult(LoginOutcome.LockedOut, RetryAfter: unknownRetry);
                }

                _passwords.Verify(DummyUser, _dummyHash!, password);
                var lockedNow = _unknownEmails.RegisterFailure(email, now);

                _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.LoginFailed, SecurityEventOutcome.Failure, now, reason: "UnknownEmail", clientType: clientType));
                if (lockedNow)
                {
                    _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.LockedOut, SecurityEventOutcome.Blocked, now, reason: "UnknownEmail", clientType: clientType));
                }

                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogWarning("Auth.LoginFailed {Reason}", "UnknownEmail");
                return new LoginResult(LoginOutcome.InvalidCredentials);
            }

            // ----- Locked account: the password is not checked -----
            if (user.LockoutEndAt > now)
            {
                await RecordAsync(http, SecurityEventTypes.LockedOut, SecurityEventOutcome.Blocked, now, user.Id, null, "Locked", clientType, cancellationToken);
                return new LoginResult(LoginOutcome.LockedOut, RetryAfter: user.LockoutEndAt.Value - now);
            }

            var check = _passwords.Verify(user, user.PasswordHash, password);
            if (!PasswordService.IsIdentityHash(user.PasswordHash))
            {
                // Legacy plaintext values verify instantly; add the PBKDF2 cost every other path pays.
                _passwords.Verify(DummyUser, _dummyHash!, password);
            }

            var portalMatches = string.Equals(user.UserType, userType, StringComparison.Ordinal);

            // ----- Wrong password or wrong portal: one generic failure -----
            if (check == PasswordCheckResult.Failed || !portalMatches)
            {
                var reason = check == PasswordCheckResult.Failed ? "WrongPassword" : "WrongPortal";
                var lockUntil = now + LockoutDuration;

                // Atomic: concurrent failures can't lose increments. The 5th failure locks and resets the counter.
                await _db.Users
                    .Where(u => u.Id == user.Id)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(u => u.LockoutEndAt, u => u.FailedLoginCount + 1 >= MaxFailedAttempts ? lockUntil : u.LockoutEndAt)
                        .SetProperty(u => u.FailedLoginCount, u => u.FailedLoginCount + 1 >= MaxFailedAttempts ? 0 : u.FailedLoginCount + 1),
                        cancellationToken);

                var lockedNow = await _db.Users.AsNoTracking()
                    .Where(u => u.Id == user.Id)
                    .Select(u => u.LockoutEndAt)
                    .FirstAsync(cancellationToken) == lockUntil;

                _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.LoginFailed, SecurityEventOutcome.Failure, now, user.Id, reason: reason, clientType: clientType));
                if (lockedNow)
                {
                    _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.LockedOut, SecurityEventOutcome.Blocked, now, user.Id, reason: reason, clientType: clientType));
                }

                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogWarning("Auth.LoginFailed {Reason} user {UserId} locked {Locked}", reason, user.Id, lockedNow);
                return new LoginResult(LoginOutcome.InvalidCredentials);
            }

            // ----- Success (suspended accounts too: they get a restricted session, §7.4) -----
            if (check == PasswordCheckResult.SuccessRehashNeeded)
            {
                user.PasswordHash = _passwords.Hash(user, password);
            }

            user.FailedLoginCount = 0;
            user.LockoutEndAt = null;
            user.LastLoginAt = now;

            var session = new AuthSession
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                ClientType = clientType,
                Status = AuthSessionStatus.Active,
                CreatedAt = now,
                LastRefreshedAt = now,
                AbsoluteExpiresAt = now + (user.UserType == "Admin" ? AdminSessionLifetime : CustomerSessionLifetime)
            };
            _db.AuthSessions.Add(session);
            _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.LoginSucceeded, SecurityEventOutcome.Success, now, user.Id, session.Id, clientType: clientType));

            await _db.SaveChangesAsync(cancellationToken);
            _sessionCache.Invalidate(user.Id);

            var token = _tokens.CreateAccessToken(new AccessTokenRequest(user.Id, user.UserType, user.SecurityStamp, session.Id));
            _logger.LogInformation("Auth.LoginSucceeded user {UserId} client {ClientType} status {Status}", user.Id, clientType, user.Status);
            return new LoginResult(LoginOutcome.Success, user, session, token);
        }

        private async Task RecordAsync(HttpContext http, string type, string outcome, DateTime now, int? userId, Guid? sessionId,
            string reason, string clientType, CancellationToken cancellationToken)
        {
            _db.SecurityEvents.Add(_events.Create(http, type, outcome, now, userId, sessionId, reason, clientType));
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogWarning("{EventType} {Reason} user {UserId}", type, reason, userId);
        }
    }

    public static class LoginSetup
    {
        public static IServiceCollection AddDevLinkLogin(this IServiceCollection services)
        {
            services.AddSingleton<UnknownEmailLockouts>();
            services.AddSingleton<SecurityEventFactory>();
            services.AddScoped<LoginService>();
            return services;
        }
    }
}
