using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DataBase;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProgrammerProfileController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ProgrammerProfileController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("{userId}")]
        public async Task<IActionResult> GetProfile(int userId)
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

            return Ok(new
            {
                id = profile.Id,
                userId = profile.UserId,
                nickname = profile.Nickname,
                phoneNumber = profile.PhoneNumber,
                country = profile.Country,
                city = profile.City,
                specialty = profile.Specialty,
                university = profile.University,
                hasCertificate = profile.Certificate != null,
                hasCV = profile.CV != null,
                cvName = profile.CVName,
                certificateName = profile.CertificateName,
                linkedInUrl = profile.LinkedInUrl,
                rating = profile.Rating,
                isVerified = profile.IsVerified,
                hasImage = profile.ProfileImage != null,
                createdAt = profile.CreatedAt
            });
        }

        [HttpGet("all")]
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

            return Ok(programmers);
        }

        [HttpPost]
        public async Task<IActionResult> CreateProfile(
            [FromForm] CreateProgrammerProfileDto model)
        {
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
                .FirstOrDefaultAsync(u => u.Id == model.UserId);

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
                .AnyAsync(p => p.UserId == model.UserId);

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
                if (model.ProfileImage.Length > 2 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "Profile image must be less than 2MB"
                    });
                }

                imageContentType = NormalizeImageType(
                    model.ProfileImage.ContentType,
                    model.ProfileImage.FileName);

                if (imageContentType == null)
                {
                    return BadRequest(new
                    {
                        message = "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                using var ms = new MemoryStream();
                await model.ProfileImage.CopyToAsync(ms);
                imageBytes = ms.ToArray();
            }

            byte[]? certBytes = null;
            string? certType = null;
            string? certName = null;

            if (model.Certificate != null &&
                model.Certificate.Length > 0)
            {
                if (model.Certificate.Length > 5 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be less than 5MB"
                    });
                }

                var certFileName = model.Certificate.FileName.ToLower();
                if (!certFileName.EndsWith(".pdf") &&
                    !certFileName.EndsWith(".jpg") &&
                    !certFileName.EndsWith(".jpeg") &&
                    !certFileName.EndsWith(".png"))
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be PDF, JPG, JPEG, or PNG"
                    });
                }

                certType = model.Certificate.ContentType.ToLower();
                certName = model.Certificate.FileName;

                using var ms = new MemoryStream();
                await model.Certificate.CopyToAsync(ms);
                certBytes = ms.ToArray();
            }

            byte[]? cvBytes = null;
            string? cvName = null;

            if (model.CV != null && model.CV.Length > 0)
            {
                if (model.CV.Length > 5 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "CV must be less than 5MB"
                    });
                }

                var cvFileName = model.CV.FileName.ToLower();
                if (!cvFileName.EndsWith(".pdf"))
                {
                    return BadRequest(new
                    {
                        message = "CV must be a PDF file"
                    });
                }

                cvName = model.CV.FileName;

                using var ms = new MemoryStream();
                await model.CV.CopyToAsync(ms);
                cvBytes = ms.ToArray();
            }

            var profile = new ProgrammerProfile
            {
                UserId = model.UserId,
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
        public async Task<IActionResult> UpdateProfile(
            int userId,
            [FromForm] UpdateProgrammerProfileDto model)
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
                if (model.ProfileImage.Length > 2 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "Profile image must be less than 2MB"
                    });
                }

                var imageContentType = NormalizeImageType(
                    model.ProfileImage.ContentType,
                    model.ProfileImage.FileName);

                if (imageContentType == null)
                {
                    return BadRequest(new
                    {
                        message = "Only JPG, PNG, or WEBP images are allowed"
                    });
                }

                using var ms = new MemoryStream();
                await model.ProfileImage.CopyToAsync(ms);
                profile.ProfileImage = ms.ToArray();
                profile.ImageContentType = imageContentType;
            }

            if (model.Certificate != null &&
                model.Certificate.Length > 0)
            {
                if (model.Certificate.Length > 5 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be less than 5MB"
                    });
                }

                var certFileName = model.Certificate.FileName.ToLower();
                if (!certFileName.EndsWith(".pdf") &&
                    !certFileName.EndsWith(".jpg") &&
                    !certFileName.EndsWith(".jpeg") &&
                    !certFileName.EndsWith(".png"))
                {
                    return BadRequest(new
                    {
                        message = "Certificate must be PDF, JPG, JPEG, or PNG"
                    });
                }

                using var ms = new MemoryStream();
                await model.Certificate.CopyToAsync(ms);
                profile.Certificate = ms.ToArray();
                profile.CertificateType =
                    model.Certificate.ContentType.ToLower();
                profile.CertificateName =
                    model.Certificate.FileName;

                // ✅ إعادة التوثيق إجبارياً
                profile.IsVerified = false;
            }

            if (model.CV != null && model.CV.Length > 0)
            {
                if (model.CV.Length > 5 * 1024 * 1024)
                {
                    return BadRequest(new
                    {
                        message = "CV must be less than 5MB"
                    });
                }

                var cvFileName = model.CV.FileName.ToLower();
                if (!cvFileName.EndsWith(".pdf"))
                {
                    return BadRequest(new
                    {
                        message = "CV must be a PDF file"
                    });
                }

                using var ms = new MemoryStream();
                await model.CV.CopyToAsync(ms);
                profile.CV = ms.ToArray();
                profile.CVName = model.CV.FileName;
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
            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile?.ProfileImage == null)
            {
                return NotFound(new
                {
                    message = "No image found"
                });
            }

            Response.Headers.Append("Content-Disposition", "inline");

            return File(
                profile.ProfileImage,
                profile.ImageContentType ?? "image/jpeg"
            );
        }

        [HttpGet("{userId}/cv")]
        public async Task<IActionResult> GetCV(int userId)
        {
            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile?.CV == null)
            {
                return NotFound(new
                {
                    message = "No CV found"
                });
            }

            var fileName = profile.CVName ?? "cv.pdf";

            Response.Headers.Append(
                "Content-Disposition",
                $"inline; filename=\"{fileName}\""
            );

            return File(
                profile.CV,
                "application/pdf",
                fileName
            );
        }

        [HttpGet("{userId}/certificate")]
        public async Task<IActionResult> GetCertificate(int userId)
        {
            var profile = await _context.ProgrammerProfiles
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (profile?.Certificate == null)
            {
                return NotFound(new
                {
                    message = "No certificate found"
                });
            }

            var fileName = profile.CertificateName ?? "certificate";

            Response.Headers.Append(
                "Content-Disposition",
                $"inline; filename=\"{fileName}\""
            );

            return File(
                profile.Certificate,
                profile.CertificateType ?? "application/octet-stream",
                fileName
            );
        }

        // ============================================================
        // CV MANAGEMENT
        // ============================================================

        [HttpPost("{userId}/cv")]
        public async Task<IActionResult> UploadCV(
            int userId,
            IFormFile cv)
        {
            if (cv == null || cv.Length == 0)
            {
                return BadRequest(new
                {
                    message = "CV file is required"
                });
            }

            if (cv.Length > 5 * 1024 * 1024)
            {
                return BadRequest(new
                {
                    message = "CV must be less than 5MB"
                });
            }

            var fileName = cv.FileName.ToLower();
            if (!fileName.EndsWith(".pdf"))
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

            using var ms = new MemoryStream();
            await cv.CopyToAsync(ms);

            profile.CV = ms.ToArray();
            profile.CVName = cv.FileName;
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
        public async Task<IActionResult> DeleteCV(int userId)
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
        public async Task<IActionResult> UploadCertificate(
            int userId,
            IFormFile certificate)
        {
            if (certificate == null || certificate.Length == 0)
            {
                return BadRequest(new
                {
                    message = "Certificate file is required"
                });
            }

            if (certificate.Length > 5 * 1024 * 1024)
            {
                return BadRequest(new
                {
                    message = "Certificate must be less than 5MB"
                });
            }

            var fileName = certificate.FileName.ToLower();
            if (!fileName.EndsWith(".pdf") &&
                !fileName.EndsWith(".jpg") &&
                !fileName.EndsWith(".jpeg") &&
                !fileName.EndsWith(".png"))
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

            using var ms = new MemoryStream();
            await certificate.CopyToAsync(ms);

            profile.Certificate = ms.ToArray();
            profile.CertificateType = certificate.ContentType.ToLower();
            profile.CertificateName = certificate.FileName;

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
        public async Task<IActionResult> DeleteCertificate(int userId)
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
                if (fn.EndsWith(".jpg") || fn.EndsWith(".jpeg"))
                    return "image/jpeg";

                return "image/jpeg";
            }

            return ct;
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