using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;
using Services;
using Services.Auth;
using Services.Files;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerProfileController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentUser _currentUser;
        private readonly MediaUrls _media;
        private readonly PostService _posts;

        public CustomerProfileController(AppDbContext context, ICurrentUser currentUser, MediaUrls media, PostService posts)
        {
            _context = context;
            _currentUser = currentUser;
            _media = media;
            _posts = posts;
        }

        // Holds the phone number: the customer themself or an admin (design 8 #18).
        [HttpGet("{userId}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetProfile(int userId)
        {
            if (_currentUser.ResolveUserId(userId) != userId && !_currentUser.IsAdmin)
                return AuthProblem.Forbidden(HttpContext, "You can only view your own profile");

            var profile = await _context.CustomerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            return Ok(new
            {
                id = profile.Id,
                userId = profile.UserId,
                nickname = profile.Nickname,
                country = profile.Country,
                city = profile.City,
                phoneNumber = profile.PhoneNumber,
                hasImage = profile.ProfileImage != null,
                avatarUrl = profile.ProfileImage != null ? _media.AvatarUrl(profile.UserId) : null,
                createdAt = profile.CreatedAt
            });
        }

        [HttpPost]
        [Authorize(Policy = AuthPolicies.CustomerOrDevFallback)]
        public async Task<IActionResult> CreateProfile(
            [FromForm] CreateProfileDto model)
        {
            var userId = _currentUser.ResolveUserId(model.UserId) ?? 0;

            if (string.IsNullOrWhiteSpace(model.Nickname) ||
                string.IsNullOrWhiteSpace(model.Country) ||
                string.IsNullOrWhiteSpace(model.City) ||
                string.IsNullOrWhiteSpace(model.PhoneNumber))
            {
                return BadRequest(new
                {
                    message = "All fields are required"
                });
            }

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null)
            {
                return NotFound(new
                {
                    message = "User not found"
                });
            }

            if (user.UserType != "Customer")
            {
                return BadRequest(new
                {
                    message = "Only Customers can create a profile"
                });
            }

            var exists = await _context.CustomerProfiles
                .AnyAsync(p => p.UserId == userId);

            if (exists)
            {
                return BadRequest(new
                {
                    message = "Profile already exists for this user"
                });
            }

            byte[]? imageBytes = null;
            string? contentType = null;

            if (model.ProfileImage != null &&
                model.ProfileImage.Length > 0)
            {
                if (model.ProfileImage.Length > UploadValidator.MaxAvatarBytes)
                {
                    return BadRequest(new
                    {
                        message = "Image size must be less than 2MB"
                    });
                }

                var image = await UploadValidator.ReadImageAsync(model.ProfileImage);
                if (image == null)
                {
                    return BadRequest(new
                    {
                        message =
                            "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                imageBytes = image.Value.Data;
                contentType = image.Value.ContentType;
            }

            var profile = new CustomerProfile
            {
                UserId = userId,
                Nickname = model.Nickname.Trim(),
                Country = model.Country.Trim(),
                City = model.City.Trim(),
                PhoneNumber = model.PhoneNumber.Trim(),
                ProfileImage = imageBytes,
                ImageContentType = contentType,
                CreatedAt = DateTime.UtcNow
            };

            _context.CustomerProfiles.Add(profile);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Profile created successfully",
                profileId = profile.Id
            });
        }

        [HttpPut("{userId}")]
        [Authorize(Policy = AuthPolicies.CustomerOrDevFallback)]
        public async Task<IActionResult> UpdateProfile(
            int userId,
            [FromForm] UpdateProfileDto model)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own profile");

            var profile = await _context.CustomerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            if (!string.IsNullOrWhiteSpace(model.Nickname))
                profile.Nickname = model.Nickname.Trim();

            if (!string.IsNullOrWhiteSpace(model.Country))
                profile.Country = model.Country.Trim();

            if (!string.IsNullOrWhiteSpace(model.City))
                profile.City = model.City.Trim();

            if (!string.IsNullOrWhiteSpace(model.PhoneNumber))
                profile.PhoneNumber = model.PhoneNumber.Trim();

            if (model.ProfileImage != null &&
                model.ProfileImage.Length > 0)
            {
                if (model.ProfileImage.Length > UploadValidator.MaxAvatarBytes)
                {
                    return BadRequest(new
                    {
                        message = "Image size must be less than 2MB"
                    });
                }

                var image = await UploadValidator.ReadImageAsync(model.ProfileImage);
                if (image == null)
                {
                    return BadRequest(new
                    {
                        message =
                            "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                profile.ProfileImage = image.Value.Data;
                profile.ImageContentType = image.Value.ContentType;
            }

            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Profile updated successfully"
            });
        }

        // Only the customer's image; a signed URL for any avatar names the user, not the route (design 5.2).
        [HttpGet("{userId}/image")]
        [Authorize(Policy = AuthPolicies.SignedImageOrMember)]
        public async Task<IActionResult> GetProfileImage(int userId)
        {
            var isCustomer = await _context.CustomerProfiles.AnyAsync(p => p.UserId == userId);

            return ImageResponse.From(this, isCustomer ? await _posts.GetUserAvatar(userId) : null, "No image found");
        }
    }

    public class CreateProfileDto
    {
        public int UserId { get; set; }
        public string Nickname { get; set; }
        public string Country { get; set; }
        public string City { get; set; }
        public string PhoneNumber { get; set; }
        public IFormFile? ProfileImage { get; set; }
    }

    public class UpdateProfileDto
    {
        public string? Nickname { get; set; }
        public string? Country { get; set; }
        public string? City { get; set; }
        public string? PhoneNumber { get; set; }
        public IFormFile? ProfileImage { get; set; }
    }
}