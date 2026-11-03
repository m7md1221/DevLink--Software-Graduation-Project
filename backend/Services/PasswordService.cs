using System.Security.Cryptography;
using System.Text;
using DataBase;
using Microsoft.AspNetCore.Identity;

namespace Services
{
    public enum PasswordCheckResult
    {
        Failed,
        Success,
        SuccessRehashNeeded
    }

    // ============================================================
    // Password hashing with ASP.NET Core Identity's PasswordHasher
    // (PBKDF2). Accounts created before hashing was introduced still
    // hold plaintext values: they are verified once in constant time
    // and must then be re-hashed by the caller (SuccessRehashNeeded).
    // ============================================================
    public class PasswordService
    {
        private readonly PasswordHasher<User> _hasher = new();

        public PasswordService(IConfiguration configuration)
        {
            MinLength = configuration.GetValue("Auth:MinPasswordLength", 6);
        }

        public int MinLength { get; }

        public string? ValidatePolicy(string password)
        {
            if (string.IsNullOrEmpty(password) || password.Length < MinLength)
            {
                return $"Password must be at least {MinLength} characters";
            }

            if (password.Length > 128)
            {
                return "Password must be at most 128 characters";
            }

            return null;
        }

        public string Hash(User user, string password)
        {
            return _hasher.HashPassword(user, password);
        }

        public PasswordCheckResult Verify(User user, string storedValue, string providedPassword)
        {
            if (string.IsNullOrEmpty(storedValue) || string.IsNullOrEmpty(providedPassword))
            {
                return PasswordCheckResult.Failed;
            }

            if (IsIdentityHash(storedValue))
            {
                return _hasher.VerifyHashedPassword(user, storedValue, providedPassword) switch
                {
                    PasswordVerificationResult.Success => PasswordCheckResult.Success,
                    PasswordVerificationResult.SuccessRehashNeeded => PasswordCheckResult.SuccessRehashNeeded,
                    _ => PasswordCheckResult.Failed
                };
            }

            // Legacy plaintext value (accounts created before hashing).
            var stored = Encoding.UTF8.GetBytes(storedValue);
            var provided = Encoding.UTF8.GetBytes(providedPassword);

            return CryptographicOperations.FixedTimeEquals(stored, provided)
                ? PasswordCheckResult.SuccessRehashNeeded
                : PasswordCheckResult.Failed;
        }

        // Recognises the Identity hash formats: v3 (0x01 marker) and v2 (0x00, 49 bytes).
        public static bool IsIdentityHash(string value)
        {
            var buffer = new byte[value.Length];

            if (!Convert.TryFromBase64String(value, buffer, out var length) || length == 0)
            {
                return false;
            }

            if (buffer[0] == 0x01)
            {
                return length >= 61;
            }

            return buffer[0] == 0x00 && length == 49;
        }
    }
}
