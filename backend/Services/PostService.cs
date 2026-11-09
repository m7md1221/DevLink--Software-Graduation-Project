using DataBase;
using DataBase.Models;
using Microsoft.EntityFrameworkCore;
using Services.Files;

namespace Services
{
    public enum PostActionStatus
    {
        Ok,
        BadRequest,
        Forbidden
    }

    public class PostService
    {
        private readonly AppDbContext _context;
        private readonly MediaUrls _media;

        public PostService(AppDbContext context, MediaUrls media)
        {
            _context = context;
            _media = media;
        }

        // The name shown to other members: the profile nickname, never any part of the email (KI-58).
        private async Task<string> SenderNameAsync(int userId)
        {
            var nickname =
                await _context.CustomerProfiles.Where(p => p.UserId == userId).Select(p => p.Nickname).FirstOrDefaultAsync() ??
                await _context.ProgrammerProfiles.Where(p => p.UserId == userId).Select(p => p.Nickname).FirstOrDefaultAsync();

            return string.IsNullOrWhiteSpace(nickname) ? "A DevLink member" : nickname;
        }

        private async Task CreateNotification(int userId, string title, string message, string type, int? referenceId = null)
        {
            if (userId <= 0) return;

            var notification = new Notification
            {
                UserId = userId,
                Title = title,
                Message = message,
                Type = type,
                ReferenceId = referenceId,
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            };

            _context.Notifications.Add(notification);
            await _context.SaveChangesAsync();

            var userNotifications = await _context.Notifications
                .Where(n => n.UserId == userId)
                .OrderByDescending(n => n.CreatedAt)
                .ToListAsync();

            if (userNotifications.Count > 5)
            {
                var toDelete = userNotifications.Skip(5).ToList();
                _context.Notifications.RemoveRange(toDelete);
                await _context.SaveChangesAsync();
            }
        }

        public async Task<List<object>> GetFeed(int currentUserId, int page = 1, int pageSize = 20)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 50) pageSize = 20;

            var posts = await _context.Posts
                .Where(p => !p.IsDeleted && p.Status == "Approved")
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

                var appCount = await _context.PostApplications.CountAsync(a => a.PostId == post.Id);

