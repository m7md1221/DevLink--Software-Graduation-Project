using DataBase;
using DataBase.Models;
using Microsoft.AspNetCore.Mvc;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SupportController : ControllerBase
    {
        private readonly AppDbContext _context;

        public SupportController(AppDbContext context)
        {
            _context = context;
        }

        // POST: /api/Support
        [HttpPost]
        public async Task<IActionResult> SendMessage(
            [FromBody] SupportMessageDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Name) ||
                string.IsNullOrWhiteSpace(model.Email) ||
                string.IsNullOrWhiteSpace(model.Subject) ||
                string.IsNullOrWhiteSpace(model.Message))
            {
                return BadRequest(new
                {
                    message = "All fields are required"
                });
            }

            if (model.Message.Length > 5000)
            {
                return BadRequest(new
                {
                    message = "Message is too long (max 5000 chars)"
                });
            }

            // ✅ تحقق من وجود المستخدم (اختياري)
            if (model.UserId.HasValue && model.UserId.Value > 0)
            {
                var userExists = await _context.Users
                    .FindAsync(model.UserId.Value);

                if (userExists == null)
                {
                    model.UserId = null;
                }
            }

            var msg = new SupportMessage
            {
                UserId = model.UserId,
                Name = model.Name.Trim(),
                Email = model.Email.Trim().ToLower(),
                Subject = model.Subject.Trim(),
                Message = model.Message.Trim(),
                Status = "New",
                CreatedAt = DateTime.UtcNow
            };

            _context.SupportMessages.Add(msg);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Your message has been sent. We'll get back to you soon.",
                ticketId = msg.Id
            });
        }
    }

    public class SupportMessageDto
    {
        public int? UserId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Subject { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }
}