using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;
using Services;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AdminController : ControllerBase
    {
        private readonly AdminService _adminService;
        private readonly AppDbContext _context; // ✅ ضروري للإحصائيات

        public AdminController(AdminService adminService, AppDbContext context)
        {
            _adminService = adminService;
            _context = context;
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

        [HttpPost("users")]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.Password) || string.IsNullOrWhiteSpace(model.UserType))
                return BadRequest(new { message = "All fields are required" });

            if (model.Password.Length < 6)
                return BadRequest(new { message = "Password must be at least 6 characters" });

            var (success, message) = await _adminService.CreateUser(model.Email, model.Password, model.UserType);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        [HttpPut("users/{id}")]
        public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserDto model)
        {
            var (success, message) = await _adminService.UpdateUser(id, model.Email, model.Password, model.UserType);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        [HttpDelete("users/{id}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var (success, message) = await _adminService.DeleteUser(id);
            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

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
}