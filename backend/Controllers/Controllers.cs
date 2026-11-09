using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using DataBase;
using Services;
using Services.Auth;
using Services.Files;
using Services.Security;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [AllowSuspended] // sign-in flows and the suspension notice stay reachable for suspended accounts (§7.4)
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly GoogleAuthService _googleAuthService;
        private readonly PasswordService _passwordService;
        private readonly LoginService _loginService;
        private readonly RefreshSessionService _refreshSessions;
        private readonly CookieSessionGuard _cookieGuard;
        private readonly SecurityEventFactory _events;
        private readonly TimeProvider _time;
        private readonly OneTimeCodeService _codes;
        private readonly EmailQueue _emailQueue;
        private readonly LegacyFallback _legacyFallback;
        private readonly SessionStateCache _sessionCache;

        public AuthController(
            AppDbContext context,
            GoogleAuthService googleAuthService,
            PasswordService passwordService,
            LoginService loginService,
            RefreshSessionService refreshSessions,
            CookieSessionGuard cookieGuard,
            SecurityEventFactory events,
            TimeProvider time,
            OneTimeCodeService codes,
            EmailQueue emailQueue,
            LegacyFallback legacyFallback,
            SessionStateCache sessionCache)
        {
            _context = context;
            _googleAuthService = googleAuthService;
            _passwordService = passwordService;
            _loginService = loginService;
            _refreshSessions = refreshSessions;
            _cookieGuard = cookieGuard;
            _events = events;
            _time = time;
            _codes = codes;
            _emailQueue = emailQueue;
            _legacyFallback = legacyFallback;
            _sessionCache = sessionCache;
        }

        // Response keeps every pre-M2.4a field (message, userId, userType, email, hasProfile,
        // hasProgrammerProfile); everything else is an addition.
        // Refresh token by client mode (X-DevLink-Client): "web" → HttpOnly cookie (CSRF-guarded),
        // "mobile" → response body, no header (today's app) → none, exactly as in M2.4a.
        [HttpPost("login")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.Login)]
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
                issueRefreshToken: csrf.Mode != ClientMode.Legacy, HttpContext, cancellationToken, issueDownloadBinding: csrf.Mode == ClientMode.Web);

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
                DownloadBindingCookie.Append(Response, result.DownloadBinding!, result.Session!.AbsoluteExpiresAt - _time.GetUtcNow().UtcDateTime);
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
        [AllowAnonymous]
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
        [AllowAnonymous]
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
                DownloadBindingCookie.Delete(Response);
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
            DownloadBindingCookie.Delete(Response);
            return NoContent();
        }

        private ObjectResult SessionEnded(ClientMode mode, string errorCode, string message)
        {
            if (mode == ClientMode.Web)
            {
                RefreshCookie.Delete(Response);
                DownloadBindingCookie.Delete(Response);
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
        public async Task<IActionResult> Me([FromServices] MediaUrls media, CancellationToken cancellationToken)
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

            var hasImage =
                await _context.CustomerProfiles.AnyAsync(p => p.UserId == user.Id && p.ProfileImage != null, cancellationToken) ||
                await _context.ProgrammerProfiles.AnyAsync(p => p.UserId == user.Id && p.ProfileImage != null, cancellationToken);

            return Ok(new
            {
                userId = user.Id,
                role = user.UserType,
                email = user.Email,
                status = user.Status,
                avatarUrl = hasImage ? media.AvatarUrl(user.Id) : null,
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
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.GoogleLogin)]
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

        // ============================================================
        // SIGN-UP AND PASSWORD-RESET CODES (M2.5a; M2_AUTH_DESIGN §6.2, Q6, Q7, C6)
        // Responses never reveal whether an email has an account. Codes are
        // emailed through the background queue (Development: console only).
        // ============================================================

        private const string SignupCodeSentMessage =
            "If this email can be used for a new DevLink account, we've sent a 6-digit code to it. Check your inbox and spam folder — the code expires in 10 minutes.";
        private const string ResetCodeSentMessage =
            "If an account exists for this email, we've sent a 6-digit reset code. It expires in 10 minutes.";
        private const string CodeInvalidMessage =
            "That code is incorrect or has expired. Check the latest email or request a new code.";
        private const string AttemptsExceededMessage =
            "Too many incorrect attempts. Please request a new code.";
        private const string VerificationRequiredMessage =
            "Your verification has expired or was already used. Please verify your email again.";

        [HttpPost("send-code")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.CodeSend)]
        public Task<IActionResult> SendCode([FromBody] SendCodeDto model, CancellationToken cancellationToken) =>
            RequestCodeAsync(model, OneTimeCodePurpose.Signup, cancellationToken);

        [HttpPost("send-reset-code")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.CodeSend)]
        public Task<IActionResult> SendResetCode([FromBody] SendCodeDto model, CancellationToken cancellationToken) =>
            RequestCodeAsync(model, OneTimeCodePurpose.Reset, cancellationToken);

        [HttpPost("verify-code")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.CodeVerify)]
        public Task<IActionResult> VerifyCode([FromBody] VerifyCodeDto model, CancellationToken cancellationToken) =>
            VerifyCodeAsync(model, OneTimeCodePurpose.Signup, cancellationToken);

        [HttpPost("verify-reset-code")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.CodeVerify)]
        public Task<IActionResult> VerifyResetCode([FromBody] VerifyCodeDto model, CancellationToken cancellationToken) =>
            VerifyCodeAsync(model, OneTimeCodePurpose.Reset, cancellationToken);

        private async Task<IActionResult> RequestCodeAsync(SendCodeDto model, string purpose, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(model.Email))
            {
                return BadRequest(new { message = "Email is required" });
            }

            var email = SecurityKeys.NormalizeEmail(model.Email);
            var hasAccount = await _context.Users.AnyAsync(u => u.Email == email, cancellationToken);

            // A code row is always created — for emails that won't receive it, it's a decoy, so attempts
            // and limits behave the same for every email.
            var result = await _codes.RequestAsync(email, purpose, HttpContext, cancellationToken);
            if (result.Outcome == CodeRequestOutcome.RateLimited)
            {
                return TooManyRequests(result.RetryAfter!.Value);
            }

            if (purpose == OneTimeCodePurpose.Signup)
            {
                if (hasAccount)
                {
                    _emailQueue.Enqueue(email, "DevLink sign-up attempt",
                        "Someone tried to create a DevLink account with this email. If it was you, sign in or reset your password.");
                }
                else
                {
                    _emailQueue.Enqueue(email, "DevLink Email Verification",
                        $"Your DevLink verification code is: {result.Code}\nIt expires in 10 minutes.");
                }

                return Ok(new { message = SignupCodeSentMessage, expiresInMinutes = 10 });
            }

            if (hasAccount)
            {
                _emailQueue.Enqueue(email, "DevLink Password Reset",
                    $"Your DevLink password reset code is: {result.Code}\nIt expires in 10 minutes.");
            }

            return Ok(new { message = ResetCodeSentMessage, expiresInMinutes = 10 });
        }

        private async Task<IActionResult> VerifyCodeAsync(VerifyCodeDto model, string purpose, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.Code))
            {
                return BadRequest(new { message = "Email and code are required" });
            }

            var result = await _codes.VerifyAsync(SecurityKeys.NormalizeEmail(model.Email), purpose, model.Code, HttpContext, cancellationToken);

            return result.Outcome switch
            {
                CodeVerifyOutcome.Verified when purpose == OneTimeCodePurpose.Signup =>
                    Ok(new { message = "Email verified successfully", signupToken = result.ProofToken }),
                CodeVerifyOutcome.Verified =>
                    Ok(new { message = "Reset code verified", resetToken = result.ProofToken }),
                CodeVerifyOutcome.RateLimited => TooManyRequests(result.RetryAfter!.Value),
                CodeVerifyOutcome.AttemptsExceeded => AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.CodeAttemptsExceeded, AttemptsExceededMessage),
                _ => AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.CodeInvalid, CodeInvalidMessage)
            };
        }

        // The proof token from verify-code / verify-reset-code; without it, only the Development fallback (C1 case 2).
        private async Task<bool> ConsumeProofAsync(string email, string purpose, string? proofToken, CancellationToken cancellationToken)
        {
            if (!string.IsNullOrWhiteSpace(proofToken))
            {
                return await _codes.ConsumeProofAsync(email, purpose, proofToken, cancellationToken);
            }

            return _legacyFallback.TryUse(HttpContext, LegacyFallbackCase.SignupResetWithoutProof) &&
                   await _codes.ConsumeLatestProofWithoutTokenAsync(email, purpose, cancellationToken);
        }

        [HttpPost("signup")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.PasswordSet)]
        public async Task<IActionResult> SignUp(
            [FromBody] SignUpDto model,
            CancellationToken cancellationToken)
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

            var email = SecurityKeys.NormalizeEmail(model.Email);

            // Checked before the proof is spent, so a weak password can be corrected without a new code.
            var passwordError = _passwordService.ValidatePolicy(model.Password, email);
            if (passwordError != null)
            {
                return AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.PasswordPolicy, passwordError);
            }

            if (!await ConsumeProofAsync(email, OneTimeCodePurpose.Signup, model.SignupToken, cancellationToken))
            {
                return AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.VerificationRequired, VerificationRequiredMessage);
            }

            var emailExists = await _context.Users
                .AnyAsync(u => u.Email == email, cancellationToken);

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
            await _context.SaveChangesAsync(cancellationToken);

            _context.SecurityEvents.Add(_events.Create(HttpContext, SecurityEventTypes.AccountCreated, SecurityEventOutcome.Success,
                _time.GetUtcNow().UtcDateTime, user.Id, reason: user.UserType, email: email));
            await _context.SaveChangesAsync(cancellationToken);

            return Ok(new
            {
                message = "Account created successfully",
                userId = user.Id,
                userType = user.UserType
            });
        }

        // On success: new password hash, new security stamp, every session revoked, lockout cleared (§3.6).
        [HttpPost("reset-password")]
        [AllowAnonymous]
        [EnableRateLimiting(RateLimitPolicies.PasswordSet)]
        public async Task<IActionResult> ResetPassword(
            [FromBody] ResetPasswordDto model,
            CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(model.Email) ||
                string.IsNullOrWhiteSpace(model.NewPassword))
            {
                return BadRequest(new
                {
                    message = "Email and new password are required"
                });
            }

            var email = SecurityKeys.NormalizeEmail(model.Email);

            var passwordError = _passwordService.ValidatePolicy(model.NewPassword, email);
            if (passwordError != null)
            {
                return AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.PasswordPolicy, passwordError);
            }

            if (!await ConsumeProofAsync(email, OneTimeCodePurpose.Reset, model.ResetToken, cancellationToken))
            {
                return AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.VerificationRequired, VerificationRequiredMessage);
            }

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Email == email, cancellationToken);

            if (user == null)
            {
                return AuthError(StatusCodes.Status400BadRequest, AuthErrorCodes.VerificationRequired, VerificationRequiredMessage);
            }

            var now = _time.GetUtcNow().UtcDateTime;
            await using (var transaction = await _context.Database.BeginTransactionAsync(cancellationToken))
            {
                user.PasswordHash = _passwordService.Hash(user, model.NewPassword);
                user.SecurityStamp = DataBase.User.NewSecurityStamp();
                user.FailedLoginCount = 0;
                user.LockoutEndAt = null;
                await _context.SaveChangesAsync(cancellationToken);

                await _refreshSessions.EndSessionsAsync(_context.AuthSessions.Where(s => s.UserId == user.Id),
                    AuthSessionStatus.Revoked, "PasswordReset", now, cancellationToken);

                _context.SecurityEvents.Add(_events.Create(HttpContext, SecurityEventTypes.PasswordReset, SecurityEventOutcome.Success,
                    now, user.Id, email: email));
                await _context.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
            }

            _sessionCache.Invalidate(user.Id);
            _emailQueue.Enqueue(email, "Your DevLink password was changed",
                "Your DevLink password was just reset and you were signed out everywhere. If this wasn't you, reset your password again and contact support.");

            return Ok(new
            {
                message = "Password reset successfully"
            });
        }

        private ObjectResult TooManyRequests(TimeSpan retryAfter)
        {
            Response.Headers.RetryAfter = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds)).ToString();
            var minutes = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalMinutes));
            return AuthError(StatusCodes.Status429TooManyRequests, AuthErrorCodes.RateLimited,
                $"Too many requests. Please wait {minutes} minute{(minutes == 1 ? "" : "s")} and try again.");
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

        // Proof token from verify-code (M2.5a). Optional only for the Development fallback.
        public string? SignupToken { get; set; }
    }

    public class ResetPasswordDto
    {
        public string Email { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;

        // Proof token from verify-reset-code (M2.5a). Optional only for the Development fallback.
        public string? ResetToken { get; set; }
    }
}