                result.Add(new
                {
                    id = post.Id,
                    userId = post.UserId,
                    authorName = author.Value.nickname,
                    authorImage = author.Value.hasImage ? _media.AvatarUrl(post.UserId) : null,
                    avatarUrl = author.Value.hasImage ? _media.AvatarUrl(post.UserId) : null,
                    authorType = author.Value.userType,
                    content = post.Content,
                    createdAt = post.CreatedAt,
                    updatedAt = post.UpdatedAt,
                    imageCount = post.Images.Count,
                    likeCount = post.Likes.Count,
                    commentCount = post.Comments.Count,
                    applicationsCount = appCount,
                    isClosed = post.IsClosed,
                    isLikedByMe = post.Likes.Any(l => l.UserId == currentUserId),
                    isMine = post.UserId == currentUserId,
                    images = post.Images.OrderBy(i => i.SortOrder).Select(i => new { id = i.Id, url = _media.PostImageUrl(i.Id) }).ToList()
                });
            }

            return result;
        }

        public async Task<List<object>> GetPostsByUser(int userId, int currentUserId)
        {
            var posts = await _context.Posts
                .Where(p => p.UserId == userId && !p.IsDeleted && p.Status == "Approved")
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
                var appCount = await _context.PostApplications.CountAsync(a => a.PostId == post.Id);

                result.Add(new
                {
                    id = post.Id,
                    userId = post.UserId,
                    authorName = author.Value.nickname,
                    authorImage = author.Value.hasImage ? _media.AvatarUrl(post.UserId) : null,
                    avatarUrl = author.Value.hasImage ? _media.AvatarUrl(post.UserId) : null,
                    authorType = author.Value.userType,
                    content = post.Content,
                    createdAt = post.CreatedAt,
                    imageCount = post.Images.Count,
                    likeCount = post.Likes.Count,
                    commentCount = post.Comments.Count,
                    applicationsCount = appCount,
                    isClosed = post.IsClosed,
                    isLikedByMe = post.Likes.Any(l => l.UserId == currentUserId),
                    isMine = post.UserId == currentUserId,
                    images = post.Images.OrderBy(i => i.SortOrder).Select(i => new { id = i.Id, url = _media.PostImageUrl(i.Id) }).ToList()
                });
            }

            return result;
        }

        public async Task<(bool success, string message, int? postId)> CreatePost(int userId, string? content, List<(byte[] data, string contentType)>? images)
        {
            var hasContent = !string.IsNullOrWhiteSpace(content);
            var hasImages = images != null && images.Count > 0;

            if (!hasContent && !hasImages) return (false, "Post must have content or at least one image", null);

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null) return (false, "User not found", null);
            if (user.UserType == "Admin") return (false, "Admins cannot create posts", null);

            if (hasImages && images!.Count > 10) return (false, "Maximum 10 images per post", null);
            if (hasContent && content!.Length > 5000) return (false, "Post content is too long", null);

            var post = new Post
            {
                UserId = userId,
                Content = hasContent ? content!.Trim() : null,
                CreatedAt = DateTime.UtcNow,
                Status = "Pending"
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

        // callerIsAdmin comes from the access token only; a client-sent isAdmin never reaches this (D-2).
        public async Task<(PostActionStatus status, string message)> DeletePost(int postId, int userId, bool callerIsAdmin)
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId);
            if (post == null || post.IsDeleted) return (PostActionStatus.BadRequest, "Post not found");
            if (post.UserId != userId && !callerIsAdmin) return (PostActionStatus.Forbidden, "You can only delete your own posts");

            post.IsDeleted = true;
            post.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return (PostActionStatus.Ok, "Post deleted successfully");
        }

        public async Task<(bool success, string message, bool isLiked, int likeCount)> ToggleLike(int postId, int userId)
        {
            // Social actions on approved posts only (design 8 #41, #43).
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted && p.Status == "Approved");
            if (post == null) return (false, "Post not found", false, 0);

            var existing = await _context.PostLikes.FirstOrDefaultAsync(l => l.PostId == postId && l.UserId == userId);
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

            if (isLiked && post.UserId != userId)
            {
                var likerName = await SenderNameAsync(userId);

                await CreateNotification(post.UserId, "New Like", $"{likerName} liked your post.", "like", postId);
            }

            var likeCount = await _context.PostLikes.CountAsync(l => l.PostId == postId);
            return (true, isLiked ? "Post liked" : "Post unliked", isLiked, likeCount);
        }

        // Approved posts: any member. Pending, rejected or deleted: only the post owner (admins are checked by the caller).
        public async Task<bool> CommentsVisibleTo(int postId, int? callerId)
        {
            var post = await _context.Posts.Where(p => p.Id == postId)
                .Select(p => new { p.UserId, p.Status, p.IsDeleted }).FirstOrDefaultAsync();

            return post == null || (post.Status == "Approved" && !post.IsDeleted) || post.UserId == callerId;
        }

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
                    authorImage = author.Value.hasImage ? _media.AvatarUrl(c.UserId) : null,
                    avatarUrl = author.Value.hasImage ? _media.AvatarUrl(c.UserId) : null,
                    authorType = author.Value.userType,
                    content = c.Content,
                    createdAt = c.CreatedAt
                });
            }

            return result;
        }

        public async Task<(bool success, string message, int? commentId)> AddComment(int postId, int userId, string content)
        {
            if (string.IsNullOrWhiteSpace(content)) return (false, "Comment cannot be empty", null);
            if (content.Length > 1000) return (false, "Comment is too long", null);

            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted && p.Status == "Approved");
            if (post == null) return (false, "Post not found", null);

            var comment = new PostComment
            {
                PostId = postId,
                UserId = userId,
                Content = content.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            _context.PostComments.Add(comment);
            await _context.SaveChangesAsync();

            if (post.UserId != userId)
            {
                var commenterName = await SenderNameAsync(userId);

                await CreateNotification(post.UserId, "New Comment", $"{commenterName} commented on your post.", "comment", postId);
            }

            return (true, "Comment added", comment.Id);
        }

        // Comment author, post owner, or an admin (from the token).
        public async Task<(PostActionStatus status, string message)> DeleteComment(int commentId, int userId, bool callerIsAdmin)
        {
            var comment = await _context.PostComments.FirstOrDefaultAsync(c => c.Id == commentId);
            if (comment == null) return (PostActionStatus.BadRequest, "Comment not found");

            var isPostOwner = await _context.Posts.AnyAsync(p => p.Id == comment.PostId && p.UserId == userId);
            if (comment.UserId != userId && !isPostOwner && !callerIsAdmin)
                return (PostActionStatus.Forbidden, "You can only delete your own comments");

            _context.PostComments.Remove(comment);
            await _context.SaveChangesAsync();

            return (PostActionStatus.Ok, "Comment deleted successfully");
        }

        // Deleted posts and suspended or deleted authors: never. Otherwise approved posts for anyone who got here; pending and
        // rejected ones need a signed URL (issued only to their owner and admins), or a token of the owner or an admin.
        public async Task<byte[]?> GetPostImage(int imageId, bool signedOrFallback, int? callerId, bool callerIsAdmin)
        {
            var image = await _context.PostImages.AsNoTracking()
                .Where(i => i.Id == imageId && !i.Post!.IsDeleted)
                .Select(i => new
                {
                    i.ImageData,
                    i.Post!.Status,
                    i.Post.UserId,
                    AuthorActive = _context.Users.Any(u => u.Id == i.Post.UserId && u.Status == UserStatus.Active)
                })
                .FirstOrDefaultAsync();

            if (image == null || !image.AuthorActive)
            {
                return null;
            }

            return image.Status == "Approved" || signedOrFallback || callerIsAdmin || image.UserId == callerId
                ? image.ImageData
                : null;
        }

        // Only for an active account (design 5.2).
        public async Task<byte[]?> GetUserAvatar(int userId)
        {
            var user = await _context.Users.AsNoTracking()
                .Where(u => u.Id == userId && u.Status == UserStatus.Active)
                .Select(u => u.UserType)
                .FirstOrDefaultAsync();

            return user switch
            {
                "Customer" => await _context.CustomerProfiles.AsNoTracking().Where(p => p.UserId == userId).Select(p => p.ProfileImage).FirstOrDefaultAsync(),
                "Programmer" => await _context.ProgrammerProfiles.AsNoTracking().Where(p => p.UserId == userId).Select(p => p.ProfileImage).FirstOrDefaultAsync(),
                _ => null
            };
        }

        // Emails are returned and searchable only for admins (Q3); others get email = null, key kept (D-5).
        public async Task<List<object>> SearchUsers(string query, string? userType, bool includeEmail)
        {
            if (string.IsNullOrWhiteSpace(query)) return new List<object>();

            query = query.Trim().ToLower();

            var users = await _context.Users.Where(u => u.UserType != "Admin").ToListAsync();
            var results = new List<object>();

            foreach (var user in users)
            {
                if (userType != null && user.UserType != userType) continue;

                string? nickname = null;
                bool hasImage = false;
                string? specialty = null;

                if (user.UserType == "Customer")
                {
                    var p = await _context.CustomerProfiles.FirstOrDefaultAsync(cp => cp.UserId == user.Id);
                    if (p != null) { nickname = p.Nickname; hasImage = p.ProfileImage != null; }
                }
                else if (user.UserType == "Programmer")
                {
                    var p = await _context.ProgrammerProfiles.FirstOrDefaultAsync(pp => pp.UserId == user.Id);
                    if (p != null) { nickname = p.Nickname; hasImage = p.ProfileImage != null; specialty = p.Specialty; }
                }

                if (nickname == null) continue;

                var matches = nickname.ToLower().Contains(query) || (includeEmail && user.Email.ToLower().Contains(query)) || (specialty != null && specialty.ToLower().Contains(query));

                if (matches)
                {
                    results.Add(new
                    {
                        userId = user.Id,
                        email = includeEmail ? user.Email : null,
                        nickname = nickname,
                        userType = user.UserType,
                        specialty = specialty,
                        hasImage = hasImage,
                        avatarUrl = hasImage ? _media.AvatarUrl(user.Id) : null
                    });
                }
            }

            return results.Take(30).ToList();
        }

        // Email and phone only for the user themself or an admin (Q3); others get null, keys kept (D-5).
        public async Task<object?> GetUserProfile(int userId, bool includeContact)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null || user.UserType == "Admin") return null;

            var postCount = await _context.Posts.CountAsync(p => p.UserId == userId && !p.IsDeleted && p.Status == "Approved");

            if (user.UserType == "Customer")
            {
                var p = await _context.CustomerProfiles.FirstOrDefaultAsync(cp => cp.UserId == userId);
                if (p == null) return null;

                return new
                {
                    userId = user.Id,
                    email = includeContact ? user.Email : null,
                    userType = user.UserType,
                    nickname = p.Nickname,
                    country = p.Country,
                    city = p.City,
                    phoneNumber = includeContact ? p.PhoneNumber : null,
                    hasImage = p.ProfileImage != null,
                    avatarUrl = p.ProfileImage != null ? _media.AvatarUrl(user.Id) : null,
                    postCount = postCount,
                    createdAt = p.CreatedAt
                };
            }
            else
            {
                var p = await _context.ProgrammerProfiles.FirstOrDefaultAsync(pp => pp.UserId == userId);
                if (p == null) return null;

                return new
                {
                    userId = user.Id,
                    email = includeContact ? user.Email : null,
                    userType = user.UserType,
                    nickname = p.Nickname,
                    country = p.Country,
                    city = p.City,
                    phoneNumber = includeContact ? p.PhoneNumber : null,
                    specialty = p.Specialty,
                    university = p.University,
                    linkedInUrl = p.LinkedInUrl,
                    rating = p.Rating,
                    isVerified = p.IsVerified,
                    hasImage = p.ProfileImage != null,
                    avatarUrl = p.ProfileImage != null ? _media.AvatarUrl(user.Id) : null,
                    postCount = postCount,
                    createdAt = p.CreatedAt
                };
            }
        }

        public async Task<(bool success, string message, int? applicationId)> ApplyToPost(int postId, int programmerId, string proposal, decimal? price, string? duration)
        {
            if (string.IsNullOrWhiteSpace(proposal)) return (false, "Proposal is required", null);
            if (proposal.Length > 2000) return (false, "Proposal is too long", null);

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == programmerId);
            if (user == null) return (false, "User not found", null);
            if (user.UserType != "Programmer") return (false, "Only programmers can apply", null);

            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted);
            if (post == null) return (false, "Post not found", null);
            if (post.UserId == programmerId) return (false, "You cannot apply to your own post", null);
            if (post.Status != "Approved") return (false, "This post is not open for applications", null);

            // D-11: only customers publish projects that accept applications.
            if (!await IsOwnedByCustomerAsync(post)) return (false, "This post is not open for applications", null);

            if (post.IsClosed) return (false, "This post is already closed", null);

            var existing = await _context.PostApplications.FirstOrDefaultAsync(a => a.PostId == postId && a.ProgrammerId == programmerId);
            if (existing != null) return (false, "You have already applied to this post", null);

            var application = new PostApplication
            {
                PostId = postId,
                ProgrammerId = programmerId,
                Proposal = proposal.Trim(),
                Price = price,
                Duration = duration?.Trim(),
                Status = "Pending",
                CreatedAt = DateTime.UtcNow
            };

            _context.PostApplications.Add(application);
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                // Two parallel requests: UQ_PostApplications_Post_Programmer keeps it to one application.
                _context.Entry(application).State = EntityState.Detached;
                return (false, "You have already applied to this post", null);
            }

            return (true, "Application submitted successfully", application.Id);
        }

        private Task<bool> IsOwnedByCustomerAsync(Post post) =>
            _context.Users.AnyAsync(u => u.Id == post.UserId && u.UserType == "Customer");

        public Task<int?> GetPostOwnerId(int postId) =>
            _context.Posts.Where(p => p.Id == postId && !p.IsDeleted).Select(p => (int?)p.UserId).FirstOrDefaultAsync();

        public async Task<List<object>> GetPostApplications(int postId, int requesterId)
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted);
            if (post == null) return new List<object>();
            if (post.UserId != requesterId) return new List<object>();

            var applications = await _context.PostApplications
                .Where(a => a.PostId == postId)
                .OrderBy(a => a.Status == "Accepted" ? 0 : a.Status == "Pending" ? 1 : 2)
                .ThenByDescending(a => a.CreatedAt)
                .ToListAsync();

            var result = new List<object>();

            foreach (var app in applications)
            {
                var programmer = await _context.ProgrammerProfiles.FirstOrDefaultAsync(pp => pp.UserId == app.ProgrammerId);
                var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == app.ProgrammerId);

                result.Add(new
                {
                    id = app.Id,
                    postId = app.PostId,
                    programmerId = app.ProgrammerId,
                    programmerName = programmer?.Nickname ?? "User",
                    programmerSpecialty = programmer?.Specialty,
                    programmerRating = programmer?.Rating ?? 0,
                    programmerIsVerified = programmer?.IsVerified ?? false,
                    programmerHasImage = programmer?.ProfileImage != null,
                    programmerAvatarUrl = programmer?.ProfileImage != null ? _media.AvatarUrl(app.ProgrammerId) : null,
                    email = user?.Email ?? "",
                    proposal = app.Proposal,
                    price = app.Price,
                    duration = app.Duration,
                    status = app.Status,
                    createdAt = app.CreatedAt
                });
            }

            return result;
        }

        public async Task<(PostActionStatus status, string message)> AcceptApplication(int postId, int applicationId, int requesterId)
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId && !p.IsDeleted);
            if (post == null) return (PostActionStatus.BadRequest, "Post not found");
            if (post.UserId != requesterId) return (PostActionStatus.Forbidden, "You can only manage your own posts");
            if (!await IsOwnedByCustomerAsync(post)) return (PostActionStatus.Forbidden, "Only customers can accept applications");
            if (post.IsClosed) return (PostActionStatus.BadRequest, "This post is already closed");

            var application = await _context.PostApplications.FirstOrDefaultAsync(a => a.Id == applicationId && a.PostId == postId);
            if (application == null) return (PostActionStatus.BadRequest, "Application not found");
            if (application.Status != "Pending") return (PostActionStatus.BadRequest, "This application is not pending");

            application.Status = "Accepted";
            application.UpdatedAt = DateTime.UtcNow;

            var others = await _context.PostApplications.Where(a => a.PostId == postId && a.Id != applicationId).ToListAsync();
            foreach (var other in others)
            {
                other.Status = "Rejected";
                other.UpdatedAt = DateTime.UtcNow;
            }

            post.IsClosed = true;
            post.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await CreateNotification(application.ProgrammerId, "Application Accepted", "Congratulations! Your application has been accepted.", "accepted", postId);

            return (PostActionStatus.Ok, "Application accepted successfully");
        }

        public async Task<int> GetApplicationsCount(int postId)
        {
            return await _context.PostApplications.CountAsync(a => a.PostId == postId);
        }

        public async Task<bool> HasUserApplied(int postId, int userId)
        {
            return await _context.PostApplications.AnyAsync(a => a.PostId == postId && a.ProgrammerId == userId);
        }

        public async Task<List<object>> GetPendingPosts()
        {
            var posts = await _context.Posts
                .Where(p => p.Status == "Pending" && !p.IsDeleted)
                .OrderByDescending(p => p.CreatedAt)
                .Include(p => p.Images)
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
                    authorType = author.Value.userType,
                    authorImage = author.Value.hasImage ? _media.AvatarUrl(post.UserId) : null,
                    avatarUrl = author.Value.hasImage ? _media.AvatarUrl(post.UserId) : null,
                    content = post.Content,
                    createdAt = post.CreatedAt,
                    imageCount = post.Images.Count,
                    images = post.Images.OrderBy(i => i.SortOrder).Select(i => new { id = i.Id, url = _media.PostImageUrl(i.Id) }).ToList()
                });
            }

            return result;
        }

        public async Task<(bool success, string message)> ApprovePost(int postId)
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId);
            if (post == null) return (false, "Post not found");
            if (post.Status == "Approved") return (true, "Already approved");

            post.Status = "Approved";
            post.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await CreateNotification(post.UserId, "Post Approved", "Your post has been reviewed and approved by the admin.", "approved", postId);

            return (true, "Post approved successfully");
        }

        public async Task<(bool success, string message)> RejectPost(int postId, string reason)
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId);
            if (post == null) return (false, "Post not found");

            post.Status = "Rejected";
            post.RejectionReason = reason.Trim();
            post.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return (true, "Post rejected");
        }

        public async Task<string?> GetPostAuthorEmail(int postId)
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.Id == postId);
            if (post == null) return null;

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == post.UserId);
            return user?.Email;
        }

        private async Task<(string nickname, string userType, bool hasImage)?> GetAuthorInfo(int userId)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null) return null;

            if (user.UserType == "Customer")
            {
                var p = await _context.CustomerProfiles.FirstOrDefaultAsync(cp => cp.UserId == userId);
                return (p?.Nickname ?? "User", user.UserType, p?.ProfileImage != null);
            }
            else if (user.UserType == "Programmer")
            {
                var p = await _context.ProgrammerProfiles.FirstOrDefaultAsync(pp => pp.UserId == userId);
                return (p?.Nickname ?? "User", user.UserType, p?.ProfileImage != null);
            }

            return ("User", user.UserType, false);
        }
    }
}