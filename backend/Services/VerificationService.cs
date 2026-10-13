using System.Collections.Concurrent;

namespace Services
{
    public class VerificationService
    {
        private static readonly
            ConcurrentDictionary<string, VerificationData> Codes = new();

        private static readonly
            ConcurrentDictionary<string, DateTime> VerifiedEmails = new();

        private static readonly
            ConcurrentDictionary<string, DateTime> VerifiedResetEmails = new();

        public string CreateCode(string email, string purpose = "signup")
        {
            email = email.ToLower();

            string code =
                Random.Shared
                    .Next(100000, 1000000)
                    .ToString();

            Codes[$"{email}|{purpose}"] = new VerificationData
            {
                Code = code,
                Expiry = DateTime.UtcNow.AddMinutes(5)
            };

            Console.WriteLine($"💾 [CreateCode] Key: {email}|{purpose}");
            Console.WriteLine($"💾 [CreateCode] Code: {code}");
            Console.WriteLine($"💾 [CreateCode] Total codes in memory: {Codes.Count}");

            return code;
        }

        public bool VerifyCode(
            string email,
            string code,
            string purpose = "signup")
        {
            email = email.ToLower();
            var key = $"{email}|{purpose}";

            Console.WriteLine($"🔍 [VerifyCode] Looking for key: {key}");
            Console.WriteLine($"🔍 [VerifyCode] Code received: {code}");
            Console.WriteLine($"🔍 [VerifyCode] Total codes in memory: {Codes.Count}");

            if (!Codes.TryGetValue(key, out var data))
            {
                Console.WriteLine($"❌ [VerifyCode] Key NOT found!");
                return false;
            }

            Console.WriteLine($"✅ [VerifyCode] Key found. Stored code: {data.Code}");
            Console.WriteLine($"⏰ [VerifyCode] Expiry: {data.Expiry}, Now: {DateTime.UtcNow}");

            if (DateTime.UtcNow > data.Expiry)
            {
                Console.WriteLine($"❌ [VerifyCode] Code expired!");
                Codes.TryRemove(key, out _);
                return false;
            }

            if (data.Code != code)
            {
                Console.WriteLine($"❌ [VerifyCode] Code mismatch!");
                return false;
            }

            Codes.TryRemove(key, out _);

            Console.WriteLine($"✅ [VerifyCode] SUCCESS!");

            if (purpose == "reset")
            {
                VerifiedResetEmails[email] =
                    DateTime.UtcNow.AddMinutes(30);
            }
            else
            {
                VerifiedEmails[email] =
                    DateTime.UtcNow.AddMinutes(30);
            }

            return true;
        }

        public bool IsEmailVerified(string email)
        {
            email = email.ToLower();

            if (!VerifiedEmails.TryGetValue(email, out var expiry))
            {
                return false;
            }

            if (DateTime.UtcNow > expiry)
            {
                VerifiedEmails.TryRemove(email, out _);
                return false;
            }

            return true;
        }

        public bool IsEmailVerifiedForReset(string email)
        {
            email = email.ToLower();

            if (!VerifiedResetEmails.TryGetValue(email, out var expiry))
            {
                return false;
            }

            if (DateTime.UtcNow > expiry)
            {
                VerifiedResetEmails.TryRemove(email, out _);
                return false;
            }

            return true;
        }

        public void ConsumeVerifiedEmail(string email)
        {
            VerifiedEmails.TryRemove(email.ToLower(), out _);
        }

        public void ConsumeVerifiedResetEmail(string email)
        {
            VerifiedResetEmails.TryRemove(email.ToLower(), out _);
        }

        private class VerificationData
        {
            public string Code { get; set; }
            public DateTime Expiry { get; set; }
        }
    }
}