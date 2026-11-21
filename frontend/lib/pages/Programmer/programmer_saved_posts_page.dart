import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../Customer/widgets/post_card.dart';
import '../Customer/user_profile_page.dart';

class ProgrammerSavedPostsPage extends StatefulWidget {
  final int userId;
  final String authorType;

  const ProgrammerSavedPostsPage({
    super.key,
    required this.userId,
    this.authorType = 'Programmer',
  });

  @override
  State<ProgrammerSavedPostsPage> createState() =>
      _ProgrammerSavedPostsPageState();
}

class _ProgrammerSavedPostsPageState extends State<ProgrammerSavedPostsPage> {
  List<PostModel> _savedPosts = [];
  bool _isLoading = true;

  static const Color primary = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await PostService.getSavedPosts(widget.userId);
    if (!mounted) return;
    setState(() {
      _savedPosts = list;
      _isLoading = false;
    });
  }

  void _openProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: userId,
          currentUserId: widget.userId,
          authorName: 'User',
          authorType: widget.authorType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF);
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bookmark_rounded,
                            color: Color(0xFFF59E0B), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Projects',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            '${_savedPosts.length} saved ${_savedPosts.length == 1 ? "item" : "items"}',
                            style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primary))
                      : _savedPosts.isEmpty
                          ? _empty(textPrimary, textSecondary)
                          : RefreshIndicator(
                              color: primary,
                              onRefresh: _load,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 30),
                                itemCount: _savedPosts.length,
                                itemBuilder: (_, i) => PostCard(
                                  post: _savedPosts[i],
                                  currentUserId: widget.userId,
                                  currentUserType: 'Programmer',
                                  onChanged: _load,
                                  onOpenProfile: () =>
                                      _openProfile(_savedPosts[i].userId),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_border_rounded,
                  size: 56, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Saved Posts',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the bookmark icon on any post to save it here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}