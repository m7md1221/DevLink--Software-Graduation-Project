using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerProfileController : ControllerBase
    {
        private readonly AppDbContext _context;

        public CustomerProfileController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("{userId}")]
        public async Task<IActionResult> GetProfile(int userId)
        {
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
                createdAt = profile.CreatedAt
            });
        }

        [HttpPost]
        public async Task<IActionResult> CreateProfile(
            [FromForm] CreateProfileDto model)
        {
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
                .FirstOrDefaultAsync(u => u.Id == model.UserId);

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
                .AnyAsync(p => p.UserId == model.UserId);

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
                if (model.ProfileImage.Length > 2 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "Image size must be less than 2MB"
                    });
                }

                var allowed = new[]
                {
                    "image/jpeg",
                    "image/jpg",
                    "image/png",
                    "image/webp",
                    "application/octet-stream"
                };

                contentType = model.ProfileImage.ContentType
                    .ToLower();

                if (!allowed.Contains(contentType))
                {
                    return BadRequest(new
                    {
                        message =
                            "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                if (contentType == "application/octet-stream")
                {
                    var fileName = model.ProfileImage.FileName
                        .ToLower();

                    if (fileName.EndsWith(".png"))
                        contentType = "image/png";
                    else if (fileName.EndsWith(".webp"))
                        contentType = "image/webp";
                    else
                        contentType = "image/jpeg";
                }

                using var ms = new MemoryStream();
                await model.ProfileImage.CopyToAsync(ms);
                imageBytes = ms.ToArray();
            }

            var profile = new CustomerProfile
            {
                UserId = model.UserId,
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
        public async Task<IActionResult> UpdateProfile(
            int userId,
            [FromForm] UpdateProfileDto model)
        {
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
                if (model.ProfileImage.Length > 2 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "Image size must be less than 2MB"
                    });
                }

                var allowed = new[]
                {
                    "image/jpeg",
                    "image/jpg",
                    "image/png",
                    "image/webp",
                    "application/octet-stream"
                };

                var contentType = model.ProfileImage.ContentType
                    .ToLower();

                if (!allowed.Contains(contentType))
                {
                    return BadRequest(new
                    {
                        message =
                            "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                if (contentType == "application/octet-stream")
                {
                    var fileName = model.ProfileImage.FileName
                        .ToLower();

                    if (fileName.EndsWith(".png"))
                        contentType = "image/png";
                    else if (fileName.EndsWith(".webp"))
                        contentType = "image/webp";
                    else
                        contentType = "image/jpeg";
                }

                using var ms = new MemoryStream();
                await model.ProfileImage.CopyToAsync(ms);
                profile.ProfileImage = ms.ToArray();
                profile.ImageContentType = contentType;
            }

            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Profile updated successfully"
            });
        }

        [HttpGet("{userId}/image")]
        public async Task<IActionResult> GetProfileImage(int userId)
        {
            var profile = await _context.CustomerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile?.ProfileImage == null)
            {
                return NotFound(new
                {
                    message = "No image found"
                });
            }

            return File(
                profile.ProfileImage,
                profile.ImageContentType ?? "image/jpeg"
            );
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