import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../services/post_service.dart';
import 'comments_sheet.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final int currentUserId;
  final VoidCallback onChanged;
  final VoidCallback? onOpenProfile;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onChanged,
    this.onOpenProfile,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);

    final result = await PostService.toggleLike(
      postId: widget.post.id,
      userId: widget.currentUserId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLiked = result['isLiked'] == true;
        _likeCount = result['likeCount'] ?? _likeCount;
      });
    }
    setState(() => _isLiking = false);
  }

  Future<void> _openComments() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: widget.post.id,
        currentUserId: widget.currentUserId,
      ),
    );

    if (added == true) {
      setState(() => _commentCount++);
    }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Post?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        content: Text(
          'This post will be permanently removed from your feed.',
          style: TextStyle(color: textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await PostService.deletePost(
      postId: widget.post.id,
      userId: widget.currentUserId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post deleted'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to delete'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // FORMAT DATE & TIME
  // ============================================================
  String _formatDateTime(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;

    int hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$day/$month/$year  $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Header =====
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: _Avatar(
                    userId: widget.post.userId,
                    hasImage: widget.post.authorImage != null,
                    authorType: widget.post.authorType,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onOpenProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            if (widget.post.authorType == 'Programmer')
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.code_rounded,
                                  size: 13,
                                  color: Colors.purple.shade400,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(widget.post.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.post.isMine)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: textSecondary,
                    ),
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ===== Content =====
          if (widget.post.content != null &&
              widget.post.content!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                widget.post.content!,
                style: TextStyle(
                  fontSize: 14.5,
                  color: textPrimary,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // ===== Images =====
          if (widget.post.images.isNotEmpty)
            _buildImages(isDark),

          // ===== Stats row =====
          if (_likeCount > 0 || _commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  if (_likeCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_likeCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_commentCount > 0)
                    Text(
                      '$_commentCount comment${_commentCount > 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

          // ===== Actions =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: borderColor.withOpacity(0.5),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: 'Like',
                    color: _isLiked
                        ? const Color(0xFFEF4444)
                        : textSecondary,
                    onTap: _toggleLike,
                  ),
                ),
                Expanded(
                  child: _actionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comment',
                    color: textSecondary,
                    onTap: _openComments,
                  ),
                ),
                Expanded(
                  child: _actionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: textSecondary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Share coming soon'),
                          backgroundColor: const Color(0xFF8B5CF6),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages(bool isDark) {
    final imgs = widget.post.images;

    if (imgs.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          PostService.getPostImageUrl(imgs[0].id),
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              color: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            color: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF1F5F9),
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      );
    }

    if (imgs.length == 2) {
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(child: _image(imgs[0].id, isDark)),
            const SizedBox(width: 2),
            Expanded(child: _image(imgs[1].id, isDark)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(child: _image(imgs[0].id, isDark)),
          const SizedBox(width: 2),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(imgs[1].id, isDark),
                if (imgs.length > 2)
                  Container(
                    color: Colors.black.withOpacity(0.55),
                    alignment: Alignment.center,
                    child: Text(
                      '+${imgs.length - 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(int id, bool isDark) {
    return Image.network(
      PostService.getPostImageUrl(id),
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF1F5F9),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AVATAR
// ============================================================
class _Avatar extends StatelessWidget {
  final int userId;
  final bool hasImage;
  final String authorType;

  const _Avatar({
    required this.userId,
    required this.hasImage,
    required this.authorType,
  });

  @override
  Widget build(BuildContext context) {
    final color = authorType == 'Programmer'
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF10B981);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 2),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                PostService.getUserAvatarUrl(userId),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  authorType == 'Programmer'
                      ? Icons.code_rounded
                      : Icons.person_rounded,
                  color: color,
                  size: 22,
                ),
              )
            : Icon(
                authorType == 'Programmer'
                    ? Icons.code_rounded
                    : Icons.person_rounded,
                color: color,
                size: 22,
              ),
      ),
    );
  }
}