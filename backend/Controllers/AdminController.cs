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
    // M2.7a: every route needs an Admin token. Tokenless requests pass only through the development
    // fallback (D-1). suspend/unsuspend additionally require the strict AdminOnly policy (no fallback).
    [Authorize(Policy = AuthPolicies.AdminOrDevFallback)]
    public class AdminController : ControllerBase
    {
        private readonly AdminService _adminService;
        private readonly AppDbContext _context; // ✅ ضروري للإحصائيات
        private readonly ICurrentUser _currentUser;

        public AdminController(AdminService adminService, AppDbContext context, ICurrentUser currentUser)
        {
            _adminService = adminService;
            _context = context;
            _currentUser = currentUser;
        }

        // ============================================================
        // USERS MANAGEMENT
        // ============================================================
        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            var users = await _adminService.GetAllUsers();
            return Ok(users);
        }

        [HttpGet("users/{id}")]
        public async Task<IActionResult> GetUser(int id)
        {
            var user = await _adminService.GetUserById(id);
            if (user == null) return NotFound(new { message = "User not found" });
            return Ok(user);
        }

        // ✅ حسابات الأدمن لا تُنشأ ولا تُعدّل من الـ API (لا يوجد تسجيل دخول للـ API بعد)
        private const string AdminProvisioningMessage =
            "Admin accounts are provisioned locally with 'dotnet run -- seed-admin' until admin sign-in is secured.";

        private Task<bool> IsAdminAsync(int id) =>
            _context.Users.AnyAsync(u => u.Id == id && u.UserType == "Admin");

        [HttpPost("users")]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.Password) || string.IsNullOrWhiteSpace(model.UserType))
                return BadRequest(new { message = "All fields are required" });

            if (model.UserType == "Admin")
                return StatusCode(StatusCodes.Status403Forbidden, new { message = AdminProvisioningMessage });

            var (success, message) = await _adminService.CreateUser(model.Email, model.Password, model.UserType);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        [HttpPut("users/{id}")]
        public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserDto model)
        {
            if (model.UserType == "Admin" || await IsAdminAsync(id))
                return StatusCode(StatusCodes.Status403Forbidden, new { message = AdminProvisioningMessage });

            var (success, message) = await _adminService.UpdateUser(id, model.Email, model.Password, model.UserType);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        [HttpDelete("users/{id}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            if (await IsAdminAsync(id))
            {
                await _adminService.AuditBlockedDeleteAsync(id, HttpContext, CallerUserId());
                return StatusCode(StatusCodes.Status403Forbidden, new { message = AdminProvisioningMessage });
            }

            var (success, message) = await _adminService.DeleteUser(id, HttpContext, CallerUserId());
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        // ============================================================
        // SUSPENSION (M2.5b) — new routes, Admin token required from day one
        // ============================================================
        [HttpPost("users/{id}/suspend")]
        [Authorize(Policy = AuthPolicies.AdminOnly)]
        public async Task<IActionResult> SuspendUser(int id, [FromBody] SuspendUserDto model)
        {
            var (status, message) = await _adminService.SuspendUser(id, model.Reason, HttpContext, CallerUserId()!.Value);
            return AdminResult(status, message);
        }

        [HttpPost("users/{id}/unsuspend")]
        [Authorize(Policy = AuthPolicies.AdminOnly)]
        public async Task<IActionResult> UnsuspendUser(int id)
        {
            var (status, message) = await _adminService.UnsuspendUser(id, HttpContext, CallerUserId()!.Value);
            return AdminResult(status, message);
        }

        // The admin from the token; null only for a tokenless request on the development fallback.
        private int? CallerUserId() => _currentUser.UserId;

        private IActionResult AdminResult(AdminActionStatus status, string message) => status switch
        {
            AdminActionStatus.Ok => Ok(new { message }),
            AdminActionStatus.NotFound => NotFound(new { message }),
            AdminActionStatus.Forbidden => StatusCode(StatusCodes.Status403Forbidden, new { message }),
            _ => BadRequest(new { message })
        };

        // ============================================================
        // PROGRAMMER VERIFICATION
        // ============================================================
        [HttpGet("programmers")]
        public async Task<IActionResult> GetAllProgrammers()
        {
            var programmers = await _adminService.GetAllProgrammersForVerification();
            return Ok(programmers);
        }

        [HttpPost("programmers/{userId}/verify")]
        public async Task<IActionResult> VerifyProgrammer(int userId)
        {
            var (success, message) = await _adminService.SetProgrammerVerification(userId, true);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        [HttpPost("programmers/{userId}/unverify")]
        public async Task<IActionResult> UnverifyProgrammer(int userId)
        {
            var (success, message) = await _adminService.SetProgrammerVerification(userId, false);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        // ============================================================
        // ✅ NEW: STATISTICS ENDPOINT
        // ============================================================
        [HttpGet("statistics")]
        public async Task<IActionResult> GetStatistics()
        {
            var totalCustomers = await _context.Users.CountAsync(u => u.UserType == "Customer");
            var totalProgrammers = await _context.Users.CountAsync(u => u.UserType == "Programmer");
            var totalPosts = await _context.Posts.CountAsync(p => !p.IsDeleted);
            var pendingPosts = await _context.Posts.CountAsync(p => p.Status == "Pending" && !p.IsDeleted);
            var verifiedProgrammers = await _context.ProgrammerProfiles.CountAsync(p => p.IsVerified);
            var totalSupportMessages = await _context.SupportMessages.CountAsync();
            var unreadSupportMessages = await _context.SupportMessages.CountAsync(m => m.Status == "New");

            return Ok(new
            {
                customers = totalCustomers,
                programmers = totalProgrammers,
                totalUsers = totalCustomers + totalProgrammers,
                posts = totalPosts,
                pendingPosts = pendingPosts,
                verifiedProgrammers = verifiedProgrammers,
                supportMessages = totalSupportMessages,
                unreadSupportMessages = unreadSupportMessages
            });
        }
    }

    // ============================================================
    // DTOs
    // ============================================================
    public class CreateUserDto
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string UserType { get; set; } = string.Empty;
    }

    public class UpdateUserDto
    {
        public string? Email { get; set; }
        public string? Password { get; set; }
        public string? UserType { get; set; }
    }

    public class SuspendUserDto
    {
        public string? Reason { get; set; }
    }
}