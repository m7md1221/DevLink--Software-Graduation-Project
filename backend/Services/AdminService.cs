using DataBase;
using Microsoft.EntityFrameworkCore;

namespace Services
{
    public class AdminService
    {
        private readonly AppDbContext _context;
        private readonly EmailService _emailService;

        public AdminService(
            AppDbContext context,
            EmailService emailService)
        {
            _context = context;
            _emailService = emailService;
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

            var user = new User
            {
                Email = email,
                PasswordHash = password,
                UserType = userType
            };

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
                user.PasswordHash = password;
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

            await _context.SaveChangesAsync();

            return (true, "User updated successfully");
        }

        public async Task<(bool success, string message)> DeleteUser(int id)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == id);

            if (user == null)
            {
                return (false, "User not found");
            }

            if (user.UserType == "Admin")
            {
                var adminCount = await _context.Users
                    .CountAsync(u => u.UserType == "Admin");

                if (adminCount <= 1)
                {
                    return (false, "Cannot delete the last admin");
                }
            }

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();

            return (true, "User deleted successfully");
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