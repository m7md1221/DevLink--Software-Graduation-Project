using System.Text.Json;
using DataBase;
using Microsoft.EntityFrameworkCore;
using Services.Auth;
using Services.Security;

namespace Services
{
    public enum AdminActionStatus
    {
        Ok,
        BadRequest,
        NotFound,
        Forbidden
    }

    public class AdminService
    {
        public const int MaxSuspendedReasonLength = 500;

        private readonly AppDbContext _context;
        private readonly IEmailSender _emailService;
        private readonly PasswordService _passwordService;
        private readonly RefreshSessionService _sessions;
        private readonly SessionStateCache _sessionCache;
        private readonly SecurityEventFactory _events;
        private readonly TimeProvider _time;

        public AdminService(
            AppDbContext context,
            IEmailSender emailService,
            PasswordService passwordService,
            RefreshSessionService sessions,
            SessionStateCache sessionCache,
            SecurityEventFactory events,
            TimeProvider time)
        {
            _context = context;
            _emailService = emailService;
            _passwordService = passwordService;
            _sessions = sessions;
            _sessionCache = sessionCache;
            _events = events;
            _time = time;
        }

        // ============================================================
        // USERS MANAGEMENT
        // ============================================================

        public async Task<List<object>> GetAllUsers()
        {
            var users = await _context.Users
                .Where(u => u.UserType != "Admin")
                .OrderByDescending(u => u.Id)
                .ToListAsync();

            var result = new List<object>();

            foreach (var user in users)
            {
                object? profile = null;

                if (user.UserType == "Customer")
                {
                    var p = await _context.CustomerProfiles
                        .FirstOrDefaultAsync(cp => cp.UserId == user.Id);

                    if (p != null)
                    {
                        profile = new
                        {
                            nickname = p.Nickname,
                            phoneNumber = p.PhoneNumber,
                            country = p.Country,
                            city = p.City,
                            hasImage = p.ProfileImage != null
                        };
                    }
                }
                else if (user.UserType == "Programmer")
                {
                    var p = await _context.ProgrammerProfiles
                        .FirstOrDefaultAsync(pp => pp.UserId == user.Id);

                    if (p != null)
                    {
                        profile = new
                        {
                            nickname = p.Nickname,
                            phoneNumber = p.PhoneNumber,
                            country = p.Country,
                            city = p.City,
                            specialty = p.Specialty,
                            university = p.University,
                            isVerified = p.IsVerified,
                            hasImage = p.ProfileImage != null
                        };
                    }
                }

                result.Add(new
                {
                    id = user.Id,
                    email = user.Email,
                    userType = user.UserType,
                    profile = profile
                });
            }

            return result;
        }

        public async Task<object?> GetUserById(int id)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == id);

            if (user == null) return null;

