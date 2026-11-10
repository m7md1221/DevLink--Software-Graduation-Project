using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using DataBase;

namespace Services.Security
{
    public static class SecurityEventTypes
    {
        public const string LoginSucceeded = "Auth.LoginSucceeded";
        public const string LoginFailed = "Auth.LoginFailed";
        public const string LockedOut = "Auth.LockedOut";
        public const string RefreshTokenReuse = "Auth.RefreshTokenReuse";
        public const string EndedSessionTokenPresented = "Auth.EndedSessionTokenPresented";
        public const string CsrfRejected = "Auth.CsrfRejected";
        public const string Logout = "Auth.Logout";
        public const string LogoutAll = "Auth.LogoutAll";
        public const string CodeRequested = "Auth.CodeRequested";
        public const string CodeAttemptsExceeded = "Auth.CodeAttemptsExceeded";
        public const string RateLimited = "Auth.RateLimited";
        public const string PasswordReset = "Auth.PasswordReset";
        public const string AccountCreated = "Auth.AccountCreated";
        public const string ReuseAlertQueued = "Auth.ReuseAlertQueued";
        public const string AdminUserSuspended = "Admin.UserSuspended";
        public const string AdminUserUnsuspended = "Admin.UserUnsuspended";
        public const string AdminUserDeleted = "Admin.UserDeleted";
        public const string FileDownloaded = "Files.Downloaded";
        public const string GoogleLogin = "Auth.GoogleLogin";
        public const string GoogleLinkRequired = "Auth.GoogleLinkRequired";
        public const string GoogleLinked = "Auth.GoogleLinked";

        // R3: the only events that may carry a (truncated) IP prefix.
        public static readonly IReadOnlySet<string> WithIpPrefix = new HashSet<string>
        {
            LoginFailed, LockedOut, RateLimited, CsrfRejected, CodeAttemptsExceeded, RefreshTokenReuse
        };
    }

    // Truncated network prefix for abuse correlation (R3): IPv4 /24, IPv6 /48. Full addresses are never stored.
    public static class IpPrefix
    {
        public static string? From(IPAddress? address)
        {
            if (address == null)
            {
                return null;
            }

            if (address.IsIPv4MappedToIPv6)
            {
                address = address.MapToIPv4();
            }

            var bytes = address.GetAddressBytes();
            if (address.AddressFamily == AddressFamily.InterNetwork)
            {
                return $"{bytes[0]}.{bytes[1]}.{bytes[2]}.0/24";
            }

            if (address.AddressFamily == AddressFamily.InterNetworkV6)
            {
                var prefix = new byte[16];
                Array.Copy(bytes, prefix, 6);
                return $"{new IPAddress(prefix)}/48";
            }

            return null;
        }
    }

    // Builds SecurityEvent rows from typed inputs only — callers cannot pass tokens, passwords, codes or emails (§6.4).
    // An email, when given, is stored only as a 12-hex keyed hash (EmailKey) for correlation.
    public class SecurityEventFactory
    {
        private readonly SecurityKeys _keys;

        public SecurityEventFactory(SecurityKeys keys)
        {
            _keys = keys;
        }

        public SecurityEvent Create(
            HttpContext context,
            string eventType,
            string outcome,
            DateTime occurredAt,
            int? userId = null,
            Guid? sessionId = null,
            string? reason = null,
            string? clientType = null,
            string? email = null)
        {
            return new SecurityEvent
            {
                OccurredAt = occurredAt,
                EventType = eventType,
                Outcome = outcome,
                UserId = userId,
                SessionId = sessionId,
                ClientType = clientType,
                EmailKey = string.IsNullOrWhiteSpace(email) ? null : _keys.LogEmailKey(SecurityKeys.NormalizeEmail(email)),
                IpPrefix = SecurityEventTypes.WithIpPrefix.Contains(eventType)
                    ? IpPrefix.From(context.Connection.RemoteIpAddress)
                    : null,
                TraceId = Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier,
                Details = reason == null ? null : JsonSerializer.Serialize(new { reason })
            };
        }
    }
}
