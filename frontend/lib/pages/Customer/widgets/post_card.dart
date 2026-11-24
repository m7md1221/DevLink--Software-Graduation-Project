import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../services/post_service.dart';
import '../../../services/media_url.dart';
import '../../../widgets/custom_toast.dart';
import '../../../theme/devlink_tokens.dart';
import '../../../widgets/dl/dl_widgets.dart';
import '../../Common/project_details_page.dart';
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

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  late int _applicationsCount;
  late bool _isClosed;
  late bool _isSaved;
  bool _isLiking = false;
  bool _hasApplied = false;
  bool _checkingApplied = true;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _applicationsCount = widget.post.applicationsCount;
    _isClosed = widget.post.isClosed;
    _isSaved = widget.post.isSaved;
    _checkApplied();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    if (!_isLiked) _controller.forward().then((_) => _controller.reverse());

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

  Future<void> _toggleSave() async {
    final result = await PostService.toggleSavePost(
      postId: widget.post.id,
      userId: widget.currentUserId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _isSaved = result['isSaved'] == true);
      CustomToast.show(
        context,
        _isSaved ? 'Post saved' : 'Post unsaved',
      );
    } else {
      CustomToast.show(
        context,
        result['message'] ?? 'Failed',
        isError: true,
      );
    }
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
    if (added == true) setState(() => _commentCount++);
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
          requiredFramework: widget.post.framework,
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
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Post?',
          style: TextStyle(fontWeight: FontWeight.w900, color: textPrimary),
        ),
        content: Text(
          'This post will be permanently removed from your feed.',
          style: TextStyle(color: textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w800)),
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
      CustomToast.show(context, 'Post deleted successfully');
      widget.onChanged();
    } else {
      CustomToast.show(context, result['message'] ?? 'Failed to delete post',
          isError: true);
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final isProgrammer = widget.currentUserType == 'Programmer';
    // KI-56 (owner decision UI-11): only customers' posts take applications; the API
    // refuses an application to a programmer's post (D-11), so don't offer one.
    final ownerTakesApplications = widget.post.authorType != 'Programmer';
    final canApply = isProgrammer &&
        ownerTakesApplications &&
        !widget.post.isMine &&
        !_isClosed &&
        !_hasApplied;
    final canViewApplications = widget.post.isMine;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
          color: _isClosed
              ? const Color(0xFF10B981).withOpacity(0.4)
              : borderColor,
          width: _isClosed ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 16,
                isMobile ? 14 : 16,
                isMobile ? 14 : 16,
                isMobile ? 10 : 12,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onOpenProfile,
                    child: _Avatar(
                      userId: widget.post.userId,
                      url: widget.post.authorImage,
                      hasImage: widget.post.authorImage != null,
                      authorType: widget.post.authorType,
                      size: isMobile ? 40 : 46,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.w900,
                                    color: textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              // KI-60 (owner decision UI-12): no verified badge on post cards. It was
                              // shown for every programmer; the feed has no verification field yet.
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: isMobile ? 10 : 11,
                                  color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(widget.post.createdAt),
                                style: TextStyle(
                                  fontSize: isMobile ? 10.5 : 11,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 13, color: Color(0xFF10B981)),
                          SizedBox(width: 5),
                          Text('Assigned',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  if (widget.post.isMine && !_isClosed)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded,
                          color: textSecondary),
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 10),
                              Text('Delete',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            if (widget.post.isProject)
              _buildProject(isMobile)
            else if (widget.post.content != null &&
                widget.post.content!.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 14 : 16,
                  0,
                  isMobile ? 14 : 16,
                  isMobile ? 12 : 14,
                ),
                child: Text(
                  widget.post.content!,
                  style: TextStyle(
                    fontSize: isMobile ? 13.5 : 14.5,
                    color: textPrimary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Framework badge
            if (widget.post.framework != null &&
                widget.post.framework!.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 14 : 16,
                  0,
                  isMobile ? 14 : 16,
                  10,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_rounded,
                          size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Text(
                        'Required: ${widget.post.framework}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.post.images.isNotEmpty) _buildImages(isDark, isMobile),

            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 16,
                isMobile ? 10 : 12,
                isMobile ? 14 : 16,
                isMobile ? 4 : 6,
              ),
              child: Row(
                children: [
                  if (_likeCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: Icon(Icons.favorite_rounded,
                          size: isMobile ? 9 : 10, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text('$_likeCount',
                        style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w700)),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: canViewApplications ? _openApplications : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_alt_rounded,
                              size: isMobile ? 12 : 13,
                              color: const Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Text('$_applicationsCount',
                              style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: const Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                  if (_commentCount > 0) ...[
                    SizedBox(width: isMobile ? 10 : 12),
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: isMobile ? 13 : 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Text('$_commentCount',
                        style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  height: isMobile ? 12 : 16,
                  thickness: 1,
                  color: borderColor.withOpacity(0.5)),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 4 : 6, vertical: 4),
              child: Row(
                children: [
                  // Like
                  Expanded(
                    child: _actionButton(
                      icon: _isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: 'Like',
                      color:
                          _isLiked ? const Color(0xFFEF4444) : textSecondary,
                      onTap: _toggleLike,
                      scaleAnimation: _scaleAnimation,
                      isMobile: isMobile,
                    ),
                  ),

                  // Comment (Customer only)
                  if (!isProgrammer)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Comment',
                        color: textSecondary,
                        onTap: _openComments,
                        isMobile: isMobile,
                      ),
                    ),

                  // Save
                  Expanded(
                    child: _actionButton(
                      icon: _isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: _isSaved ? 'Saved' : 'Save',
                      color:
                          _isSaved ? const Color(0xFFF59E0B) : textSecondary,
                      onTap: _toggleSave,
                      isMobile: isMobile,
                    ),
                  ),

                  // Apply / Applied / View
                  if (canApply)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.send_rounded,
                        label: 'Apply',
                        color: const Color(0xFF8B5CF6),
                        onTap: _checkingApplied ? null : _openApply,
                        isMobile: isMobile,
                      ),
                    )
                  else if (_hasApplied && !widget.post.isMine)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.check_circle_rounded,
                        label: 'Applied',
                        color: const Color(0xFF10B981),
                        onTap: null,
                        isMobile: isMobile,
                      ),
                    )
                  else if (canViewApplications)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.people_alt_rounded,
                        label: 'View',
                        color: const Color(0xFF3B82F6),
                        onTap: _openApplications,
                        isMobile: isMobile,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProject() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(
          projectId: widget.post.id,
          currentUserId: widget.currentUserId,
          currentUserType: widget.currentUserType,
        ),
      ),
    );
    if (mounted) widget.onChanged();
  }

  Widget _buildProject(bool isMobile) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final post = widget.post;
    final meta = [
      requirementsLabel(post.criteriaCount),
      if (post.budgetMin != null || post.budgetMax != null) formatBudget(post.budgetMin, post.budgetMax),
      if (post.deadlineDays != null) formatDeadline(post.deadlineDays),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 16, 0, isMobile ? 14 : 16, isMobile ? 12 : 14),
      child: Semantics(
        button: true,
        label: 'Open project ${post.title}',
        child: InkWell(
          onTap: _openProject,
          borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DevLinkTokens.spaceLg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title ?? '', style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
                if ((post.content ?? '').isNotEmpty) ...[
                  const SizedBox(height: DevLinkTokens.spaceXs),
                  Text(post.content!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                const SizedBox(height: DevLinkTokens.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: Text(meta,
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                    Text('View project', style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                    Icon(Icons.chevron_right_rounded, color: scheme.primary, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImages(bool isDark, bool isMobile) {
    final imgs = widget.post.images;

    if (imgs.length == 1) {
      return AspectRatio(
        aspectRatio: isMobile ? 4 / 3 : 16 / 9,
        child: _image(imgs[0].url, isDark),
      );
    }

    if (imgs.length == 2) {
      return SizedBox(
        height: isMobile ? 180 : 220,
        child: Row(
          children: [
            Expanded(child: _image(imgs[0].url, isDark)),
            const SizedBox(width: 2),
            Expanded(child: _image(imgs[1].url, isDark)),
          ],
        ),
      );
    }

    return SizedBox(
      height: isMobile ? 220 : 260,
      child: Row(
        children: [
          Expanded(child: _image(imgs[0].url, isDark)),
          const SizedBox(width: 2),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(imgs[1].url, isDark),
                if (imgs.length > 2)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            color: Colors.white, size: isMobile ? 28 : 32),
                        const SizedBox(height: 6),
                        Text(
                          '+${imgs.length - 1}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 22,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(String url, bool isDark) {
    return Image.network(
      MediaUrl.resolve(url),
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          child:
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    Animation<double>? scaleAnimation,
    required bool isMobile,
  }) {
    Widget iconWidget =
        Icon(icon, size: isMobile ? 18 : 20, color: color);
    if (scaleAnimation != null) {
      iconWidget =
          ScaleTransition(scale: scaleAnimation, child: iconWidget);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              SizedBox(width: isMobile ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: isMobile ? 12.5 : 13.5,
                      fontWeight: FontWeight.w800,
                      color: color),
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
  final String? url;
  final bool hasImage;
  final String authorType;
  final double size;

  const _Avatar({
    required this.userId,
    this.url,
    required this.hasImage,
    required this.authorType,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final color = authorType == 'Programmer'
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF10B981);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                MediaUrl.resolve(url),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                    authorType == 'Programmer'
                        ? Icons.code_rounded
                        : Icons.person_rounded,
                    color: color,
                    size: size * 0.5),
              )
            : Icon(
                authorType == 'Programmer'
                    ? Icons.code_rounded
                    : Icons.person_rounded,
                color: color,
                size: size * 0.5),
      ),
    );
  }
}