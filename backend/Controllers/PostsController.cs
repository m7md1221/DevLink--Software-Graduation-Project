using Services.Auth;
using Services.Files;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services;
using DataBase;
using Microsoft.EntityFrameworkCore;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PostsController : ControllerBase
    {
        private readonly PostService _postService;
        private readonly IEmailSender _emailService;
        private readonly AppDbContext _context;
        private readonly ICurrentUser _currentUser;

        public PostsController(PostService postService, IEmailSender emailService, AppDbContext context, ICurrentUser currentUser)
        {
            _postService = postService;
            _emailService = emailService;
            _context = context;
            _currentUser = currentUser;
        }

        // Generic error with a trace id (KI-29): the exception text can hold URLs and coordinates, so only its type is logged.
        private ObjectResult WeatherFailed(Exception ex)
        {
            HttpContext.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("DevLink.Weather")
                .LogError("Weather.Failed {FailureType}", ex.GetType().Name);

            return StatusCode(500, new
            {
                message = "Failed to fetch weather",
                traceId = System.Diagnostics.Activity.Current?.Id ?? HttpContext.TraceIdentifier
            });
        }

        // M2.7b: refusals keep today's 400 { message }; ownership refusals are 403 FORBIDDEN with the same message.
        private IActionResult Refused(PostActionStatus status, string message) =>
            status == PostActionStatus.Forbidden
                ? AuthProblem.Forbidden(HttpContext, message)
                : BadRequest(new { message });

        // ============================================================
        // Helper: Get City from Coordinates using Nominatim
        // ============================================================
        private async Task<string> GetCityFromCoordinates(double lat, double lon, HttpClient client)
        {
            try
            {
                var url = $"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lon}&accept-language=en";
                client.DefaultRequestHeaders.UserAgent.ParseAdd("DevLinkApp/1.0");

                var response = await client.GetAsync(url);
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    using var doc = System.Text.Json.JsonDocument.Parse(json);

                    if (doc.RootElement.TryGetProperty("address", out var address))
                    {
                        if (address.TryGetProperty("city", out var city) && !string.IsNullOrEmpty(city.GetString()))
                            return city.GetString()!;
                        if (address.TryGetProperty("town", out var town) && !string.IsNullOrEmpty(town.GetString()))
                            return town.GetString()!;
                        if (address.TryGetProperty("village", out var village) && !string.IsNullOrEmpty(village.GetString()))
                            return village.GetString()!;
                        if (address.TryGetProperty("state", out var state) && !string.IsNullOrEmpty(state.GetString()))
                            return state.GetString()!;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Nominatim Error: {ex.Message}");
            }
            return "Your Location";
        }

        // ============================================================
        // FEED
        // ============================================================
        [HttpGet("feed")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetFeed(
            [FromQuery] int userId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            var callerId = _currentUser.ResolveUserId(userId);
            if (callerId is null or <= 0)
                return BadRequest(new { message = "userId is required" });

            var posts = await _postService.GetFeed(callerId.Value, page, pageSize);
            return Ok(new { posts });
        }

        [HttpGet("user/{userId}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetUserPosts(
            int userId,
            [FromQuery] int currentUserId)
        {
            var callerId = _currentUser.ResolveUserId(currentUserId);
            if (userId <= 0 || callerId is null or <= 0)
                return BadRequest(new { message = "Invalid user id" });

            var posts = await _postService.GetPostsByUser(userId, callerId.Value);
            return Ok(new { posts });
        }

        [HttpPost]
        [Authorize(Policy = AuthPolicies.NonAdminOrDevFallback)]
        public async Task<IActionResult> CreatePost(
            [FromForm] CreatePostDto model)
        {
            var userId = _currentUser.ResolveUserId(model.UserId);
            if (userId is null or <= 0)
                return BadRequest(new { message = "userId is required" });

            var images = new List<(byte[], string)>();

            if (model.Images != null && model.Images.Count > 0)
            {
                if (model.Images.Count > 10)
                    return BadRequest(new { message = "Maximum 10 images per post" });

                foreach (var file in model.Images)
                {
                    if (file.Length > UploadValidator.MaxPostImageBytes)
                        return BadRequest(new { message = "Each image must be less than 5MB" });

                    var image = await UploadValidator.ReadImageAsync(file);
                    if (image == null)
                        return BadRequest(new { message = "Only JPG, PNG, WEBP images are allowed" });

                    images.Add((image.Value.Data, image.Value.ContentType));
                }
            }

            var (success, message, postId) =
                await _postService.CreatePost(
                    userId.Value,
                    model.Content,
                    images.Count > 0 ? images : null);

            if (!success)
                return BadRequest(new { message });

            return Ok(new
            {
                message = "Post submitted successfully. Your post is now pending admin approval.",
                postId
            });
        }

        [HttpDelete("{id}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> DeletePost(
            int id,
            [FromQuery] int userId)
        {
            var callerId = _currentUser.ResolveUserId(userId);
            if (callerId is null or <= 0)
                return BadRequest(new { message = "userId is required" });

            var (status, message) =
                await _postService.DeletePost(id, callerId.Value, _currentUser.IsAdmin);

            if (status != PostActionStatus.Ok)
                return Refused(status, message);

            return Ok(new { message });
        }

        [HttpPost("{id}/like")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> ToggleLike(
            int id,
            [FromBody] LikeDto model)
        {
            var userId = _currentUser.ResolveUserId(model.UserId);
            if (userId is null or <= 0)
                return BadRequest(new { message = "userId is required" });

            var (success, message, isLiked, likeCount) =
                await _postService.ToggleLike(id, userId.Value);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message, isLiked, likeCount });
        }

        [HttpGet("{id}/comments")]
        [Authorize(Policy = AuthPolicies.MemberResourceOrDevFallback)]
        public async Task<IActionResult> GetComments(int id)
        {
            if (!_currentUser.IsAdmin && !await _postService.CommentsVisibleTo(id, _currentUser.UserId))
                return AuthProblem.Forbidden(HttpContext, "These comments are not available");

            var comments = await _postService.GetComments(id);
            return Ok(new { comments });
        }

        [HttpPost("{id}/comments")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> AddComment(
            int id,
            [FromBody] AddCommentDto model)
        {
            var userId = _currentUser.ResolveUserId(model.UserId);
            if (userId is null or <= 0)
                return BadRequest(new { message = "userId is required" });

            if (string.IsNullOrWhiteSpace(model.Content))
                return BadRequest(new { message = "Content is required" });

            var (success, message, commentId) =
                await _postService.AddComment(id, userId.Value, model.Content);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message, commentId });
        }

        [HttpDelete("comments/{commentId}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> DeleteComment(
            int commentId,
            [FromQuery] int userId)
        {
            var callerId = _currentUser.ResolveUserId(userId);
            if (callerId is null or <= 0)
                return BadRequest(new { message = "userId is required" });

            var (status, message) =
                await _postService.DeleteComment(commentId, callerId.Value, _currentUser.IsAdmin);

            if (status != PostActionStatus.Ok)
                return Refused(status, message);

            return Ok(new { message });
        }

        [HttpGet("image/{imageId}")]
        [Authorize(Policy = AuthPolicies.SignedImageOrMember)]
        public async Task<IActionResult> GetPostImage(int imageId)
        {
            // Past the policy without a signature or a token: only the development fallback.
            var signedOrFallback = HttpContext.Items.ContainsKey(SignedImageHandler.VerifiedItem) || !_currentUser.IsAuthenticated;
            var data = await _postService.GetPostImage(imageId, signedOrFallback, _currentUser.UserId, _currentUser.IsAdmin);

            return ImageResponse.From(this, data, "Image not found");
        }

        [HttpGet("user/{userId}/avatar")]
        [Authorize(Policy = AuthPolicies.SignedImageOrMember)]
        public async Task<IActionResult> GetUserAvatar(int userId)
        {
            return ImageResponse.From(this, await _postService.GetUserAvatar(userId), "No avatar found");
        }

        [HttpGet("search")]
        [Authorize(Policy = AuthPolicies.MemberResourceOrDevFallback)]
        public async Task<IActionResult> Search(
            [FromQuery] string q,
            [FromQuery] string? userType = null)
        {
            if (string.IsNullOrWhiteSpace(q))
                return Ok(new { users = new List<object>() });

            var users = await _postService.SearchUsers(q, userType, _currentUser.IsAdmin);
            return Ok(new { users });
        }

        // A tokenless (development fallback) caller is nobody in particular, so it gets the public fields.
        [HttpGet("profile/{userId}")]
        [Authorize(Policy = AuthPolicies.MemberResourceOrDevFallback)]
        public async Task<IActionResult> GetUserProfile(int userId)
        {
            var profile = await _postService.GetUserProfile(userId, _currentUser.UserId == userId || _currentUser.IsAdmin);

            if (profile == null)
                return NotFound(new { message = "Profile not found" });

            return Ok(profile);
        }

        [HttpPost("{id}/apply")]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> ApplyToPost(
            int id,
            [FromBody] ApplyToPostDto model)
        {
            var programmerId = _currentUser.ResolveUserId(model.ProgrammerId);
            if (programmerId is null or <= 0)
                return BadRequest(new { message = "ProgrammerId is required" });

            if (string.IsNullOrWhiteSpace(model.Proposal))
                return BadRequest(new { message = "Proposal is required" });

            var (success, message, applicationId) =
                await _postService.ApplyToPost(
                    id,
                    programmerId.Value,
                    model.Proposal,
                    model.Price,
                    model.Duration);

            if (!success)
                return BadRequest(new { message });

            return Ok(new { message, applicationId });
        }

        // Post owner only: applicants' emails are visible only to the post owner until M2.12 (D-6, KI-53).
        [HttpGet("{id}/applications")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetApplications(
            int id,
            [FromQuery] int requesterId)
        {
            var callerId = _currentUser.ResolveUserId(requesterId);
            if (callerId is null or <= 0)
                return BadRequest(new { message = "requesterId is required" });

            var ownerId = await _postService.GetPostOwnerId(id);
            if (ownerId != null && ownerId != callerId)
                return AuthProblem.Forbidden(HttpContext, "You can only manage your own posts");

            var applications = await _postService.GetPostApplications(id, callerId.Value);
            return Ok(new { applications });
        }

        // The post owner, who must be a customer (D-11, design 8 #51).
        [HttpPost("{id}/applications/{applicationId}/accept")]
        [Authorize(Policy = AuthPolicies.CustomerOrDevFallback)]
        public async Task<IActionResult> AcceptApplication(
            int id,
            int applicationId,
            [FromQuery] int requesterId)
        {
            var callerId = _currentUser.ResolveUserId(requesterId);
            if (callerId is null or <= 0)
                return BadRequest(new { message = "requesterId is required" });

            var (status, message) = await _postService.AcceptApplication(
                id, applicationId, callerId.Value);

            if (status != PostActionStatus.Ok)
                return Refused(status, message);

            return Ok(new { message });
        }

        [HttpGet("{id}/applications/count")]
        [Authorize(Policy = AuthPolicies.MemberResourceOrDevFallback)]
        public async Task<IActionResult> GetApplicationsCount(int id)
        {
            var count = await _postService.GetApplicationsCount(id);
            return Ok(new { count });
        }

        [HttpGet("{id}/has-applied")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> HasUserApplied(
            int id,
            [FromQuery] int userId)
        {
            var hasApplied = await _postService.HasUserApplied(id, _currentUser.ResolveUserId(userId) ?? 0);
            return Ok(new { hasApplied });
        }

        [HttpGet("pending")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> GetPendingPosts()
        {
            var posts = await _postService.GetPendingPosts();
            return Ok(new { posts });
        }

        [HttpPost("{id}/approve")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
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

        [HttpPost("{id}/reject")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
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
        // WEATHER ENDPOINTS
        // ============================================================
        // Only the user themself: the result reveals the user's city (owner rule, M2.7c).
        [HttpGet("weather/{userId}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetWeather(int userId)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only view your own weather");

            var user = await _context.Users.FindAsync(userId);
            if (user == null) return NotFound(new { message = "User not found" });

            string city = "Ramallah";

            if (user.UserType == "Customer")
            {
                var profile = await _context.CustomerProfiles.FirstOrDefaultAsync(c => c.UserId == userId);
                if (profile != null && !string.IsNullOrWhiteSpace(profile.City))
                    city = profile.City;
            }
            else if (user.UserType == "Programmer")
            {
                var profile = await _context.ProgrammerProfiles.FirstOrDefaultAsync(c => c.UserId == userId);
                if (profile != null && !string.IsNullOrWhiteSpace(profile.City))
                    city = profile.City;
            }

            try
            {
                using var client = new HttpClient();
                
                async Task<(double lat, double lon, string country)?> GetCoordinates(string cityName)
                {
                    var url = $"https://geocoding-api.open-meteo.com/v1/search?name={Uri.EscapeDataString(cityName)}&count=1&language=en&format=json";
                    var response = await client.GetAsync(url);
                    if (!response.IsSuccessStatusCode) return null;
                    
                    var json = await response.Content.ReadAsStringAsync();
                    using var doc = System.Text.Json.JsonDocument.Parse(json);
                    
                    if (!doc.RootElement.TryGetProperty("results", out var results) || results.GetArrayLength() == 0)
                        return null;

                    var first = results[0];
                    var lat = first.GetProperty("latitude").GetDouble();
                    var lon = first.GetProperty("longitude").GetDouble();
                    var country = first.TryGetProperty("country", out var c) ? c.GetString() : "";
                    return (lat, lon, country ?? "");
                }

                var coords = await GetCoordinates(city);
                if (coords == null) coords = await GetCoordinates($"{city}, Palestine");
                if (coords == null) { city = "Ramallah"; coords = await GetCoordinates("Ramallah"); }
                if (coords == null) return StatusCode(500, new { message = "Could not find city coordinates" });

                var (lat, lon, country) = coords.Value;

                var weatherUrl = $"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto";
                var weatherResponse = await client.GetAsync(weatherUrl);
                if (!weatherResponse.IsSuccessStatusCode) return StatusCode(500, new { message = "Failed to fetch weather" });

                var weatherJson = await weatherResponse.Content.ReadAsStringAsync();
                using var weatherDoc = System.Text.Json.JsonDocument.Parse(weatherJson);
                
                var current = weatherDoc.RootElement.GetProperty("current");
                var temp = current.GetProperty("temperature_2m").GetDouble();
                var weatherCode = current.GetProperty("weather_code").GetInt32();
                var windSpeed = current.GetProperty("wind_speed_10m").GetDouble();
                var timezone = weatherDoc.RootElement.GetProperty("timezone").GetString();

                return Ok(new
                {
                    city = city,
                    country = country,
                    temperature = temp,
                    weatherCode = weatherCode,
                    windSpeed = windSpeed,
                    timezone = timezone,
                    latitude = lat,
                    longitude = lon
                });
            }
            catch (Exception ex)
            {
                return WeatherFailed(ex);
            }
        }

        [HttpGet("weather-location")]
        [Authorize(Policy = AuthPolicies.MemberResourceOrDevFallback)]
        public async Task<IActionResult> GetWeatherByLocation([FromQuery] double lat, [FromQuery] double lon)
        {
            try
            {
                using var client = new HttpClient();
                
                var weatherUrl = $"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto";
                var weatherResponse = await client.GetAsync(weatherUrl);
                if (!weatherResponse.IsSuccessStatusCode) return StatusCode(500, new { message = "Failed to fetch weather" });

                var weatherJson = await weatherResponse.Content.ReadAsStringAsync();
                using var weatherDoc = System.Text.Json.JsonDocument.Parse(weatherJson);
                
                var current = weatherDoc.RootElement.GetProperty("current");
                var temp = current.GetProperty("temperature_2m").GetDouble();
                var weatherCode = current.GetProperty("weather_code").GetInt32();
                var windSpeed = current.GetProperty("wind_speed_10m").GetDouble();
                var timezone = weatherDoc.RootElement.GetProperty("timezone").GetString();

                // ✅ استخدام Nominatim لجلب اسم المدينة
                string cityName = await GetCityFromCoordinates(lat, lon, client);

                return Ok(new
                {
                    city = cityName,
                    country = "",
                    temperature = temp,
                    weatherCode = weatherCode,
                    windSpeed = windSpeed,
                    timezone = timezone,
                    latitude = lat,
                    longitude = lon
                });
            }
            catch (Exception ex)
            {
                return WeatherFailed(ex);
            }
        }
    }

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