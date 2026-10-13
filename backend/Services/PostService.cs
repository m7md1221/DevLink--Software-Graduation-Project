using DataBase;
using DataBase.Models;
using Microsoft.EntityFrameworkCore;

namespace Services
{
    public class PostService
    {
        private readonly AppDbContext _context;

        public PostService(AppDbContext context)
        {
            _context = context;
        }

        // ============================================================
        // GET FEED
        // ============================================================
        public async Task<List<object>> GetFeed(
            int currentUserId,
            int page = 1,
            int pageSize = 20)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 50) pageSize = 20;

            var posts = await _context.Posts
                .Where(p => !p.IsDeleted)
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Include(p => p.Images)
                .Include(p => p.Likes)
                .Include(p => p.Comments)
                .ToListAsync();

            var result = new List<object>();

            foreach (var post in posts)
            {
                var author = await GetAuthorInfo(post.UserId);
                if (author == null) continue;

                result.Add(new
                {
                    id = post.Id,
                    userId = post.UserId,
                    authorName = author.Value.nickname,
                    authorImage = author.Value.hasImage
                        ? $"/api/Posts/user/{post.UserId}/avatar"
                        : null,
                    authorType = author.Value.userType,
                    content = post.Content,
                    createdAt = post.CreatedAt,
                    updatedAt = post.UpdatedAt,
                    imageCount = post.Images.Count,
                    likeCount = post.Likes.Count,
                    commentCount = post.Comments.Count,
                    isLikedByMe = post.Likes.Any(l => l.UserId == currentUserId),
                    isMine = post.UserId == currentUserId,
                    images = post.Images
                        .OrderBy(i => i.SortOrder)
                        .Select(i => new
                        {
                            id = i.Id,
                            url = $"/api/Posts/image/{i.Id}"
                        })
                        .ToList()
                });
            }

