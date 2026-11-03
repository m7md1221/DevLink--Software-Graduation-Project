using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;
using Services;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IEmailSender _emailService;
        private readonly VerificationService _verificationService;
        private readonly GoogleAuthService _googleAuthService;
        private readonly PasswordService _passwordService;

        public AuthController(
            AppDbContext context,
            IEmailSender emailService,
            VerificationService verificationService,
            GoogleAuthService googleAuthService,
            PasswordService passwordService)
        {
            _context = context;
            _emailService = emailService;
            _verificationService = verificationService;
            _googleAuthService = googleAuthService;
            _passwordService = passwordService;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login(
            [FromBody] LoginDto model)
        {
            var email = model.Email.Trim().ToLower();

            var user = await _context.Users
                .FirstOrDefaultAsync(u =>
                    u.Email == email &&
                    u.UserType == model.UserType);

            var check = user == null
                ? PasswordCheckResult.Failed
                : _passwordService.Verify(user, user.PasswordHash, model.Password);

            if (user == null || check == PasswordCheckResult.Failed)
            {
                return Unauthorized(new
                {
                    message = "Invalid email or password"
                });
            }

            // ✅ ترقية كلمات المرور القديمة (نص عادي) إلى hash عند أول دخول ناجح
            if (check == PasswordCheckResult.SuccessRehashNeeded)
            {
                user.PasswordHash = _passwordService.Hash(user, model.Password);
                await _context.SaveChangesAsync();
            }

            var hasCustomerProfile = await _context.CustomerProfiles
                .AnyAsync(p => p.UserId == user.Id);

            var hasProgrammerProfile = await _context.ProgrammerProfiles
                .AnyAsync(p => p.UserId == user.Id);

            return Ok(new
            {
                message = "Login successful",
                userId = user.Id,
                userType = user.UserType,
                email = user.Email,
                hasProfile = hasCustomerProfile,
                hasProgrammerProfile = hasProgrammerProfile
            });
        }

        // ============================================================
        // GOOGLE SIGN-IN
        // ============================================================
        [HttpPost("google-login")]
        public async Task<IActionResult> GoogleLogin(
            [FromBody] GoogleLoginDto model)
        {
            if (string.IsNullOrWhiteSpace(model.IdToken) ||
                string.IsNullOrWhiteSpace(model.UserType))
            {
                return BadRequest(new
                {
                    message = "idToken and userType are required"
                });
            }

            if (model.UserType != "Customer" &&
                model.UserType != "Programmer")
            {
                return BadRequest(new
                {
                    message = "Invalid user type"
                });
            }

            var googleUser = await _googleAuthService
                .VerifyIdToken(model.IdToken);

            if (googleUser == null)
            {
                return Unauthorized(new
                {
                    message = "Invalid Google token"
                });
            }

            var email = googleUser.Email.Trim().ToLower();

            var existingUser = await _context.Users
                .FirstOrDefaultAsync(u => u.Email == email);

            // ===== مستخدم موجود =====
            if (existingUser != null)
            {
                var hasCustomerProfile = await _context.CustomerProfiles
                    .AnyAsync(p => p.UserId == existingUser.Id);

                var hasProgrammerProfile = await _context.ProgrammerProfiles
                    .AnyAsync(p => p.UserId == existingUser.Id);

                return Ok(new
                {
                    message = "Login successful",
                    isNewUser = false,
                    userId = existingUser.Id,
                    userType = existingUser.UserType,
                    email = existingUser.Email,
                    hasProfile = hasCustomerProfile,
                    hasProgrammerProfile = hasProgrammerProfile
                });
            }

            // ===== مستخدم جديد =====
            // ✅ إذا جاء من Login، نرفض (بدو يسجل أولاً)
            if (model.Mode == "login")
            {
                return BadRequest(new
                {
                    message = "No account found with this email. Please sign up first.",
                    requiresSignUp = true
                });
            }

            // ✅ إذا جاء من SignUp، ننشئ الحساب
            var newUser = new User
            {
                Email = email,
                UserType = model.UserType
            };

            // Google accounts get an unusable random password (hashed, never shown).
            newUser.PasswordHash = _passwordService.Hash(
                newUser,
                Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32)));

            _context.Users.Add(newUser);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Account created successfully",
                isNewUser = true,
                userId = newUser.Id,
                userType = newUser.UserType,
                email = newUser.Email,
                hasProfile = false,
                hasProgrammerProfile = false
            });
        }

        [HttpPost("send-code")]
        public async Task<IActionResult> SendCode(
            [FromBody] SendCodeDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email))
            {
                return BadRequest(new
                {
                    message = "Email is required"
                });
            }

            var email = model.Email.Trim().ToLower();

            var emailExists = await _context.Users
                .AnyAsync(u => u.Email == email);

            if (emailExists)
            {
                return BadRequest(new
                {
                    message = "This email is already registered"
                });
            }

            var code = _verificationService.CreateCode(email, "signup");

            var sent = _emailService.SendEmail(
                email,
                "DevLink Email Verification",
                $"Your DevLink verification code is: {code}"
            );

            if (!sent)
            {
                return StatusCode(500, new
                {
                    message = "Failed to send verification email"
                });
            }

            return Ok(new
            {
                message = "Verification code sent",
                expiresInMinutes = 5
            });
        }

        [HttpPost("verify-code")]
        public IActionResult VerifyCode(
            [FromBody] VerifyCodeDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) ||
                string.IsNullOrWhiteSpace(model.Code))
            {
                return BadRequest(new
                {
                    message = "Email and code are required"
                });
            }

            var verified = _verificationService.VerifyCode(
                model.Email, model.Code, "signup");

            if (!verified)
            {
                return BadRequest(new
                {
                    message = "Invalid or expired verification code"
                });
            }

            return Ok(new
            {
                message = "Email verified successfully"
            });
        }

        [HttpPost("signup")]
        public async Task<IActionResult> SignUp(
            [FromBody] SignUpDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) ||
                string.IsNullOrWhiteSpace(model.Password) ||
                string.IsNullOrWhiteSpace(model.UserType))
            {
                return BadRequest(new
                {
                    message = "All fields are required"
                });
            }

            if (model.UserType != "Customer" &&
                model.UserType != "Programmer")
            {
                return BadRequest(new
                {
                    message = "Invalid user type"
                });
            }

            var passwordError = _passwordService.ValidatePolicy(model.Password);

            if (passwordError != null)
            {
                return BadRequest(new
                {
                    message = passwordError
                });
            }

            var email = model.Email.Trim().ToLower();

            if (!_verificationService.IsEmailVerified(email))
            {
                return BadRequest(new
                {
                    message =
                        "Email is not verified. Please verify your email first."
                });
            }

            var emailExists = await _context.Users
                .AnyAsync(u => u.Email == email);

            if (emailExists)
            {
                return BadRequest(new
                {
                    message = "This email is already registered"
                });
            }

            var user = new User
            {
                Email = email,
                UserType = model.UserType
            };

            user.PasswordHash = _passwordService.Hash(user, model.Password);

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _verificationService.ConsumeVerifiedEmail(email);

            return Ok(new
            {
                message = "Account created successfully",
                userId = user.Id,
                userType = user.UserType
            });
        }

        [HttpPost("send-reset-code")]
        public async Task<IActionResult> SendResetCode(
            [FromBody] SendCodeDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email))
            {
                return BadRequest(new
                {
                    message = "Email is required"
                });
            }

            var email = model.Email.Trim().ToLower();

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Email == email);

            if (user == null)
            {
                return BadRequest(new
                {
                    message = "This email is not registered"
                });
            }

            var code =
                _verificationService.CreateCode(email, "reset");

            var sent = _emailService.SendEmail(
                email,
                "DevLink Password Reset",
                $"Your DevLink password reset code is: {code}"
            );

            if (!sent)
            {
                return StatusCode(500, new
                {
                    message = "Failed to send reset email"
                });
            }

            return Ok(new
            {
                message = "Reset code sent",
                expiresInMinutes = 5
            });
        }

        [HttpPost("verify-reset-code")]
        public IActionResult VerifyResetCode(
            [FromBody] VerifyCodeDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) ||
                string.IsNullOrWhiteSpace(model.Code))
            {
                return BadRequest(new
                {
                    message = "Email and code are required"
                });
            }

            var verified = _verificationService.VerifyCode(
                model.Email, model.Code, "reset");

            if (!verified)
            {
                return BadRequest(new
                {
                    message = "Invalid or expired reset code"
                });
            }

            return Ok(new
            {
                message = "Reset code verified"
            });
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword(
            [FromBody] ResetPasswordDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) ||
                string.IsNullOrWhiteSpace(model.NewPassword))
            {
                return BadRequest(new
                {
                    message = "Email and new password are required"
                });
            }

            var passwordError = _passwordService.ValidatePolicy(model.NewPassword);

            if (passwordError != null)
            {
                return BadRequest(new
                {
                    message = passwordError
                });
            }

            var email = model.Email.Trim().ToLower();

            if (!_verificationService.IsEmailVerifiedForReset(email))
            {
                return BadRequest(new
                {
                    message =
                        "Email is not verified. Please verify the reset code first."
                });
            }

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Email == email);

            if (user == null)
            {
                return BadRequest(new
                {
                    message = "User not found"
                });
            }

            user.PasswordHash = _passwordService.Hash(user, model.NewPassword);
            await _context.SaveChangesAsync();

            _verificationService.ConsumeVerifiedResetEmail(email);

            return Ok(new
            {
                message = "Password reset successfully"
            });
        }
    }

    public class LoginDto
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string UserType { get; set; } = string.Empty;
    }

    public class GoogleLoginDto
    {
        public string IdToken { get; set; } = string.Empty;
        public string UserType { get; set; } = string.Empty;
        public string Mode { get; set; } = "signup"; // signup / login
    }

    public class SendCodeDto
    {
        public string Email { get; set; } = string.Empty;
    }

    public class VerifyCodeDto
    {
        public string Email { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }

    public class SignUpDto
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string UserType { get; set; } = string.Empty;
    }

    public class ResetPasswordDto
    {
        public string Email { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}