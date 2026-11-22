using System.Collections.Concurrent;
using System.Security.Cryptography;
using DataBase;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Services.Security;

namespace Services.Auth
{
    public enum CodeRequestOutcome
    {
        Issued,
        RateLimited
    }

    public sealed record CodeRequestResult(CodeRequestOutcome Outcome, string? Code = null, TimeSpan? RetryAfter = null);

    public enum CodeVerifyOutcome
    {
        Verified,
        Invalid,
        AttemptsExceeded,
        RateLimited
    }

    public sealed record CodeVerifyResult(CodeVerifyOutcome Outcome, string? ProofToken = null, TimeSpan? RetryAfter = null);

    // ============================================================
    // Failed code verifications per client IP in a rolling hour (C6).
    // In memory (single instance, §3.7) and bounded like the unknown-email
    // tracker (F1): at most MaxEntries IPs, least recently seen evicted first.
    // ============================================================
    public class IpFailureWindow
    {
        public static readonly TimeSpan Window = TimeSpan.FromHours(1);
        private const int MaxEntries = 10_000;

        private readonly ConcurrentDictionary<string, Queue<DateTime>> _failures = new();
        private readonly object _sync = new();

        public IpFailureWindow(IConfiguration configuration)
        {
            Limit = Math.Max(1, configuration.GetValue("Auth:CodeFailuresPerIpPerHour", 20));
        }

        public int Limit { get; }

        public TimeSpan? BlockedFor(string ip, DateTime now)
        {
            lock (_sync)
            {
                if (!_failures.TryGetValue(ip, out var times)) return null;
                Prune(times, now);
                return times.Count >= Limit ? times.Peek() + Window - now : null;
            }
        }

        public void RecordFailure(string ip, DateTime now)
        {
            lock (_sync)
            {
                if (!_failures.ContainsKey(ip) && _failures.Count >= MaxEntries)
                {
                    foreach (var stale in _failures.OrderBy(kv => kv.Value.Count == 0 ? DateTime.MinValue : kv.Value.Last())
                                 .Take(MaxEntries / 10).Select(kv => kv.Key).ToList())
                    {
                        _failures.TryRemove(stale, out _);
                    }
                }

                var times = _failures.GetOrAdd(ip, _ => new Queue<DateTime>());
                Prune(times, now);
                times.Enqueue(now);
            }
        }

        private static void Prune(Queue<DateTime> times, DateTime now)
        {
            while (times.Count > 0 && now - times.Peek() >= Window)
            {
                times.Dequeue();
            }
        }
    }

    // ============================================================
    // Sign-up and password-reset codes (M2.5a; M2_AUTH_DESIGN §6.2, Q7, C6).
    // - 6 random digits; stored only as HMAC(purpose, email key, code); the email
    //   itself is not stored (EmailKey is an HMAC too).
    // - 10-minute expiry, single use, 5 wrong attempts per code (atomic).
    // - Aggregate budget per email: 10 failed attempts in a rolling hour across all
    //   codes and both purposes — a new code never resets it. Per IP: 20 (IpFailureWindow).
    // - Request limits per email and purpose: 1 per 60 s, 5 per hour.
    // - Success returns a proof token (single use, 15 min, stored as HMAC) that
    //   sign-up / reset must present.
    // - Unknown emails get a decoy row (a code nobody receives), so attempts and
    //   limits behave exactly as for real accounts.
    // ============================================================
    public class OneTimeCodeService
    {
        public const int MaxAttemptsPerCode = 5;
        public const int MaxFailuresPerEmailPerHour = 10;
        public const int MaxRequestsPerEmailPerHour = 5;
        public static readonly TimeSpan CodeLifetime = TimeSpan.FromMinutes(10);
        public static readonly TimeSpan ProofLifetime = TimeSpan.FromMinutes(15);
        public static readonly TimeSpan RequestCooldown = TimeSpan.FromSeconds(60);

        // A code is verifiable for 10 minutes, so every failure of the last hour sits on a row created
        // in the last 70 minutes. Counting those rows is conservative, never lenient.
        private static readonly TimeSpan FailureLookback = TimeSpan.FromMinutes(70);

        private readonly AppDbContext _db;
        private readonly SecurityKeys _keys;
        private readonly IpFailureWindow _ipFailures;
        private readonly SecurityEventFactory _events;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;