            return result;
        }

        // ============================================================
        // GET POSTS BY USER
        // ============================================================
        public async Task<List<object>> GetPostsByUser(
            int userId,
            int currentUserId)
        {
            var posts = await _context.Posts
                .Where(p => p.UserId == userId && !p.IsDeleted)
                .OrderByDescending(p => p.CreatedAt)
                .Include(p => p.Images)
                .Include(p => p.Likes)
                .Include(p => p.Comments)
                .ToListAsync();

            var author = await GetAuthorInfo(userId);
            if (author == null) return new List<object>();

            var result = new List<object>();

            foreach (var post in posts)
            {
                result.Add(new
                {
                    id = post.Id,
                    userId = post.UserId,
                    authorName = author.Value.nickname,
                    authorImage = author.Value.hasImage
                        ? $"/api/Posts/user/{post.UserId}/avatar"
                        : null,
                    authorType = author.Value.userType,
                    content = post.Content,
                    createdAt = post.CreatedAt,
                    imageCount = post.Images.Count,
                    likeCount = post.Likes.Count,
                    commentCount = post.Comments.Count,
                    isLikedByMe = post.Likes.Any(l => l.UserId == currentUserId),
                    isMine = post.UserId == currentUserId,
                    images = post.Images
                        .OrderBy(i => i.SortOrder)
                        .Select(i => new
                        {
                            id = i.Id,
                            url = $"/api/Posts/image/{i.Id}"
                        })
                        .ToList()
                });
            }

            return result;
        }

        // ============================================================
        // CREATE POST
        // ============================================================
        public async Task<(bool success, string message, int? postId)> CreatePost(
            int userId,
            string? content,
            List<(byte[] data, string contentType)>? images)
        {
            var hasContent = !string.IsNullOrWhiteSpace(content);
            var hasImages = images != null && images.Count > 0;

            if (!hasContent && !hasImages)
            {
                return (false, "Post must have content or at least one image", null);
            }

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null)
            {
                return (false, "User not found", null);
            }

            if (user.UserType == "Admin")
            {
                return (false, "Admins cannot create posts", null);
            }

            if (hasImages && images!.Count > 10)
            {
                return (false, "Maximum 10 images per post", null);
            }

            if (hasContent && content!.Length > 5000)
            {
                return (false, "Post content is too long (max 5000 chars)", null);
            }

            var post = new Post
            {
                UserId = userId,
                Content = hasContent ? content!.Trim() : null,
                CreatedAt = DateTime.UtcNow
            };

            _context.Posts.Add(post);
            await _context.SaveChangesAsync();

            if (hasImages)
            {
                var order = 0;
                foreach (var img in images!)
                {
                    _context.PostImages.Add(new PostImage
                    {
                        PostId = post.Id,
                        ImageData = img.data,
                        ContentType = img.contentType,
                        SortOrder = order++,
                        CreatedAt = DateTime.UtcNow
                    });
                }

                await _context.SaveChangesAsync();
            }

            return (true, "Post created successfully", post.Id);
        }

        // ============================================================
        // DELETE POST (Soft Delete)
        // ============================================================
        public async Task<(bool success, string message)> DeletePost(
            int postId,
            int userId,
            bool isAdmin = false)
        {
            var post = await _context.Posts
                .FirstOrDefaultAsync(p => p.Id == postId);

            if (post == null || post.IsDeleted)
            {
                return (false, "Post not found");
            }

            if (post.UserId != userId && !isAdmin)
            {
                return (false, "You can only delete your own posts");
            }

            post.IsDeleted = true;
            post.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return (true, "Post deleted successfully");
        }

        // ============================================================
        // TOGGLE LIKE
        // ============================================================
        public async Task<(bool success, string message, bool isLiked, int likeCount)>
            ToggleLike(int postId, int userId)
        {
            var post = await _context.Posts
                .FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted);

            if (post == null)
            {
                return (false, "Post not found", false, 0);
            }

            var existing = await _context.PostLikes
                .FirstOrDefaultAsync(l =>
                    l.PostId == postId && l.UserId == userId);

            bool isLiked;

            if (existing != null)
            {
                _context.PostLikes.Remove(existing);
                isLiked = false;
            }
            else
            {
                _context.PostLikes.Add(new PostLike
                {
                    PostId = postId,
                    UserId = userId,
                    CreatedAt = DateTime.UtcNow
                });
                isLiked = true;
            }

            await _context.SaveChangesAsync();

            var likeCount = await _context.PostLikes
                .CountAsync(l => l.PostId == postId);

            return (true,
                isLiked ? "Post liked" : "Post unliked",
                isLiked,
                likeCount);
        }

        // ============================================================
        // GET COMMENTS
        // ============================================================
        public async Task<List<object>> GetComments(int postId)
        {
            var comments = await _context.PostComments
                .Where(c => c.PostId == postId)
                .OrderBy(c => c.CreatedAt)
                .ToListAsync();

            var result = new List<object>();

            foreach (var c in comments)
            {
                var author = await GetAuthorInfo(c.UserId);
                if (author == null) continue;

                result.Add(new
                {
                    id = c.Id,
                    postId = c.PostId,
                    userId = c.UserId,
                    authorName = author.Value.nickname,
                    authorImage = author.Value.hasImage
                        ? $"/api/Posts/user/{c.UserId}/avatar"
                        : null,
                    authorType = author.Value.userType,
                    content = c.Content,
                    createdAt = c.CreatedAt
                });
            }

            return result;
        }

        // ============================================================
        // ADD COMMENT
        // ============================================================
        public async Task<(bool success, string message, int? commentId)>
            AddComment(int postId, int userId, string content)
        {
            if (string.IsNullOrWhiteSpace(content))
            {
                return (false, "Comment cannot be empty", null);
            }

            if (content.Length > 1000)
            {
                return (false, "Comment is too long (max 1000 chars)", null);
            }

            var post = await _context.Posts
                .FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted);

            if (post == null)
            {
                return (false, "Post not found", null);
            }

            var comment = new PostComment
            {
                PostId = postId,
                UserId = userId,
                Content = content.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            _context.PostComments.Add(comment);
            await _context.SaveChangesAsync();

            return (true, "Comment added", comment.Id);
        }

        // ============================================================
        // DELETE COMMENT
        // ============================================================
        public async Task<(bool success, string message)> DeleteComment(
            int commentId,
            int userId,
            bool isAdmin = false)
        {
            var comment = await _context.PostComments
                .FirstOrDefaultAsync(c => c.Id == commentId);

            if (comment == null)
            {
                return (false, "Comment not found");
            }

            if (comment.UserId != userId && !isAdmin)
            {
                return (false, "You can only delete your own comments");
            }

            _context.PostComments.Remove(comment);
            await _context.SaveChangesAsync();

            return (true, "Comment deleted successfully");
        }

        // ============================================================
        // GET POST IMAGE
        // ============================================================
        public async Task<(byte[]? data, string? contentType)> GetPostImage(int imageId)
        {
            var img = await _context.PostImages
                .FirstOrDefaultAsync(i => i.Id == imageId);

            if (img == null) return (null, null);

            return (img.ImageData, img.ContentType);
        }

        // ============================================================
        // GET USER AVATAR
        // ============================================================
        public async Task<(byte[]? data, string? contentType)> GetUserAvatar(int userId)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null) return (null, null);

            if (user.UserType == "Customer")
            {
                var p = await _context.CustomerProfiles
                    .FirstOrDefaultAsync(cp => cp.UserId == userId);

                if (p?.ProfileImage == null) return (null, null);
                return (p.ProfileImage, p.ImageContentType ?? "image/jpeg");
            }
            else if (user.UserType == "Programmer")
            {
                var p = await _context.ProgrammerProfiles
                    .FirstOrDefaultAsync(pp => pp.UserId == userId);

                if (p?.ProfileImage == null) return (null, null);
                return (p.ProfileImage, p.ImageContentType ?? "image/jpeg");
            }

            return (null, null);
        }

        // ============================================================
        // SEARCH USERS
        // ============================================================
        public async Task<List<object>> SearchUsers(
            string query,
            string? userType = null)
        {
            if (string.IsNullOrWhiteSpace(query))
                return new List<object>();

            query = query.Trim().ToLower();

            var users = await _context.Users
                .Where(u => u.UserType != "Admin")
                .ToListAsync();

            var results = new List<object>();

            foreach (var user in users)
            {
                if (userType != null && user.UserType != userType)
                    continue;

                string? nickname = null;
                bool hasImage = false;
                string? specialty = null;

                if (user.UserType == "Customer")
                {
                    var p = await _context.CustomerProfiles
                        .FirstOrDefaultAsync(cp => cp.UserId == user.Id);
                    if (p != null)
                    {
                        nickname = p.Nickname;
                        hasImage = p.ProfileImage != null;
                    }
                }
                else if (user.UserType == "Programmer")
                {
                    var p = await _context.ProgrammerProfiles
                        .FirstOrDefaultAsync(pp => pp.UserId == user.Id);
                    if (p != null)
                    {
                        nickname = p.Nickname;
                        hasImage = p.ProfileImage != null;
                        specialty = p.Specialty;
                    }
                }

                if (nickname == null) continue;

                var matches =
                    nickname.ToLower().Contains(query) ||
                    user.Email.ToLower().Contains(query) ||
                    (specialty != null && specialty.ToLower().Contains(query));

                if (matches)
                {
                    results.Add(new
                    {
                        userId = user.Id,
                        email = user.Email,
                        nickname = nickname,
                        userType = user.UserType,
                        specialty = specialty,
                        hasImage = hasImage,
                        avatarUrl = hasImage
                            ? $"/api/Posts/user/{user.Id}/avatar"
                            : null
                    });
                }
            }

            return results.Take(30).ToList();
        }

        // ============================================================
        // GET USER PUBLIC PROFILE
        // ============================================================
        public async Task<object?> GetUserProfile(int userId)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null || user.UserType == "Admin")
                return null;

            var postCount = await _context.Posts
                .CountAsync(p => p.UserId == userId && !p.IsDeleted);

            if (user.UserType == "Customer")
            {
                var p = await _context.CustomerProfiles
                    .FirstOrDefaultAsync(cp => cp.UserId == userId);

                if (p == null) return null;

                return new
                {
                    userId = user.Id,
                    email = user.Email,
                    userType = user.UserType,
                    nickname = p.Nickname,
                    country = p.Country,
                    city = p.City,
                    phoneNumber = p.PhoneNumber,
                    hasImage = p.ProfileImage != null,
                    avatarUrl = p.ProfileImage != null
                        ? $"/api/Posts/user/{user.Id}/avatar"
                        : null,
                    postCount = postCount,
                    createdAt = p.CreatedAt
                };
            }
            else
            {
                var p = await _context.ProgrammerProfiles
                    .FirstOrDefaultAsync(pp => pp.UserId == userId);

                if (p == null) return null;

                return new
                {
                    userId = user.Id,
                    email = user.Email,
                    userType = user.UserType,
                    nickname = p.Nickname,
                    country = p.Country,
                    city = p.City,
                    phoneNumber = p.PhoneNumber,
                    specialty = p.Specialty,
                    university = p.University,
                    linkedInUrl = p.LinkedInUrl,
                    rating = p.Rating,
                    isVerified = p.IsVerified,
                    hasImage = p.ProfileImage != null,
                    avatarUrl = p.ProfileImage != null
                        ? $"/api/Posts/user/{user.Id}/avatar"
                        : null,
                    postCount = postCount,
                    createdAt = p.CreatedAt
                };
            }
        }

        // ============================================================
        // HELPER: Get Author Info
        // ============================================================
        private async Task<(string nickname, string userType, bool hasImage)?>
            GetAuthorInfo(int userId)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null) return null;

            if (user.UserType == "Customer")
            {
                var p = await _context.CustomerProfiles
                    .FirstOrDefaultAsync(cp => cp.UserId == userId);

                return (
                    p?.Nickname ?? "User",
                    user.UserType,
                    p?.ProfileImage != null
                );
            }
            else if (user.UserType == "Programmer")
            {
                var p = await _context.ProgrammerProfiles
                    .FirstOrDefaultAsync(pp => pp.UserId == userId);

                return (
                    p?.Nickname ?? "User",
                    user.UserType,
                    p?.ProfileImage != null
                );
            }

            return ("User", user.UserType, false);
        }
    }
}