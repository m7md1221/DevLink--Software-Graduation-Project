using Microsoft.AspNetCore.Authorization;
using DataBase;
using Microsoft.AspNetCore.Mvc;
using Services.Auth;
using Services.Security;
using Microsoft.EntityFrameworkCore;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SupportController : ControllerBase
    {
        private const int MaxMessagesPerHour = 5;
        private const int MaxMessagesPerDay = 20;

        private readonly AppDbContext _context;
        private readonly ICurrentUser _currentUser;
        private readonly SecurityEventFactory _events;

        public SupportController(AppDbContext context, ICurrentUser currentUser, SecurityEventFactory events)
        {
            _context = context;
            _currentUser = currentUser;
            _events = events;
        }

        // Customers and programmers (D-7). With a token, the sender comes from the account; client values are ignored (Q4).
        [HttpPost]
        [AllowSuspended]
        [Authorize(Policy = AuthPolicies.NonAdminOrDevFallback)]
        public async Task<IActionResult> SendMessage(
            [FromBody] SupportMessageDto model)
        {
            if (_currentUser.IsAuthenticated)
            {
                var account = await _context.Users.FindAsync(_currentUser.UserId);
                if (account == null)
                {
                    return Unauthorized();
                }

                var nickname =
                    await _context.CustomerProfiles.Where(p => p.UserId == account.Id).Select(p => p.Nickname).FirstOrDefaultAsync() ??
                    await _context.ProgrammerProfiles.Where(p => p.UserId == account.Id).Select(p => p.Nickname).FirstOrDefaultAsync();

                model.UserId = account.Id;
                model.Name = nickname ?? account.Email.Split('@')[0];
                model.Email = account.Email;
            }
            else
            {
                model.UserId = _currentUser.ResolveUserId(model.UserId);
            }

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

            if (model.Subject.Length > 200)
            {
                return BadRequest(new
                {
                    message = "Subject is too long (max 200 chars)"
                });
            }

            if (model.Message.Length > 5000)
            {
                return BadRequest(new
                {
                    message = "Message is too long (max 5000 chars)"
                });
            }

            if (model.UserId.HasValue && model.UserId.Value > 0)
            {
                var userExists = await _context.Users
                    .FindAsync(model.UserId.Value);

                if (userExists == null)
                {
                    model.UserId = null;
                }
            }

            // 5 per hour, 20 per day per account (design 8 #59).
            if (model.UserId.HasValue && await LimitReachedAsync(model.UserId.Value))
            {
                _context.SecurityEvents.Add(_events.Create(HttpContext, SecurityEventTypes.RateLimited, SecurityEventOutcome.Blocked,
                    DateTime.UtcNow, model.UserId, reason: "api/Support"));
                await _context.SaveChangesAsync();

                Response.Headers.RetryAfter = "3600";
                return AuthProblem.Result(HttpContext, StatusCodes.Status429TooManyRequests, AuthErrorCodes.RateLimited,
                    "You have sent too many messages. Please try again later.");
            }

            var msg = new SupportMessage
            {
                UserId = model.UserId,
                Name = model.Name!.Trim(),
                Email = model.Email!.Trim().ToLower(),
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

        private async Task<bool> LimitReachedAsync(int userId)
        {
            var now = DateTime.UtcNow;
            var hourAgo = now.AddHours(-1);
            var dayAgo = now.AddDays(-1);
            var recent = _context.SupportMessages.Where(m => m.UserId == userId);

            return await recent.CountAsync(m => m.CreatedAt > hourAgo) >= MaxMessagesPerHour ||
                   await recent.CountAsync(m => m.CreatedAt > dayAgo) >= MaxMessagesPerDay;
        }

        [HttpGet("all")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> GetAllMessages(
            [FromQuery] string? status = null)
        {
            var query = _context.SupportMessages.AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && status != "All")
            {
                query = query.Where(m => m.Status == status);
            }

            var messages = await query
                .OrderByDescending(m => m.CreatedAt)
                .ToListAsync();

            var result = new List<object>();

            foreach (var m in messages)
            {
                string? userName = null;
                string? userType = null;

                if (m.UserId.HasValue)
                {
                    var user = await _context.Users
                        .FirstOrDefaultAsync(u => u.Id == m.UserId.Value);

                    if (user != null)
                    {
                        userType = user.UserType;

                        if (user.UserType == "Customer")
                        {
                            var p = await _context.CustomerProfiles
                                .FirstOrDefaultAsync(cp => cp.UserId == user.Id);
                            userName = p?.Nickname;
                        }
                        else if (user.UserType == "Programmer")
                        {
                            var p = await _context.ProgrammerProfiles
                                .FirstOrDefaultAsync(pp => pp.UserId == user.Id);
                            userName = p?.Nickname;
                        }
                    }
                }

                result.Add(new
                {
                    id = m.Id,
                    userId = m.UserId,
                    userName = userName,
                    userType = userType,
                    name = m.Name,
                    email = m.Email,
                    subject = m.Subject,
                    message = m.Message,
                    status = m.Status,
                    adminReply = m.AdminReply,
                    repliedAt = m.RepliedAt,
                    createdAt = m.CreatedAt,
                    readAt = m.ReadAt
                });
            }

            return Ok(new { messages = result });
        }

        [HttpGet("{id}")]
        [AllowSuspended]
        public async Task<IActionResult> GetMessage(int id)
        {
            var m = await _context.SupportMessages
                .FirstOrDefaultAsync(x => x.Id == id);

            if (m == null)
            {
                return NotFound(new { message = "Message not found" });
            }

            return Ok(new
            {
                id = m.Id,
                userId = m.UserId,
                name = m.Name,
                email = m.Email,
                subject = m.Subject,
                message = m.Message,
                status = m.Status,
                adminReply = m.AdminReply,
                repliedAt = m.RepliedAt,
                createdAt = m.CreatedAt,
                readAt = m.ReadAt
            });
        }

        [HttpPost("{id}/reply")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> ReplyToMessage(
            int id,
            [FromBody] ReplyDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Reply))
            {
                return BadRequest(new { message = "Reply is required" });
            }

            if (model.Reply.Length > 5000)
            {
                return BadRequest(new
                {
                    message = "Reply is too long (max 5000 chars)"
                });
            }

            var msg = await _context.SupportMessages
                .FirstOrDefaultAsync(x => x.Id == id);

            if (msg == null)
            {
                return NotFound(new { message = "Message not found" });
            }

            msg.AdminReply = model.Reply.Trim();
            msg.Status = "Replied";
            msg.RepliedAt = DateTime.UtcNow;
            msg.CustomerReadReplyAt = null;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Reply sent successfully",
                repliedAt = msg.RepliedAt
            });
        }

        [HttpPost("{id}/read")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> MarkAsRead(int id)
        {
            var msg = await _context.SupportMessages
                .FirstOrDefaultAsync(x => x.Id == id);

            if (msg == null)
            {
                return NotFound(new { message = "Message not found" });
            }

            if (msg.ReadAt == null)
            {
                msg.ReadAt = DateTime.UtcNow;

                if (msg.Status == "New")
                {
                    msg.Status = "Read";
                }

                await _context.SaveChangesAsync();
            }

            return Ok(new { message = "Marked as read" });
        }

        [HttpDelete("{id}")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> DeleteMessage(int id)
        {
            var msg = await _context.SupportMessages
                .FirstOrDefaultAsync(x => x.Id == id);

            if (msg == null)
            {
                return NotFound(new { message = "Message not found" });
            }

            _context.SupportMessages.Remove(msg);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Message deleted" });
        }

        [HttpGet("my/{userId}")]
        [AllowSuspended]
        public async Task<IActionResult> GetMyMessages(int userId)
        {
            var messages = await _context.SupportMessages
                .Where(m => m.UserId == userId)
                .OrderByDescending(m => m.CreatedAt)
                .ToListAsync();

            var result = messages.Select(m => new
            {
                id = m.Id,
                subject = m.Subject,
                message = m.Message,
                status = m.Status,
                adminReply = m.AdminReply,
                repliedAt = m.RepliedAt,
                createdAt = m.CreatedAt
            }).ToList();

            return Ok(new { messages = result });
        }

        [HttpGet("my/{userId}/unread-count")]
        [AllowSuspended]
        public async Task<IActionResult> GetUnreadRepliesCount(int userId)
        {
            var count = await _context.SupportMessages
                .CountAsync(m =>
                    m.UserId == userId &&
                    m.Status == "Replied" &&
                    m.CustomerReadReplyAt == null);

            return Ok(new { count });
        }

        [HttpPost("{id}/mark-reply-read")]
        [AllowSuspended]
        [Authorize(Policy = AuthPolicies.NonAdminResourceOrDevFallback)]
        public async Task<IActionResult> MarkReplyRead(int id)
        {
            var msg = await _context.SupportMessages
                .FirstOrDefaultAsync(x => x.Id == id);

            if (msg == null)
                return NotFound(new { message = "Message not found" });

            // Only the sender. A tokenless request gets here only through the development fallback.
            if (_currentUser.IsAuthenticated && msg.UserId != _currentUser.UserId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own messages");

            msg.CustomerReadReplyAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return Ok(new { message = "Marked as read" });
        }
    }

    public class SupportMessageDto
    {
        public int? UserId { get; set; }
        public string? Name { get; set; }
        public string? Email { get; set; }
        public string Subject { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }

    public class ReplyDto
    {
        public string Reply { get; set; } = string.Empty;
    }
}