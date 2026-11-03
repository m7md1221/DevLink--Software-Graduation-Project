using DataBase;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace Services.Auth
{
    // What the per-request check needs for one user (M2_AUTH_DESIGN §3.7, condition C2).
    public sealed record SessionState(string Status, string SecurityStamp, IReadOnlyDictionary<Guid, DateTime> ActiveSessions);

    public enum SessionCheck
    {
        Valid,
        Revoked,
        Unavailable
    }

    public sealed record SessionValidationResult(SessionCheck Check, string? UserStatus = null);

    public interface ISessionValidator
    {
        Task<SessionValidationResult> ValidateAsync(int userId, string securityStamp, Guid sessionId, CancellationToken cancellationToken);
    }

    // ============================================================
    // Per-process cache of SessionState, 30 s maximum age, cleared
    // synchronously by Invalidate() after every security write made
    // through this API. Single instance only (§3.7).
    // ============================================================
    public class SessionStateCache
    {
        public static readonly TimeSpan MaxAge = TimeSpan.FromSeconds(30);

        private sealed record Entry(SessionState? State, DateTimeOffset LoadedAt);

        private readonly IMemoryCache _cache;
        private readonly IServiceScopeFactory _scopes;
        private readonly TimeProvider _time;
        private readonly object _sync = new();
        private readonly Dictionary<int, long> _generations = new();

        public SessionStateCache(IMemoryCache cache, IServiceScopeFactory scopes, TimeProvider time)
        {
            _cache = cache;
            _scopes = scopes;
            _time = time;
        }

        private static string Key(int userId) => $"devlink:session-state:{userId}";

        public async Task<SessionState?> GetAsync(int userId, CancellationToken cancellationToken)
        {
            var now = _time.GetUtcNow();
            if (_cache.TryGetValue(Key(userId), out Entry? cached) && cached != null && now - cached.LoadedAt <= MaxAge)
            {
                return cached.State;
            }

            long generation;
            lock (_sync)
            {
                generation = _generations.GetValueOrDefault(userId);
            }

            // A cache miss always reads the database; failures propagate (fail closed, never "assume valid").
            var state = await LoadAsync(userId, now.UtcDateTime, cancellationToken);

            lock (_sync)
            {
                // A write that invalidated this user while we were loading wins: don't store stale data.
                if (_generations.GetValueOrDefault(userId) == generation)
                {
                    _cache.Set(Key(userId), new Entry(state, now), MaxAge);
                }
            }

            return state;
        }

        public void Invalidate(int userId)
        {
            lock (_sync)
            {
                _generations[userId] = _generations.GetValueOrDefault(userId) + 1;
                _cache.Remove(Key(userId));
            }
        }

        private async Task<SessionState?> LoadAsync(int userId, DateTime now, CancellationToken cancellationToken)
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var user = await db.Users.AsNoTracking()
                .Where(u => u.Id == userId)
                .Select(u => new { u.Status, u.SecurityStamp })
                .FirstOrDefaultAsync(cancellationToken);
            if (user == null)
            {
                return null;
            }

            var sessions = await db.AuthSessions.AsNoTracking()
                .Where(s => s.UserId == userId && s.Status == AuthSessionStatus.Active && s.AbsoluteExpiresAt > now)
                .Select(s => new { s.Id, s.AbsoluteExpiresAt })
                .ToDictionaryAsync(s => s.Id, s => s.AbsoluteExpiresAt, cancellationToken);

            return new SessionState(user.Status, user.SecurityStamp, sessions);
        }
    }

    // Checks, for a token that already passed signature/lifetime validation:
    // user exists, sstamp == SecurityStamp, sid is an Active, unexpired session. Status is returned for the suspended gate.
    public class SessionValidator : ISessionValidator
    {
        private readonly SessionStateCache _cache;
        private readonly TimeProvider _time;
        private readonly ILogger _logger;

        public SessionValidator(SessionStateCache cache, TimeProvider time, ILoggerFactory loggers)
        {
            _cache = cache;
            _time = time;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        public async Task<SessionValidationResult> ValidateAsync(int userId, string securityStamp, Guid sessionId, CancellationToken cancellationToken)
        {
            SessionState? state;
            try
            {
                state = await _cache.GetAsync(userId, cancellationToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError("Auth.SessionCheckUnavailable {FailureType}", ex.GetType().Name);
                return new SessionValidationResult(SessionCheck.Unavailable);
            }

            if (state == null ||
                !string.Equals(state.SecurityStamp, securityStamp, StringComparison.Ordinal) ||
                !state.ActiveSessions.TryGetValue(sessionId, out var expiresAt) ||
                expiresAt <= _time.GetUtcNow().UtcDateTime)
            {
                return new SessionValidationResult(SessionCheck.Revoked);
            }

            return new SessionValidationResult(SessionCheck.Valid, state.Status);
        }
    }

    public class SessionRevokedException : Exception
    {
        public SessionRevokedException() : base("The session is no longer valid.")
        {
        }
    }

    public class SessionCheckUnavailableException : Exception
    {
        public SessionCheckUnavailableException() : base("The session could not be verified.")
        {
        }
    }

    public static class AuthHttpItems
    {
        public const string UserStatus = "DevLink.UserStatus";
    }
}
