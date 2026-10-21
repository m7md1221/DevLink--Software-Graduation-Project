using Microsoft.AspNetCore.Mvc;
using Services;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PostsController : ControllerBase
    {
        private readonly PostService _postService;
        private readonly EmailService _emailService;

        public PostsController(PostService postService, EmailService emailService)
        {
            _postService = postService;
            _emailService = emailService;
        }

        // ============================================================
        // FEED
        // ============================================================
        [HttpGet("feed")]
        public async Task<IActionResult> GetFeed(
            [FromQuery] int userId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            if (userId <= 0)
                return BadRequest(new { message = "userId is required" });

            var posts = await _postService.GetFeed(userId, page, pageSize);
            return Ok(new { posts });
        }

        [HttpGet("user/{userId}")]
        public async Task<IActionResult> GetUserPosts(
            int userId,
            [FromQuery] int currentUserId)
        {
            if (userId <= 0 || currentUserId <= 0)
                return BadRequest(new { message = "Invalid user id" });

            var posts = await _postService.GetPostsByUser(userId, currentUserId);
            return Ok(new { posts });
        }

        // ============================================================
        // CREATE POST
        // ============================================================
        [HttpPost]
        public async Task<IActionResult> CreatePost(
            [FromForm] CreatePostDto model)
        {
            if (model.UserId <= 0)
                return BadRequest(new { message = "userId is required" });

            var images = new List<(byte[], string)>();

            if (model.Images != null && model.Images.Count > 0)
            {
                if (model.Images.Count > 10)
                    return BadRequest(new { message = "Maximum 10 images per post" });

                foreach (var file in model.Images)
                {
                    if (file.Length > 5 * 1024 * 1024)
                        return BadRequest(new { message = "Each image must be less than 5MB" });

                    var ct = NormalizeImageType(file.ContentType, file.FileName);
                    if (ct == null)
                        return BadRequest(new { message = "Only JPG, PNG, WEBP images are allowed" });

                    using var ms = new MemoryStream();
                    await file.CopyToAsync(ms);
                    images.Add((ms.ToArray(), ct));
                }
            }

            var (success, message, postId) =
                await _postService.CreatePost(
                    model.UserId,
                    model.Content,
                    images.Count > 0 ? images : null);

            if (!success)
                return BadRequest(new { message });

            // ✅ الرسالة الجديدة
            return Ok(new
            {
                message = "Post submitted successfully. Your post is now pending admin approval.",
                postId
            });
        }

        // ============================================================
        // DELETE POST
        // ============================================================
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePost(
            int id,
            [FromQuery] int userId,
            [FromQuery] bool isAdmin = false)
        {
            if (userId <= 0)
                return BadRequest(new { message = "userId is required" });

            var (success, message) =
                await _postService.DeletePost(id, userId, isAdmin);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message });
        }

        // ============================================================
        // LIKE / UNLIKE
        // ============================================================
        [HttpPost("{id}/like")]
        public async Task<IActionResult> ToggleLike(
            int id,
            [FromBody] LikeDto model)
        {
            if (model.UserId <= 0)
                return BadRequest(new { message = "userId is required" });

            var (success, message, isLiked, likeCount) =
                await _postService.ToggleLike(id, model.UserId);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message, isLiked, likeCount });
        }

        // ============================================================
        // COMMENTS
        // ============================================================
        [HttpGet("{id}/comments")]
        public async Task<IActionResult> GetComments(int id)
        {
            var comments = await _postService.GetComments(id);
            return Ok(new { comments });
        }

        [HttpPost("{id}/comments")]
        public async Task<IActionResult> AddComment(
            int id,
            [FromBody] AddCommentDto model)
        {
            if (model.UserId <= 0)
                return BadRequest(new { message = "userId is required" });

            if (string.IsNullOrWhiteSpace(model.Content))
                return BadRequest(new { message = "Content is required" });

            var (success, message, commentId) =
                await _postService.AddComment(id, model.UserId, model.Content);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message, commentId });
        }

        [HttpDelete("comments/{commentId}")]
        public async Task<IActionResult> DeleteComment(
            int commentId,
            [FromQuery] int userId,
            [FromQuery] bool isAdmin = false)
        {
            if (userId <= 0)
                return BadRequest(new { message = "userId is required" });

            var (success, message) =
                await _postService.DeleteComment(commentId, userId, isAdmin);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message });
        }

        // ============================================================
        // IMAGES
        // ============================================================
        [HttpGet("image/{imageId}")]
        public async Task<IActionResult> GetPostImage(int imageId)
        {
            var result = await _postService.GetPostImage(imageId);

            if (result.data == null)
                return NotFound(new { message = "Image not found" });

            Response.Headers.Append("Cache-Control", "public, max-age=86400");
            return File(result.data, result.contentType ?? "image/jpeg");
        }

        [HttpGet("user/{userId}/avatar")]
        public async Task<IActionResult> GetUserAvatar(int userId)
        {
            var result = await _postService.GetUserAvatar(userId);

            if (result.data == null)
                return NotFound(new { message = "No avatar found" });

            Response.Headers.Append("Cache-Control", "public, max-age=3600");
            return File(result.data, result.contentType ?? "image/jpeg");
        }

        // ============================================================
        // SEARCH
        // ============================================================
        [HttpGet("search")]
        public async Task<IActionResult> Search(
            [FromQuery] string q,
            [FromQuery] string? userType = null)
        {
            if (string.IsNullOrWhiteSpace(q))
                return Ok(new { users = new List<object>() });

            var users = await _postService.SearchUsers(q, userType);
            return Ok(new { users });
        }

        // ============================================================
        // PUBLIC PROFILE
        // ============================================================
        [HttpGet("profile/{userId}")]
        public async Task<IActionResult> GetUserProfile(int userId)
        {
            var profile = await _postService.GetUserProfile(userId);

            if (profile == null)
                return NotFound(new { message = "Profile not found" });

            return Ok(profile);
        }

        // ============================================================
        // APPLY TO POST
        // ============================================================
        [HttpPost("{id}/apply")]
        public async Task<IActionResult> ApplyToPost(
            int id,
            [FromBody] ApplyToPostDto model)
        {
            if (model.ProgrammerId <= 0)
                return BadRequest(new { message = "ProgrammerId is required" });

            if (string.IsNullOrWhiteSpace(model.Proposal))
                return BadRequest(new { message = "Proposal is required" });

            var (success, message, applicationId) =
                await _postService.ApplyToPost(
                    id,
                    model.ProgrammerId,
                    model.Proposal,
                    model.Price,
                    model.Duration);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message, applicationId });
        }

        [HttpGet("{id}/applications")]
        public async Task<IActionResult> GetApplications(
            int id,
            [FromQuery] int requesterId)
        {
            if (requesterId <= 0)
                return BadRequest(new { message = "requesterId is required" });

            var applications = await _postService.GetPostApplications(id, requesterId);
            return Ok(new { applications });
        }

        [HttpPost("{id}/applications/{applicationId}/accept")]
        public async Task<IActionResult> AcceptApplication(
            int id,
            int applicationId,
            [FromQuery] int requesterId)
        {
            if (requesterId <= 0)
                return BadRequest(new { message = "requesterId is required" });

            var (success, message) = await _postService.AcceptApplication(
                id, applicationId, requesterId);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message });
        }

        [HttpGet("{id}/applications/count")]
        public async Task<IActionResult> GetApplicationsCount(int id)
        {
            var count = await _postService.GetApplicationsCount(id);
            return Ok(new { count });
        }

        [HttpGet("{id}/has-applied")]
        public async Task<IActionResult> HasUserApplied(
            int id,
            [FromQuery] int userId)
        {
            var hasApplied = await _postService.HasUserApplied(id, userId);
            return Ok(new { hasApplied });
        }

        // ============================================================
        // ADMIN: PENDING POSTS
        // ============================================================
        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingPosts()
        {
            var posts = await _postService.GetPendingPosts();
            return Ok(new { posts });
        }

        // ============================================================
        // ADMIN: APPROVE POST
        // ============================================================
        [HttpPost("{id}/approve")]
        public async Task<IActionResult> ApprovePost(int id)
        {
            var (success, message) = await _postService.ApprovePost(id);

            if (!success)
                return BadRequest(new { message });

            var authorEmail = await _postService.GetPostAuthorEmail(id);

            if (!string.IsNullOrEmpty(authorEmail))
            {
                try
                {
                    await _emailService.SendEmailAsync(
                        authorEmail,
                        "Your post has been approved ✅",
                        "Hi,\n\nYour post has been reviewed and approved by our team.\nIt is now live on DevLink!\n\nBest regards,\nDevLink Team"
                    );
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Email error: {ex.Message}");
                }
            }

            return Ok(new { message });
        }

        // ============================================================
        // ADMIN: REJECT POST
        // ============================================================
        [HttpPost("{id}/reject")]
        public async Task<IActionResult> RejectPost(
            int id,
            [FromBody] RejectPostDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Reason))
                return BadRequest(new { message = "Reason is required" });

            var (success, message) = await _postService.RejectPost(id, model.Reason);

            if (!success)
                return BadRequest(new { message });

            var authorEmail = await _postService.GetPostAuthorEmail(id);

            if (!string.IsNullOrEmpty(authorEmail))
            {
                try
                {
                    await _emailService.SendEmailAsync(
                        authorEmail,
                        "Your post has been rejected ❌",
                        $"Hi,\n\nUnfortunately, your post was rejected by our team.\n\nReason: {model.Reason}\n\nIf you think this is a mistake, please contact support.\n\nBest regards,\nDevLink Team"
                    );
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Email error: {ex.Message}");
                }
            }

            return Ok(new { message });
        }

        // ============================================================
        // HELPER
        // ============================================================
        private static string? NormalizeImageType(
            string contentType,
            string fileName)
        {
            var ct = contentType.ToLower();
            var fn = fileName.ToLower();

            var allowed = new[]
            {
                "image/jpeg",
                "image/jpg",
                "image/png",
                "image/webp",
                "application/octet-stream"
            };

            if (!allowed.Contains(ct))
                return null;

            if (ct == "application/octet-stream")
            {
                if (fn.EndsWith(".png")) return "image/png";
                if (fn.EndsWith(".webp")) return "image/webp";
                return "image/jpeg";
            }

            return ct;
        }
    }

    // ============================================================
    // DTOs
    // ============================================================
    public class CreatePostDto
    {
        public int UserId { get; set; }
        public string? Content { get; set; }
        public List<IFormFile>? Images { get; set; }
    }

    public class LikeDto
    {
        public int UserId { get; set; }
    }

    public class AddCommentDto
    {
        public int UserId { get; set; }
        public string Content { get; set; } = string.Empty;
    }

    public class ApplyToPostDto
    {
        public int ProgrammerId { get; set; }
        public string Proposal { get; set; } = string.Empty;
        public decimal? Price { get; set; }
        public string? Duration { get; set; }
    }

    public class RejectPostDto
    {
        public string Reason { get; set; } = string.Empty;
    }
}