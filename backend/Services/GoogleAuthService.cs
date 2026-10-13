using Google.Apis.Auth;

namespace Services
{
    public class GoogleAuthService
    {
        private readonly string _clientId;

        public GoogleAuthService(IConfiguration config)
        {
            _clientId = config["Google:ClientId"] 
                ?? throw new Exception("Google ClientId missing");
        }

        // التحقق من idToken وإرجاع بيانات المستخدم
        public async Task<GoogleUserInfo?> VerifyIdToken(string idToken)
        {
            try
            {
                var settings = new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = new[] { _clientId }
                };

                var payload = await GoogleJsonWebSignature.ValidateAsync(
                    idToken,
                    settings
                );

                return new GoogleUserInfo
                {
                    Email = payload.Email,
                    Name = payload.Name,
                    Picture = payload.Picture,
                    GoogleId = payload.Subject
                };
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️ Google token verification failed: {ex.Message}");
                return null;
            }
        }
    }

    public class GoogleUserInfo
    {
        public string Email { get; set; } = string.Empty;
        public string? Name { get; set; }
        public string? Picture { get; set; }
        public string GoogleId { get; set; } = string.Empty;
    }
}