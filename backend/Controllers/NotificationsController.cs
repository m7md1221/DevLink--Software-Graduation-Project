using DataBase;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Services.Auth;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class NotificationsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentUser _currentUser;

        public NotificationsController(AppDbContext context, ICurrentUser currentUser)
        {
            _context = context;
            _currentUser = currentUser;
        }

        public const int DefaultCount = 5;
        public const int MaxCount = 50;

        // Newest first, always a JSON array (the unchanged bell reads exactly this). Without parameters: the newest 5.
        // Paging (N1), one style per request:
        //   limit (1-50, default 5) and before (an id; only older notifications), for "load more";
        //   page (1-based) and pageSize (1-50, default 5).
        // A larger limit or pageSize is capped at 50.
        [HttpGet("{userId}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetNotifications(
            int userId,
            [FromQuery] int? limit = null,
            [FromQuery] int? before = null,
            [FromQuery] int? page = null,
            [FromQuery] int? pageSize = null)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only view your own notifications");

            var cursorStyle = limit != null || before != null;
            var pageStyle = page != null || pageSize != null;
            if (cursorStyle && pageStyle)
                return BadRequest(new { message = "Use either limit and before, or page and pageSize, not both." });

            if (limit < 1 || pageSize < 1 || before < 1 || page < 1)
                return BadRequest(new { message = "limit, before, page and pageSize must be positive numbers." });

            var count = Math.Min(limit ?? pageSize ?? DefaultCount, MaxCount);
            var query = _context.Notifications.Where(n => n.UserId == userId);
            if (before != null)
            {
                query = query.Where(n => n.Id < before);
            }

            // Ids grow with creation time, so the id order is the newest-first order and a stable cursor.
            query = query.OrderByDescending(n => n.Id);

            var skip = ((long)(page ?? 1) - 1) * count;
            if (skip > int.MaxValue)
                return Ok(Array.Empty<object>());

            var notifications = await query
                .Skip((int)skip)
                .Take(count)
                .ToListAsync();

            var result = notifications.Select(n => new
            {
                id = n.Id,
                title = n.Title,
                message = n.Message,
                type = n.Type,
                isRead = n.IsRead,
                referenceId = n.ReferenceId,
                createdAt = n.CreatedAt
            });

            return Ok(result);
        }

        // Every unread notification of the recipient, not only the ones on the first page.
        [HttpGet("{userId}/unread-count")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetUnreadCount(int userId)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only view your own notifications");

            return Ok(new { count = await _context.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead) });
        }

        [HttpPost("{id}/read")]
        [Authorize(Policy = AuthPolicies.MemberResourceOrDevFallback)]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            var notification = await _context.Notifications.FindAsync(id);
            if (notification == null)
            {
                return NotFound(new { message = "Notification not found" });
            }

            // Only the recipient. A tokenless request gets here only through the development fallback.
            if (_currentUser.IsAuthenticated && notification.UserId != _currentUser.UserId)
            {
                return AuthProblem.Forbidden(HttpContext, "You can only change your own notifications");
            }

            notification.IsRead = true;
            await _context.SaveChangesAsync();

            return Ok(new { message = "Marked as read" });
        }
    }
}