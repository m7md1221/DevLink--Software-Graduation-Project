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

        [HttpGet("{userId}")]
        public async Task<IActionResult> GetNotifications(int userId)
        {
            var notifications = await _context.Notifications
                .Where(n => n.UserId == userId)
                .OrderByDescending(n => n.CreatedAt)
                .Take(5)
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