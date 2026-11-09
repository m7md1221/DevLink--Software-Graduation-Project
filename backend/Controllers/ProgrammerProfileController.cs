using Services.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;
using Services;
using Services.Files;
using Services.Security;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProgrammerProfileController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentUser _currentUser;
        private readonly MediaUrls _media;
        private readonly PostService _posts;

        public ProgrammerProfileController(AppDbContext context, ICurrentUser currentUser, MediaUrls media, PostService posts)
        {
            _context = context;
            _currentUser = currentUser;
            _media = media;
            _posts = posts;
        }

        // Self or admin: full. Other members: phone and file names are null, keys kept (design 8 #22, D-5).
        [HttpGet("{userId}")]
        [Authorize(Policy = AuthPolicies.MemberOrDevFallback)]
        public async Task<IActionResult> GetProfile(int userId)
        {
            var full = _currentUser.ResolveUserId(userId) == userId || _currentUser.IsAdmin;

            var profile = await _context.ProgrammerProfiles
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
                phoneNumber = full ? profile.PhoneNumber : null,
                country = profile.Country,
                city = profile.City,
                specialty = profile.Specialty,
                university = profile.University,
                hasCertificate = profile.Certificate != null,
                hasCV = profile.CV != null,
                cvName = full ? profile.CVName : null,
                certificateName = full ? profile.CertificateName : null,
                linkedInUrl = profile.LinkedInUrl,
                rating = profile.Rating,
                isVerified = profile.IsVerified,
                hasImage = profile.ProfileImage != null,
                avatarUrl = profile.ProfileImage != null ? _media.AvatarUrl(profile.UserId) : null,
                createdAt = profile.CreatedAt
            });
        }

        // Admin only (D-4).
        [HttpGet("all")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)]
        public async Task<IActionResult> GetAllProgrammers()
        {
            var programmers = await _context.ProgrammerProfiles
                .OrderByDescending(p => p.Rating)
                .Select(p => new
                {
                    id = p.Id,
                    userId = p.UserId,
                    nickname = p.Nickname,
                    country = p.Country,
                    city = p.City,
                    specialty = p.Specialty,
                    university = p.University,
                    rating = p.Rating,
                    isVerified = p.IsVerified,
                    hasImage = p.ProfileImage != null
                })
                .ToListAsync();

            return Ok(programmers.Select(p => new
            {
                p.id,
                p.userId,
                p.nickname,
                p.country,
                p.city,
                p.specialty,
                p.university,
                p.rating,
                p.isVerified,
                p.hasImage,
                avatarUrl = p.hasImage ? _media.AvatarUrl(p.userId) : null
            }));
        }

        [HttpPost]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> CreateProfile(
            [FromForm] CreateProgrammerProfileDto model)
        {
            var userId = _currentUser.ResolveUserId(model.UserId) ?? 0;

            if (string.IsNullOrWhiteSpace(model.Nickname) ||
                string.IsNullOrWhiteSpace(model.PhoneNumber) ||
                string.IsNullOrWhiteSpace(model.Country) ||
                string.IsNullOrWhiteSpace(model.City) ||
                string.IsNullOrWhiteSpace(model.Specialty) ||
                string.IsNullOrWhiteSpace(model.University))
            {
                return BadRequest(new
                {
                    message = "All required fields must be filled"
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

            if (user.UserType != "Programmer")
            {
                return BadRequest(new
                {
                    message = "Only Programmers can create a profile"
                });
            }

            var exists = await _context.ProgrammerProfiles
                .AnyAsync(p => p.UserId == userId);

            if (exists)
            {
                return BadRequest(new
                {
                    message = "Profile already exists for this user"
                });
            }

            byte[]? imageBytes = null;
            string? imageContentType = null;

            if (model.ProfileImage != null &&
                model.ProfileImage.Length > 0)
            {
                if (model.ProfileImage.Length > UploadValidator.MaxAvatarBytes)
                {
                    return BadRequest(new
                    {
                        message = "Profile image must be less than 2MB"
                    });
                }

                var image = await UploadValidator.ReadImageAsync(model.ProfileImage);
                if (image == null)
                {
                    return BadRequest(new
                    {
                        message = "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                imageBytes = image.Value.Data;
                imageContentType = image.Value.ContentType;
            }

            byte[]? certBytes = null;
            string? certType = null;
            string? certName = null;

            if (model.Certificate != null &&
                model.Certificate.Length > 0)
            {
                if (model.Certificate.Length > UploadValidator.MaxDocumentBytes)
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be less than 5MB"
                    });
                }

                var certificate = await UploadValidator.ReadCertificateAsync(model.Certificate);
                if (certificate == null)
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be PDF, JPG, JPEG, or PNG"
                    });
                }

                certBytes = certificate.Value.Data;
                certType = certificate.Value.ContentType;
                certName = UploadValidator.SafeFileName(model.Certificate.FileName, "certificate");
            }

            byte[]? cvBytes = null;
            string? cvName = null;

            if (model.CV != null && model.CV.Length > 0)
            {
                if (model.CV.Length > UploadValidator.MaxDocumentBytes)
                {
                    return BadRequest(new
                    {
                        message = "CV must be less than 5MB"
                    });
                }

                cvBytes = await UploadValidator.ReadCvAsync(model.CV);
                if (cvBytes == null)
                {
                    return BadRequest(new
                    {
                        message = "CV must be a PDF file"
                    });
                }

                cvName = UploadValidator.SafeFileName(model.CV.FileName, "cv.pdf");
            }

            var profile = new ProgrammerProfile
            {
                UserId = userId,
                Nickname = model.Nickname.Trim(),
                PhoneNumber = model.PhoneNumber.Trim(),
                Country = model.Country.Trim(),
                City = model.City.Trim(),
                Specialty = model.Specialty.Trim(),
                University = model.University.Trim(),
                Certificate = certBytes,
                CertificateType = certType,
                CertificateName = certName,
                CV = cvBytes,
                CVName = cvName,
                LinkedInUrl = string.IsNullOrWhiteSpace(model.LinkedInUrl)
                    ? null
                    : model.LinkedInUrl.Trim(),
                Rating = 0,
                IsVerified = false,
                ProfileImage = imageBytes,
                ImageContentType = imageContentType,
                CreatedAt = DateTime.UtcNow
            };

            _context.ProgrammerProfiles.Add(profile);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Profile created successfully",
                profileId = profile.Id
            });
        }

        [HttpPut("{userId}")]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> UpdateProfile(
            int userId,
            [FromForm] UpdateProgrammerProfileDto model)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own profile");

            var profile = await _context.ProgrammerProfiles
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

            if (!string.IsNullOrWhiteSpace(model.PhoneNumber))
                profile.PhoneNumber = model.PhoneNumber.Trim();

            if (!string.IsNullOrWhiteSpace(model.Country))
                profile.Country = model.Country.Trim();

            if (!string.IsNullOrWhiteSpace(model.City))
                profile.City = model.City.Trim();

            if (!string.IsNullOrWhiteSpace(model.Specialty))
                profile.Specialty = model.Specialty.Trim();

            if (!string.IsNullOrWhiteSpace(model.University))
                profile.University = model.University.Trim();

            if (model.LinkedInUrl != null)
                profile.LinkedInUrl = string.IsNullOrWhiteSpace(model.LinkedInUrl)
                    ? null
                    : model.LinkedInUrl.Trim();

            if (model.ProfileImage != null &&
                model.ProfileImage.Length > 0)
            {
                if (model.ProfileImage.Length > UploadValidator.MaxAvatarBytes)
                {
                    return BadRequest(new
                    {
                        message = "Profile image must be less than 2MB"
                    });
                }

                var image = await UploadValidator.ReadImageAsync(model.ProfileImage);
                if (image == null)
                {
                    return BadRequest(new
                    {
                        message = "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                profile.ProfileImage = image.Value.Data;
                profile.ImageContentType = image.Value.ContentType;
            }

            if (model.Certificate != null &&
                model.Certificate.Length > 0)
            {
                if (model.Certificate.Length > UploadValidator.MaxDocumentBytes)
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be less than 5MB"
                    });
                }

                var certificate = await UploadValidator.ReadCertificateAsync(model.Certificate);
                if (certificate == null)
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be PDF, JPG, JPEG, or PNG"
                    });
                }

                profile.Certificate = certificate.Value.Data;
                profile.CertificateType = certificate.Value.ContentType;
                profile.CertificateName = UploadValidator.SafeFileName(model.Certificate.FileName, "certificate");

                // ✅ إعادة التوثيق إجبارياً
                profile.IsVerified = false;
            }

            if (model.CV != null && model.CV.Length > 0)
            {
                if (model.CV.Length > UploadValidator.MaxDocumentBytes)
                {
                    return BadRequest(new
                    {
                        message = "CV must be less than 5MB"
                    });
                }

                var cv = await UploadValidator.ReadCvAsync(model.CV);
                if (cv == null)
                {
                    return BadRequest(new
                    {
                        message = "CV must be a PDF file"
                    });
                }

                profile.CV = cv;
                profile.CVName = UploadValidator.SafeFileName(model.CV.FileName, "cv.pdf");
            }

            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Profile updated successfully"
            });
        }

        // Only the programmer's image; a signed URL for any avatar names the user, not the route (design 5.2).
        [HttpGet("{userId}/image")]
        [Authorize(Policy = AuthPolicies.SignedImageOrMember)]
        public async Task<IActionResult> GetProfileImage(int userId)
        {
            var isProgrammer = await _context.ProgrammerProfiles.AnyAsync(p => p.UserId == userId);

            return ImageResponse.From(this, isProgrammer ? await _posts.GetUserAvatar(userId) : null, "No image found");
        }

        // Private documents (design 8 #27): the programmer, an admin, or a customer the programmer applied to.
        private async Task<bool> CanReadDocumentsAsync(int programmerId)
        {
            if (!_currentUser.IsAuthenticated)
            {
                return true; // Only the development fallback gets here without a token.
            }

            return await ProgrammerDocuments.CanReadAsync(_context, programmerId, _currentUser.UserId!.Value, _currentUser.Role);
        }

        private async Task<IActionResult> DirectDocumentAsync(int userId, string kind, string notFoundMessage)
        {
            if (!await CanReadDocumentsAsync(userId))
                return AuthProblem.Forbidden(HttpContext, "You can't view this document");

            var (data, name) = await ProgrammerDocuments.LoadAsync(_context, userId, kind);
            if (data == null)
            {
                return NotFound(new
                {
                    message = notFoundMessage
                });
            }

            return ProgrammerDocuments.Respond(this, kind, data, name);
        }

        [HttpGet("{userId}/cv")]
        [Authorize(Policy = AuthPolicies.MemberFileOrDevFallback)]
        public Task<IActionResult> GetCV(int userId) => DirectDocumentAsync(userId, DocumentKinds.Cv, "No CV found");

        [HttpGet("{userId}/certificate")]
        [Authorize(Policy = AuthPolicies.MemberFileOrDevFallback)]
        public Task<IActionResult> GetCertificate(int userId) => DirectDocumentAsync(userId, DocumentKinds.Certificate, "No certificate found");

        // ============================================================
        // DOWNLOAD LINKS (design 5.1): for opening a document in a new
        // browser tab. An access token only, never the development fallback.
        // ============================================================

        [HttpPost("{userId}/cv/link")]
        [Authorize]
        public Task<IActionResult> IssueCvLink(int userId, [FromServices] DownloadLinkStore links, [FromServices] TimeProvider time) =>
            IssueLinkAsync(userId, DocumentKinds.Cv, "No CV found", links, time);

        [HttpPost("{userId}/certificate/link")]
        [Authorize]
        public Task<IActionResult> IssueCertificateLink(int userId, [FromServices] DownloadLinkStore links, [FromServices] TimeProvider time) =>
            IssueLinkAsync(userId, DocumentKinds.Certificate, "No certificate found", links, time);

        private async Task<IActionResult> IssueLinkAsync(int userId, string kind, string notFoundMessage, DownloadLinkStore links, TimeProvider time)
        {
            Response.Headers.CacheControl = "no-store";

            var callerId = _currentUser.UserId;
            if (callerId == null || !Guid.TryParse(User.FindFirst(AuthClaims.SessionId)?.Value, out var sessionId) ||
                !await CanReadDocumentsAsync(userId))
            {
                return AuthProblem.Forbidden(HttpContext, "You can't view this document");
            }

            var now = time.GetUtcNow().UtcDateTime;
            if (!links.TryCountIssue(callerId.Value, now))
            {
                return AuthProblem.Result(HttpContext, StatusCodes.Status429TooManyRequests, AuthErrorCodes.RateLimited,
                    "Too many download links. Please wait a few minutes and try again.");
            }

            var (data, _) = await ProgrammerDocuments.LoadAsync(_context, userId, kind);
            if (data == null)
            {
                return NotFound(new
                {
                    message = notFoundMessage
                });
            }

            var token = links.Add(new DownloadLink(
                userId, kind, System.Security.Cryptography.SHA256.HashData(data), callerId.Value, sessionId, now, now + DownloadLinkStore.Lifetime));

            return Ok(new
            {
                url = $"{Request.Scheme}://{Request.Host}/api/Files/download?t={token}",
                expiresInSeconds = (int)DownloadLinkStore.Lifetime.TotalSeconds
            });
        }

        // ============================================================
        // CV MANAGEMENT
        // ============================================================

        [HttpPost("{userId}/cv")]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> UploadCV(
            int userId,
            IFormFile cv)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own profile");

            if (cv == null || cv.Length == 0)
            {
                return BadRequest(new
                {
                    message = "CV file is required"
                });
            }

            if (cv.Length > UploadValidator.MaxDocumentBytes)
            {
                return BadRequest(new
                {
                    message = "CV must be less than 5MB"
                });
            }

            var data = await UploadValidator.ReadCvAsync(cv);
            if (data == null)
            {
                return BadRequest(new
                {
                    message = "CV must be a PDF file"
                });
            }

            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            profile.CV = data;
            profile.CVName = UploadValidator.SafeFileName(cv.FileName, "cv.pdf");
            profile.UpdatedAt = DateTime.UtcNow;

            // ⚠️ CV ما يأثر على التوثيق
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "CV uploaded successfully",
                cvName = profile.CVName
            });
        }

        [HttpDelete("{userId}/cv")]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> DeleteCV(int userId)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own profile");

            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            if (profile.CV == null)
            {
                return BadRequest(new
                {
                    message = "No CV to delete"
                });
            }

            profile.CV = null;
            profile.CVName = null;
            profile.UpdatedAt = DateTime.UtcNow;

            // ⚠️ حذف CV ما يأثر على التوثيق
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "CV deleted successfully"
            });
        }

        // ============================================================
        // CERTIFICATE MANAGEMENT
        // ============================================================

        [HttpPost("{userId}/certificate")]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> UploadCertificate(
            int userId,
            IFormFile certificate)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own profile");

            if (certificate == null || certificate.Length == 0)
            {
                return BadRequest(new
                {
                    message = "Certificate file is required"
                });
            }

            if (certificate.Length > UploadValidator.MaxDocumentBytes)
            {
                return BadRequest(new
                {
                    message = "Certificate must be less than 5MB"
                });
            }

            var file = await UploadValidator.ReadCertificateAsync(certificate);
            if (file == null)
            {
                return BadRequest(new
                {
                    message = "Certificate must be PDF, JPG, JPEG, or PNG"
                });
            }

            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            profile.Certificate = file.Value.Data;
            profile.CertificateType = file.Value.ContentType;
            profile.CertificateName = UploadValidator.SafeFileName(certificate.FileName, "certificate");

            // ✅✅✅ إلغاء التوثيق إجبارياً
            profile.IsVerified = false;

            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Certificate uploaded successfully. Your verification has been removed and is pending admin review.",
                certificateName = profile.CertificateName,
                isVerified = false
            });
        }

        [HttpDelete("{userId}/certificate")]
        [Authorize(Policy = AuthPolicies.ProgrammerOrDevFallback)]
        public async Task<IActionResult> DeleteCertificate(int userId)
        {
            if (_currentUser.ResolveUserId(userId) != userId)
                return AuthProblem.Forbidden(HttpContext, "You can only change your own profile");

            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            if (profile.Certificate == null)
            {
                return BadRequest(new
                {
                    message = "No certificate to delete"
                });
            }

            profile.Certificate = null;
            profile.CertificateType = null;
            profile.CertificateName = null;

            // ✅✅✅ إلغاء التوثيق إجبارياً
            profile.IsVerified = false;

            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Certificate deleted successfully. Your verification has been removed.",
                isVerified = false
            });
        }

        [HttpPost("{userId}/verify")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> VerifyProgrammer(int userId)
        {
            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            profile.IsVerified = true;
            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Programmer verified successfully"
            });
        }

        [HttpPost("{userId}/unverify")]
        [Authorize(Policy = AuthPolicies.AdminOrDevFallback)] // M2.7a: Admin token (dev fallback: D-1)
        public async Task<IActionResult> UnverifyProgrammer(int userId)
        {
            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile == null)
            {
                return NotFound(new
                {
                    message = "Profile not found"
                });
            }

            profile.IsVerified = false;
            profile.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Programmer unverified successfully"
            });
        }
    }

    public class CreateProgrammerProfileDto
    {
        public int UserId { get; set; }
        public string Nickname { get; set; }
        public string PhoneNumber { get; set; }
        public string Country { get; set; }
        public string City { get; set; }
        public string Specialty { get; set; }
        public string University { get; set; }
        public string? LinkedInUrl { get; set; }
        public IFormFile? Certificate { get; set; }
        public IFormFile? CV { get; set; }
        public IFormFile? ProfileImage { get; set; }
    }

    public class UpdateProgrammerProfileDto
    {
        public string? Nickname { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Country { get; set; }
        public string? City { get; set; }
        public string? Specialty { get; set; }
        public string? University { get; set; }
        public string? LinkedInUrl { get; set; }
        public IFormFile? Certificate { get; set; }
        public IFormFile? CV { get; set; }
        public IFormFile? ProfileImage { get; set; }
    }
}