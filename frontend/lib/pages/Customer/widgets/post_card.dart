import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../services/post_service.dart';
import 'comments_sheet.dart';
import '../apply_to_post_page.dart';
import '../post_applications_page.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final int currentUserId;
  final String currentUserType;
  final VoidCallback onChanged;
  final VoidCallback? onOpenProfile;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.currentUserType = 'Customer',
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
  late int _applicationsCount;
  late bool _isClosed;
  bool _isLiking = false;
  bool _hasApplied = false;
  bool _checkingApplied = true;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _applicationsCount = widget.post.applicationsCount;
    _isClosed = widget.post.isClosed;
    _checkApplied();
  }

  Future<void> _checkApplied() async {
    if (widget.currentUserType != 'Programmer') {
      setState(() => _checkingApplied = false);
      return;
    }

    final applied = await PostService.hasUserApplied(
      postId: widget.post.id,
      userId: widget.currentUserId,
    );

    if (!mounted) return;
    setState(() {
      _hasApplied = applied;
      _checkingApplied = false;
    });
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

  Future<void> _openApply() async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApplyToPostPage(
          postId: widget.post.id,
          programmerId: widget.currentUserId,
          postAuthorName: widget.post.authorName,
          postContent: widget.post.content,
        ),
      ),
    );

    if (applied == true) {
      setState(() {
        _hasApplied = true;
        _applicationsCount++;
      });
    }
  }

  Future<void> _openApplications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostApplicationsPage(
          postId: widget.post.id,
          requesterId: widget.currentUserId,
          postContent: widget.post.content,
        ),
      ),
    );

    if (mounted) widget.onChanged();
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

    final isProgrammer = widget.currentUserType == 'Programmer';
    final canApply = isProgrammer &&
        !widget.post.isMine &&
        !_isClosed &&
        !_hasApplied;
    final canViewApplications = widget.post.isMine;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isClosed
              ? const Color(0xFF10B981).withOpacity(0.4)
              : borderColor,
          width: _isClosed ? 1.5 : 1.2,
        ),
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
                if (_isClosed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Assigned',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.post.isMine && !_isClosed)
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

          if (widget.post.images.isNotEmpty) _buildImages(isDark),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  const SizedBox(width: 5),
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: canViewApplications ? _openApplications : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          size: 12,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_applicationsCount',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_commentCount > 0) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 13,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_commentCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: borderColor.withOpacity(0.5),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                if (canApply)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.send_rounded,
                      label: 'Apply',
                      color: const Color(0xFF8B5CF6),
                      onTap: _checkingApplied ? null : _openApply,
                    ),
                  )
                else if (_hasApplied && !widget.post.isMine)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.check_circle_rounded,
                      label: 'Applied',
                      color: const Color(0xFF10B981),
                      onTap: null,
                    ),
                  )
                else if (canViewApplications)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.people_alt_rounded,
                      label: 'View',
                      color: const Color(0xFF3B82F6),
                      onTap: _openApplications,
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
        child: _image(imgs[0].id, isDark),
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
    required VoidCallback? onTap,
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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