            return new
            {
                id = user.Id,
                email = user.Email,
                userType = user.UserType
            };
        }

        public async Task<(bool success, string message)> CreateUser(
            string email, string password, string userType)
        {
            email = email.Trim().ToLower();

            var exists = await _context.Users
                .AnyAsync(u => u.Email == email);

            if (exists)
            {
                return (false, "This email is already registered");
            }

            if (userType != "Admin" &&
                userType != "Customer" &&
                userType != "Programmer")
            {
                return (false, "Invalid user type");
            }

            var passwordError = _passwordService.ValidatePolicy(password, email);

            if (passwordError != null)
            {
                return (false, passwordError);
            }

            var user = new User
            {
                Email = email,
                UserType = userType
            };

            user.PasswordHash = _passwordService.Hash(user, password);

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return (true, "User created successfully");
        }

        public async Task<(bool success, string message)> UpdateUser(
            int id, string? email, string? password, string? userType)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == id);

            if (user == null)
            {
                return (false, "User not found");
            }

            if (!string.IsNullOrWhiteSpace(email))
            {
                email = email.Trim().ToLower();

                var exists = await _context.Users
                    .AnyAsync(u => u.Email == email && u.Id != id);

                if (exists)
                {
                    return (false, "Email already used by another user");
                }

                user.Email = email;
            }

            if (!string.IsNullOrWhiteSpace(password))
            {
                var passwordError = _passwordService.ValidatePolicy(password, user.Email);

                if (passwordError != null)
                {
                    return (false, passwordError);
                }

                user.PasswordHash = _passwordService.Hash(user, password);
            }

            if (!string.IsNullOrWhiteSpace(userType))
            {
                if (userType != "Admin" &&
                    userType != "Customer" &&
                    userType != "Programmer")
                {
                    return (false, "Invalid user type");
                }

                user.UserType = userType;
            }

            // M2 (§3.6): a role, password or email change signs the user out everywhere —
            // new security stamp, every session revoked — so a new sign-in carries the new role.
            var roleChanged = _context.Entry(user).Property(u => u.UserType).IsModified;
            var credentialsChanged = roleChanged ||
                                     _context.Entry(user).Property(u => u.PasswordHash).IsModified ||
                                     _context.Entry(user).Property(u => u.Email).IsModified;
            if (credentialsChanged)
            {
                user.SecurityStamp = User.NewSecurityStamp();
            }

            await using var transaction = await _context.Database.BeginTransactionAsync();
            await _context.SaveChangesAsync();
            if (credentialsChanged)
            {
                await _sessions.EndSessionsAsync(_context.AuthSessions.Where(s => s.UserId == user.Id), AuthSessionStatus.Revoked,
                    roleChanged ? "RoleChanged" : "AdminChanged", _time.GetUtcNow().UtcDateTime, CancellationToken.None);
            }

            await transaction.CommitAsync();
            if (credentialsChanged)
            {
                _sessionCache.Invalidate(user.Id);
            }

            return (true, "User updated successfully");
        }

        // actorUserId: the caller's token subject, or null — this route stays anonymous until M2.7.
        public async Task<(bool success, string message)> DeleteUser(int id, HttpContext http, int? actorUserId)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == id);

            if (user == null)
            {
                await AuditAsync(http, SecurityEventTypes.AdminUserDeleted, SecurityEventOutcome.Failure, actorUserId, id, "NotFound");
                return (false, "User not found");
            }

            if (user.UserType == "Admin")
            {
                var adminCount = await _context.Users
                    .CountAsync(u => u.UserType == "Admin");

                if (adminCount <= 1)
                {
                    await AuditAsync(http, SecurityEventTypes.AdminUserDeleted, SecurityEventOutcome.Blocked, actorUserId, id, "LastAdmin");
                    return (false, "Cannot delete the last admin");
                }
            }

            var now = _time.GetUtcNow().UtcDateTime;
            await using (var transaction = await _context.Database.BeginTransactionAsync())
            {
                try
                {
                    // KI-39: AuthSessions/RefreshTokens reference Users with NO ACTION, so they are revoked and
                    // removed first, in the same transaction as the delete. SecurityEvents have no FK and stay.
                    var ended = await _sessions.EndSessionsAsync(_context.AuthSessions.Where(s => s.UserId == id), AuthSessionStatus.Revoked,
                        "UserDeleted", now, CancellationToken.None);
                    var sessionIds = _context.AuthSessions.Where(s => s.UserId == id).Select(s => s.Id);
                    await _context.RefreshTokens.Where(t => sessionIds.Contains(t.SessionId)).ExecuteDeleteAsync();
                    await _context.AuthSessions.Where(s => s.UserId == id).ExecuteDeleteAsync();

                    _context.Users.Remove(user);
                    await _context.SaveChangesAsync();

                    _context.SecurityEvents.Add(AdminEvent(http, SecurityEventTypes.AdminUserDeleted, SecurityEventOutcome.Success, actorUserId, id,
                        "Deleted", new { sessionsEnded = ended }));
                    await _context.SaveChangesAsync();
                    await transaction.CommitAsync();
                }
                catch (DbUpdateException)
                {
                    // The delete is refused by other references (KI-10): nothing was removed. Audit, then keep the existing behaviour.
                    await transaction.RollbackAsync();
                    _context.ChangeTracker.Clear();
                    await AuditAsync(http, SecurityEventTypes.AdminUserDeleted, SecurityEventOutcome.Failure, actorUserId, id, "DeleteFailed");
                    throw;
                }
            }

            _sessionCache.Invalidate(id);
            return (true, "User deleted successfully");
        }

        // ============================================================
        // SUSPENSION (M2.5b; §7.4). Owner rule 2026-11-04: suspending also rotates the
        // stamp and revokes every session, so existing tokens get 401 at once; the user
        // can sign in again, but only into restricted mode. Admins can't be suspended.
        // ============================================================

        public async Task<(AdminActionStatus status, string message)> SuspendUser(int id, string? reason, HttpContext http, int actorUserId)
        {
            const string type = SecurityEventTypes.AdminUserSuspended;
            if (id == actorUserId)
            {
                await AuditAsync(http, type, SecurityEventOutcome.Blocked, actorUserId, id, "Self");
                return (AdminActionStatus.Forbidden, "You cannot suspend your own account");
            }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
            if (user == null)
            {
                await AuditAsync(http, type, SecurityEventOutcome.Failure, actorUserId, id, "NotFound");
                return (AdminActionStatus.NotFound, "User not found");
            }

            if (user.UserType == "Admin")
            {
                await AuditAsync(http, type, SecurityEventOutcome.Blocked, actorUserId, id, "AdminTarget");
                return (AdminActionStatus.Forbidden, "Admin accounts cannot be suspended");
            }

            reason = reason?.Trim();
            if (string.IsNullOrEmpty(reason) || reason.Length > MaxSuspendedReasonLength)
            {
                await AuditAsync(http, type, SecurityEventOutcome.Failure, actorUserId, id, "InvalidReason");
                return (AdminActionStatus.BadRequest, $"A reason of 1 to {MaxSuspendedReasonLength} characters is required");
            }

            if (user.Status == UserStatus.Suspended)
            {
                await AuditAsync(http, type, SecurityEventOutcome.Success, actorUserId, id, "AlreadySuspended");
                return (AdminActionStatus.Ok, "User is already suspended");
            }

            var now = _time.GetUtcNow().UtcDateTime;
            user.Status = UserStatus.Suspended;
            user.SuspendedReason = reason;
            user.SuspendedAt = now;
            user.SecurityStamp = User.NewSecurityStamp();

            await using (var transaction = await _context.Database.BeginTransactionAsync())
            {
                await _context.SaveChangesAsync();
                var ended = await _sessions.EndSessionsAsync(_context.AuthSessions.Where(s => s.UserId == id), AuthSessionStatus.Revoked,
                    "Suspended", now, CancellationToken.None);
                // The reason text is written by the admin and may hold personal data: it stays on the user row only.
                _context.SecurityEvents.Add(AdminEvent(http, type, SecurityEventOutcome.Success, actorUserId, id, "Suspended", new { sessionsEnded = ended }));
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
            }

            _sessionCache.Invalidate(id);
            return (AdminActionStatus.Ok, "User suspended successfully");
        }

        public async Task<(AdminActionStatus status, string message)> UnsuspendUser(int id, HttpContext http, int actorUserId)
        {
            const string type = SecurityEventTypes.AdminUserUnsuspended;
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
            if (user == null)
            {
                await AuditAsync(http, type, SecurityEventOutcome.Failure, actorUserId, id, "NotFound");
                return (AdminActionStatus.NotFound, "User not found");
            }

            if (user.UserType == "Admin")
            {
                await AuditAsync(http, type, SecurityEventOutcome.Blocked, actorUserId, id, "AdminTarget");
                return (AdminActionStatus.Forbidden, "Admin accounts cannot be suspended or unsuspended");
            }

            if (user.Status != UserStatus.Suspended)
            {
                await AuditAsync(http, type, SecurityEventOutcome.Success, actorUserId, id, "NotSuspended");
                return (AdminActionStatus.Ok, "User is not suspended");
            }

            user.Status = UserStatus.Active;
            user.SuspendedReason = null;
            user.SuspendedAt = null;
            _context.SecurityEvents.Add(AdminEvent(http, type, SecurityEventOutcome.Success, actorUserId, id, "Unsuspended", null));
            await _context.SaveChangesAsync();

            // Sessions opened while suspended get full access on their next request.
            _sessionCache.Invalidate(id);
            return (AdminActionStatus.Ok, "User unsuspended successfully");
        }

        // The controller refuses to delete admin accounts (Q10) before reaching DeleteUser.
        public Task AuditBlockedDeleteAsync(int id, HttpContext http, int? actorUserId) =>
            AuditAsync(http, SecurityEventTypes.AdminUserDeleted, SecurityEventOutcome.Blocked, actorUserId, id, "AdminTarget");

        private SecurityEvent AdminEvent(HttpContext http, string type, string outcome, int? actorUserId, int targetUserId, string result, object? extra)
        {
            var evt = _events.Create(http, type, outcome, _time.GetUtcNow().UtcDateTime, targetUserId);
            evt.ActorUserId = actorUserId;
            evt.TargetType = "User";
            evt.TargetId = targetUserId.ToString();
            evt.Details = JsonSerializer.Serialize(extra == null ? new { result } : (object)new { result, details = extra });
            return evt;
        }

        private async Task AuditAsync(HttpContext http, string type, string outcome, int? actorUserId, int targetUserId, string result)
        {
            _context.SecurityEvents.Add(AdminEvent(http, type, outcome, actorUserId, targetUserId, result, null));
            await _context.SaveChangesAsync();
        }

        // ============================================================
        // PROGRAMMER VERIFICATION
        // ============================================================

        public async Task<List<object>> GetAllProgrammersForVerification()
        {
            var programmers = await _context.ProgrammerProfiles
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();

            var result = new List<object>();

            foreach (var p in programmers)
            {
                var user = await _context.Users
                    .FirstOrDefaultAsync(u => u.Id == p.UserId);

                result.Add(new
                {
                    userId = p.UserId,
                    email = user?.Email ?? "",
                    nickname = p.Nickname,
                    specialty = p.Specialty,
                    university = p.University,
                    country = p.Country,
                    city = p.City,
                    phoneNumber = p.PhoneNumber,
                    linkedInUrl = p.LinkedInUrl,
                    isVerified = p.IsVerified,
                    rating = p.Rating,
                    hasImage = p.ProfileImage != null,
                    hasCV = p.CV != null,
                    hasCertificate = p.Certificate != null,
                    cvName = p.CVName,
                    certificateName = p.CertificateName,
                    createdAt = p.CreatedAt
                });
            }

            return result;
        }

        // ✅ توثيق / إلغاء توثيق + إرسال إيميل
        public async Task<(bool success, string message)> SetProgrammerVerification(
            int userId, bool verified)
        {
            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return (false, "Programmer profile not found");
            }

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null)
            {
                return (false, "User not found");
            }

            // ✅ إذا الحالة ما تغيرت، ما نعمل شي
            if (profile.IsVerified == verified)
            {
                return (true, verified
                    ? "Programmer is already verified"
                    : "Programmer is already unverified");
            }

            profile.IsVerified = verified;
            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // ✅ إرسال الإيميل (ما نوقف العملية لو الإيميل فشل)
            try
            {
                if (verified)
                {
                    _emailService.SendEmail(
                        user.Email,
                        "🎉 Congratulations! Your DevLink account is now verified",
                        BuildVerificationEmail(profile.Nickname)
                    );
                }
                else
                {
                    _emailService.SendEmail(
                        user.Email,
                        "Your DevLink verification has been removed",
                        BuildUnverificationEmail(profile.Nickname)
                    );
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️ Email error: {ex.Message}");
                // ما نرجع false — لأن التوثيق نجح
            }

            return (true, verified
                ? "Programmer verified successfully"
                : "Programmer unverified successfully");
        }

        // ============================================================
        // EMAIL TEMPLATES
        // ============================================================

        private static string BuildVerificationEmail(string nickname)
        {
            return $@"Hi {nickname},

Great news! 🎉

Your DevLink programmer account has been reviewed and verified successfully.

Your profile now shows the verified badge, which means:

  ✅ Customers can trust your profile
  ✅ You will appear higher in search results
  ✅ You can receive more project requests

Thank you for being part of DevLink!

Best regards,
DevLink Team
";
        }

        private static string BuildUnverificationEmail(string nickname)
        {
            return $@"Hi {nickname},

Your DevLink verification status has been removed.

If you believe this was a mistake, please contact support.

Best regards,
DevLink Team
";
        }
    }
}