        public OneTimeCodeService(AppDbContext db, SecurityKeys keys, IpFailureWindow ipFailures, SecurityEventFactory events,
            TimeProvider time, ILoggerFactory loggers)
        {
            _db = db;
            _keys = keys;
            _ipFailures = ipFailures;
            _events = events;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        private byte[] CodeHash(string purpose, byte[] emailKey, string code) =>
            _keys.Hmac("code", $"{purpose}|{Convert.ToHexString(emailKey)}|{code}");

        private byte[] ProofHash(string proofToken) => _keys.Hmac("proof", proofToken);

        private static string IpKey(HttpContext http) => http.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        // Creates a code (always — a decoy when the caller will not send it). The caller decides what to email.
        public async Task<CodeRequestResult> RequestAsync(string normalizedEmail, string purpose, HttpContext http, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var emailKey = _keys.CodeEmailKey(normalizedEmail);

            // Request limits count per purpose; the failure budget (VerifyAsync) spans both.
            var recent = await _db.OneTimeCodes.AsNoTracking()
                .Where(c => c.EmailKey == emailKey && c.Purpose == purpose && c.CreatedAt > now.AddHours(-1))
                .Select(c => c.CreatedAt)
                .ToListAsync(cancellationToken);
            if (recent.Count > 0 && now - recent.Max() < RequestCooldown)
            {
                return new CodeRequestResult(CodeRequestOutcome.RateLimited, RetryAfter: recent.Max() + RequestCooldown - now);
            }

            if (recent.Count >= MaxRequestsPerEmailPerHour)
            {
                return new CodeRequestResult(CodeRequestOutcome.RateLimited, RetryAfter: recent.Min().AddHours(1) - now);
            }

            // A new code replaces earlier ones of this purpose — and their proof tokens.
            await _db.OneTimeCodes
                .Where(c => c.EmailKey == emailKey && c.Purpose == purpose && c.InvalidatedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.InvalidatedAt, now), cancellationToken);

            var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            _db.OneTimeCodes.Add(new OneTimeCode
            {
                Purpose = purpose,
                EmailKey = emailKey,
                CodeHash = CodeHash(purpose, emailKey, code),
                CreatedAt = now,
                ExpiresAt = now + CodeLifetime
            });
            _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.CodeRequested, SecurityEventOutcome.Success, now,
                reason: purpose, email: normalizedEmail));
            await _db.SaveChangesAsync(cancellationToken);

