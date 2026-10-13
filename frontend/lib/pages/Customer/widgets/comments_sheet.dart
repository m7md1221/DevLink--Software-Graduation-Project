import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../services/post_service.dart';

class CommentsSheet extends StatefulWidget {
  final int postId;
  final int currentUserId;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _addedSomething = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final list = await PostService.getComments(widget.postId);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _isLoading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final result = await PostService.addComment(
      postId: widget.postId,
      userId: widget.currentUserId,
      content: text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _controller.clear();
      _addedSomething = true;
      await _loadComments();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isSending = false);
  }

  Future<void> _deleteComment(int commentId) async {
    final result = await PostService.deleteComment(
      commentId: commentId,
      userId: widget.currentUserId,
    );

    if (result['success'] == true) {
      await _loadComments();
      _addedSomething = true;
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _addedSomething);
        return false;
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context, _addedSomething),
                    icon: Icon(
                      Icons.close_rounded,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : _comments.isEmpty
                      ? _empty(textSecondary)
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _commentTile(_comments[i], isDark),
                        ),
            ),
            Divider(height: 1, color: borderColor),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8 + bottomInset,
              ),
              color: cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                          color: textSecondary,
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF8B5CF6),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF8B5CF6),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isSending ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
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

  Widget _empty(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No comments yet',
            style: TextStyle(
              color: textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to comment!',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(CommentModel c, bool isDark) {
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final cardColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    final isMine = c.userId == widget.currentUserId;
    final isProg = c.authorType == 'Programmer';
    final accent = isProg
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF10B981);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(color: accent, width: 1.5),
          ),
          child: ClipOval(
            child: c.authorImage != null
                ? Image.network(
                    PostService.getUserAvatarUrl(c.userId),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      isProg ? Icons.code_rounded : Icons.person_rounded,
                      size: 18,
                      color: accent,
                    ),
                  )
                : Icon(
                    isProg ? Icons.code_rounded : Icons.person_rounded,
                    size: 18,
                    color: accent,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_timeAgo(c.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (isMine)
                      GestureDetector(
                        onTap: () => _deleteComment(c.id),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  c.content,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textPrimary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}