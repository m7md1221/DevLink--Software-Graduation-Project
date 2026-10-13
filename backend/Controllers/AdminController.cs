using Microsoft.AspNetCore.Mvc;
using Services;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AdminController : ControllerBase
    {
        private readonly AdminService _adminService;

        public AdminController(AdminService adminService)
        {
            _adminService = adminService;
        }

        // ============================================================
        // USERS MANAGEMENT
        // ============================================================

        // GET: /api/Admin/users
        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            var users = await _adminService.GetAllUsers();
            return Ok(users);
        }

        // GET: /api/Admin/users/{id}
        [HttpGet("users/{id}")]
        public async Task<IActionResult> GetUser(int id)
        {
            var user = await _adminService.GetUserById(id);

            if (user == null)
            {
                return NotFound(new { message = "User not found" });
            }

            return Ok(user);
        }

        // POST: /api/Admin/users
        [HttpPost("users")]
        public async Task<IActionResult> CreateUser(
            [FromBody] CreateUserDto model)
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

            if (model.Password.Length < 6)
            {
                return BadRequest(new
                {
                    message = "Password must be at least 6 characters"
                });
            }

            var (success, message) = await _adminService.CreateUser(
                model.Email, model.Password, model.UserType);

            if (!success)
            {
                return BadRequest(new { message });
            }

            return Ok(new { message });
        }

        // PUT: /api/Admin/users/{id}
        [HttpPut("users/{id}")]
        public async Task<IActionResult> UpdateUser(
            int id, [FromBody] UpdateUserDto model)
        {
            var (success, message) = await _adminService.UpdateUser(
                id,
                model.Email,
                model.Password,
                model.UserType);

            if (!success)
            {
                return BadRequest(new { message });
            }

            return Ok(new { message });
        }

        // DELETE: /api/Admin/users/{id}
        [HttpDelete("users/{id}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var (success, message) = await _adminService.DeleteUser(id);

            if (!success)
            {
                return BadRequest(new { message });
            }

            return Ok(new { message });
        }

        // ============================================================
        // PROGRAMMER VERIFICATION
        // ============================================================

        // GET: /api/Admin/programmers
        [HttpGet("programmers")]
        public async Task<IActionResult> GetAllProgrammers()
        {
            var programmers =
                await _adminService.GetAllProgrammersForVerification();
            return Ok(programmers);
        }

        // POST: /api/Admin/programmers/{userId}/verify
        [HttpPost("programmers/{userId}/verify")]
        public async Task<IActionResult> VerifyProgrammer(int userId)
        {
            var (success, message) = await _adminService
                .SetProgrammerVerification(userId, true);

            if (!success) return BadRequest(new { message });
            return Ok(new { message });
        }

        // POST: /api/Admin/programmers/{userId}/unverify
        [HttpPost("programmers/{userId}/unverify")]
        public async Task<IActionResult> UnverifyProgrammer(int userId)
        {
            var (success, message) = await _adminService
                .SetProgrammerVerification(userId, false);

            if (!success) return BadRequest(new { message });
            return Ok(new { message });
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