            return new CodeRequestResult(CodeRequestOutcome.Issued, code);
        }

        public async Task<CodeVerifyResult> VerifyAsync(string normalizedEmail, string purpose, string? code, HttpContext http, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var emailKey = _keys.CodeEmailKey(normalizedEmail);
            var ip = IpKey(http);

            // Aggregate budgets first (C6): per IP, then per email across all codes.
            if (_ipFailures.BlockedFor(ip, now) is { } ipRetry)
            {
                await RateLimitedEventAsync(http, now, normalizedEmail, "CodeFailuresPerIp", cancellationToken);
                return new CodeVerifyResult(CodeVerifyOutcome.RateLimited, RetryAfter: ipRetry);
            }

            var failures = await _db.OneTimeCodes.AsNoTracking()
                .Where(c => c.EmailKey == emailKey && c.CreatedAt > now - FailureLookback)
                .SumAsync(c => c.FailedAttempts, cancellationToken);
            if (failures >= MaxFailuresPerEmailPerHour)
            {
                await RateLimitedEventAsync(http, now, normalizedEmail, "CodeFailuresPerEmail", cancellationToken);
                return new CodeVerifyResult(CodeVerifyOutcome.RateLimited, RetryAfter: TimeSpan.FromHours(1));
            }

            var row = await _db.OneTimeCodes.AsNoTracking()
                .Where(c => c.EmailKey == emailKey && c.Purpose == purpose && c.ConsumedAt == null && c.InvalidatedAt == null &&
                            c.ExpiresAt > now && c.FailedAttempts < MaxAttemptsPerCode)
                .OrderByDescending(c => c.CreatedAt)
                .FirstOrDefaultAsync(cancellationToken);

            var presented = (code ?? string.Empty).Trim();
            if (row == null)
            {
                _ipFailures.RecordFailure(ip, now);
                return new CodeVerifyResult(CodeVerifyOutcome.Invalid);
            }

            if (presented.Length != 6 || !CryptographicOperations.FixedTimeEquals(CodeHash(purpose, emailKey, presented), row.CodeHash))
            {
                _ipFailures.RecordFailure(ip, now);

                // Atomic: parallel wrong guesses can never exceed 5. The 5th destroys the code.
                await _db.OneTimeCodes
                    .Where(c => c.Id == row.Id && c.ConsumedAt == null && c.InvalidatedAt == null && c.FailedAttempts < MaxAttemptsPerCode)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(c => c.InvalidatedAt, c => c.FailedAttempts + 1 >= MaxAttemptsPerCode ? now : c.InvalidatedAt)
                        .SetProperty(c => c.FailedAttempts, c => c.FailedAttempts + 1), cancellationToken);

                var attempts = await _db.OneTimeCodes.AsNoTracking().Where(c => c.Id == row.Id).Select(c => c.FailedAttempts).FirstAsync(cancellationToken);
                if (attempts >= MaxAttemptsPerCode)
                {
                    _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.CodeAttemptsExceeded, SecurityEventOutcome.Blocked, now,
                        reason: purpose, email: normalizedEmail));
                    await _db.SaveChangesAsync(cancellationToken);
                    _logger.LogWarning("Auth.CodeAttemptsExceeded {Purpose}", purpose);
                    return new CodeVerifyResult(CodeVerifyOutcome.AttemptsExceeded);
                }

                return new CodeVerifyResult(CodeVerifyOutcome.Invalid);
            }

            // Correct: consume once and hand out a proof token.
            var proof = Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(32));
            var proofHash = ProofHash(proof);
            var consumed = await _db.OneTimeCodes
                .Where(c => c.Id == row.Id && c.ConsumedAt == null && c.InvalidatedAt == null && c.FailedAttempts < MaxAttemptsPerCode && c.ExpiresAt > now)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(c => c.ConsumedAt, now)
                    .SetProperty(c => c.ProofTokenHash, proofHash)
                    .SetProperty(c => c.ProofExpiresAt, now + ProofLifetime), cancellationToken);

            return consumed == 1
                ? new CodeVerifyResult(CodeVerifyOutcome.Verified, proof)
                : new CodeVerifyResult(CodeVerifyOutcome.Invalid);
        }

        // Single use: true only for an unused, unexpired proof issued for this email and purpose.
        public async Task<bool> ConsumeProofAsync(string normalizedEmail, string purpose, string proofToken, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var emailKey = _keys.CodeEmailKey(normalizedEmail);
            var proofHash = ProofHash(proofToken.Trim());

            return await _db.OneTimeCodes
                .Where(c => c.ProofTokenHash == proofHash && c.EmailKey == emailKey && c.Purpose == purpose &&
                            c.ProofConsumedAt == null && c.InvalidatedAt == null && c.ProofExpiresAt > now)
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.ProofConsumedAt, now), cancellationToken) == 1;
        }

        // Development fallback only (C1 case 2): the unchanged app never sends the proof token, so the
        // latest still-valid proof of this email and purpose is consumed on its behalf.
        public async Task<bool> ConsumeLatestProofWithoutTokenAsync(string normalizedEmail, string purpose, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow().UtcDateTime;
            var emailKey = _keys.CodeEmailKey(normalizedEmail);

            var id = await _db.OneTimeCodes.AsNoTracking()
                .Where(c => c.EmailKey == emailKey && c.Purpose == purpose && c.ProofTokenHash != null &&
                            c.ProofConsumedAt == null && c.InvalidatedAt == null && c.ProofExpiresAt > now)
                .OrderByDescending(c => c.ConsumedAt)
                .Select(c => (long?)c.Id)
                .FirstOrDefaultAsync(cancellationToken);
            if (id == null)
            {
                return false;
            }

            return await _db.OneTimeCodes
                .Where(c => c.Id == id && c.ProofConsumedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.ProofConsumedAt, now), cancellationToken) == 1;
        }

        private async Task RateLimitedEventAsync(HttpContext http, DateTime now, string normalizedEmail, string reason, CancellationToken cancellationToken)
        {
            _db.SecurityEvents.Add(_events.Create(http, SecurityEventTypes.RateLimited, SecurityEventOutcome.Blocked, now,
                reason: reason, email: normalizedEmail));
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogWarning("Auth.RateLimited {Reason}", reason);
        }
    }
}
