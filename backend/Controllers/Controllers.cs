using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;
using Services;
using Services.Auth;
using Services.Security;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [AllowSuspended] // sign-in flows and the suspension notice stay reachable for suspended accounts (§7.4)
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IEmailSender _emailService;
        private readonly VerificationService _verificationService;
        private readonly GoogleAuthService _googleAuthService;
        private readonly PasswordService _passwordService;
        private readonly LoginService _loginService;
        private readonly RefreshSessionService _refreshSessions;
        private readonly CookieSessionGuard _cookieGuard;
        private readonly SecurityEventFactory _events;
        private readonly TimeProvider _time;

        public AuthController(
            AppDbContext context,
            IEmailSender emailService,
            VerificationService verificationService,
            GoogleAuthService googleAuthService,
            PasswordService passwordService,
            LoginService loginService,
            RefreshSessionService refreshSessions,
            CookieSessionGuard cookieGuard,
            SecurityEventFactory events,
            TimeProvider time)
        {
            _context = context;
            _emailService = emailService;
            _verificationService = verificationService;
            _googleAuthService = googleAuthService;
            _passwordService = passwordService;
            _loginService = loginService;
            _refreshSessions = refreshSessions;
            _cookieGuard = cookieGuard;
            _events = events;
            _time = time;
        }

        // Response keeps every pre-M2.4a field (message, userId, userType, email, hasProfile,
        // hasProgrammerProfile); everything else is an addition.
        // Refresh token by client mode (X-DevLink-Client): "web" → HttpOnly cookie (CSRF-guarded),
        // "mobile" → response body, no header (today's app) → none, exactly as in M2.4a.
        [HttpPost("login")]
        public async Task<IActionResult> Login(
            [FromBody] LoginDto model,
            CancellationToken cancellationToken)
        {
            var csrf = _cookieGuard.Check(Request);
            if (!csrf.Allowed)
            {
                return await CsrfRejectedAsync(csrf, cancellationToken);
            }

            var clientType = csrf.Mode == ClientMode.Mobile ? AuthClientType.Mobile : AuthClientType.Web;

            var result = await _loginService.LoginAsync(
                model.Email, model.Password, model.UserType, clientType,
                issueRefreshToken: csrf.Mode != ClientMode.Legacy, HttpContext, cancellationToken);

            if (result.Outcome == LoginOutcome.LockedOut)
            {
                Response.Headers.RetryAfter = Math.Max(1, (int)Math.Ceiling(result.RetryAfter!.Value.TotalSeconds)).ToString();
                return AuthError(StatusCodes.Status429TooManyRequests, AuthErrorCodes.AccountLocked,
                    "Too many failed sign-in attempts. Try again in 15 minutes or reset your password.");
            }

            if (result.Outcome != LoginOutcome.Success)
            {
                return AuthError(StatusCodes.Status401Unauthorized, AuthErrorCodes.InvalidCredentials,
                    "Email or password is incorrect.");
            }

            var user = result.User!;

            var hasCustomerProfile = await _context.CustomerProfiles
                .AnyAsync(p => p.UserId == user.Id, cancellationToken);

            var hasProgrammerProfile = await _context.ProgrammerProfiles
                .AnyAsync(p => p.UserId == user.Id, cancellationToken);

            if (result.RefreshToken != null && csrf.Mode == ClientMode.Web)
            {
                RefreshCookie.Append(Response, result.RefreshToken, _time.GetUtcNow().UtcDateTime);
            }

            return Ok(new
            {
                message = "Login successful",
                userId = user.Id,
                userType = user.UserType,
                email = user.Email,
                hasProfile = hasCustomerProfile,
                hasProgrammerProfile = hasProgrammerProfile,
                accessToken = result.Token!.Token,
                accessTokenExpiresAt = result.Token.ExpiresAtUtc,
                role = user.UserType,
                status = user.Status,
                refreshTokenExpiresAt = result.RefreshToken?.ExpiresAt,
                refreshToken = csrf.Mode == ClientMode.Mobile ? result.RefreshToken?.RawToken : null
            });
        }

        // Strict rotation (M2_AUTH_DESIGN §3.4). Web: refresh cookie + CSRF guard. Mobile: token in the body.
        [HttpPost("session/refresh")]
        public async Task<IActionResult> RefreshSession(
            [FromBody(EmptyBodyBehavior = Microsoft.AspNetCore.Mvc.ModelBinding.EmptyBodyBehavior.Allow)] RefreshSessionDto? model,
            CancellationToken cancellationToken)
        {
            var csrf = _cookieGuard.Check(Request);
            if (!csrf.Allowed || csrf.Mode == ClientMode.Legacy)
            {
                return await CsrfRejectedAsync(csrf with { Reason = csrf.Reason ?? "MissingClientHeader" }, cancellationToken);
            }

            var raw = csrf.Mode == ClientMode.Web ? Request.Cookies[RefreshCookie.Name] : model?.RefreshToken;
            if (string.IsNullOrWhiteSpace(raw))
            {
                return SessionEnded(csrf.Mode, AuthErrorCodes.SessionExpired, "Your session has expired. Please sign in again.");
            }

            var clientType = csrf.Mode == ClientMode.Mobile ? AuthClientType.Mobile : AuthClientType.Web;
            var result = await _refreshSessions.RefreshAsync(raw.Trim(), HttpContext, clientType, cancellationToken);

            switch (result.Outcome)
            {
                case RefreshOutcome.Success:
                    if (csrf.Mode == ClientMode.Web)
                    {
                        RefreshCookie.Append(Response, result.RefreshToken!, _time.GetUtcNow().UtcDateTime);
                    }

                    return Ok(new
                    {
                        userId = result.User!.Id,
                        role = result.User.UserType,
                        status = result.User.Status,
                        accessToken = result.AccessToken!.Token,
                        accessTokenExpiresAt = result.AccessToken.ExpiresAtUtc,
                        refreshTokenExpiresAt = result.RefreshToken!.ExpiresAt,
                        refreshToken = csrf.Mode == ClientMode.Mobile ? result.RefreshToken.RawToken : null
                    });
                case RefreshOutcome.Expired:
                    return SessionEnded(csrf.Mode, AuthErrorCodes.SessionExpired, "Your session has expired. Please sign in again.");
                default:
                    return SessionEnded(csrf.Mode, AuthErrorCodes.SessionRevoked, "For your security, you were signed out. Please sign in again.");
            }
        }

        // Ends the current session. Web: cookie + CSRF guard; mobile: body token; no client header: the Bearer token's session.
        [HttpPost("session/logout")]
        public async Task<IActionResult> Logout(
            [FromBody(EmptyBodyBehavior = Microsoft.AspNetCore.Mvc.ModelBinding.EmptyBodyBehavior.Allow)] RefreshSessionDto? model,
            CancellationToken cancellationToken)
        {
            var csrf = _cookieGuard.Check(Request);
            var bearerSession = Guid.TryParse(User.FindFirst("sid")?.Value, out var sid) ? sid : (Guid?)null;
            if (!csrf.Allowed || (csrf.Mode == ClientMode.Legacy && bearerSession == null))
            {
                return await CsrfRejectedAsync(csrf with { Reason = csrf.Reason ?? "MissingClientHeader" }, cancellationToken);
            }

            var raw = csrf.Mode switch
            {
                ClientMode.Web => Request.Cookies[RefreshCookie.Name],
                ClientMode.Mobile => model?.RefreshToken,
                _ => null
            };
            var clientType = csrf.Mode == ClientMode.Mobile ? AuthClientType.Mobile : AuthClientType.Web;

            await _refreshSessions.LogoutAsync(raw?.Trim(), bearerSession, HttpContext, clientType, cancellationToken);

            if (csrf.Mode != ClientMode.Mobile)
            {
                RefreshCookie.Delete(Response);
            }

            return NoContent();
        }

        // Every session of the signed-in user (M2_AUTH_DESIGN §3.6). Bearer-authenticated, so not CSRF-relevant.
        [HttpPost("logout-all")]
        [Authorize]
        public async Task<IActionResult> LogoutAll(CancellationToken cancellationToken)
        {
            if (!int.TryParse(User.FindFirst("sub")?.Value, out var userId))
            {
                return Unauthorized();
            }

            var clientType = CookieSessionGuard.ModeOf(Request) == ClientMode.Mobile ? AuthClientType.Mobile : AuthClientType.Web;
            await _refreshSessions.LogoutAllAsync(userId, HttpContext, clientType, cancellationToken);
            RefreshCookie.Delete(Response);
            return NoContent();
        }

        private ObjectResult SessionEnded(ClientMode mode, string errorCode, string message)
        {
            if (mode == ClientMode.Web)
            {
                RefreshCookie.Delete(Response);
            }

            return AuthError(StatusCodes.Status401Unauthorized, errorCode, message);
        }

        private async Task<ObjectResult> CsrfRejectedAsync(CsrfCheckResult csrf, CancellationToken cancellationToken)
        {
            _context.SecurityEvents.Add(_events.Create(HttpContext, SecurityEventTypes.CsrfRejected, SecurityEventOutcome.Blocked,
                _time.GetUtcNow().UtcDateTime, reason: csrf.Reason));
            await _context.SaveChangesAsync(cancellationToken);
            HttpContext.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("DevLink.Security")
                .LogWarning("Auth.CsrfRejected {Reason}", csrf.Reason);

            return AuthError(StatusCodes.Status403Forbidden, AuthErrorCodes.CsrfFailed,
                "This request was blocked for your security. Please reload DevLink and try again.");
        }

        // The trusted source for the signed-in user's role and status (M2_AUTH_DESIGN §6.1).
        [HttpGet("me")]
        [Authorize]
        public async Task<IActionResult> Me(CancellationToken cancellationToken)
        {
            if (!int.TryParse(User.FindFirst("sub")?.Value, out var userId))
            {
                return Unauthorized();
            }

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            if (user == null)
            {
                return Unauthorized();
            }

            return Ok(new
            {
                userId = user.Id,
                role = user.UserType,
                email = user.Email,
                status = user.Status,
                suspendedReason = user.Status == UserStatus.Suspended ? user.SuspendedReason : null,
                hasProfile = await _context.CustomerProfiles.AnyAsync(p => p.UserId == user.Id, cancellationToken),
                hasProgrammerProfile = await _context.ProgrammerProfiles.AnyAsync(p => p.UserId == user.Id, cancellationToken)
            });
        }

        private ObjectResult AuthError(int status, string errorCode, string message)
        {
            var result = new ObjectResult(new
            {
                type = "about:blank",
                title = Microsoft.AspNetCore.WebUtilities.ReasonPhrases.GetReasonPhrase(status),
                status,
                errorCode,
                message,
                traceId = Activity.Current?.Id ?? HttpContext.TraceIdentifier
            })
            {
                StatusCode = status
            };
            result.ContentTypes.Add("application/problem+json");
            return result;
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

    public class RefreshSessionDto
    {
        // Mobile clients only; web clients use the HttpOnly cookie.
        public string? RefreshToken { get; set; }
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