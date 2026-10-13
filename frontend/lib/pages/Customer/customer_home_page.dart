import 'package:flutter/material.dart';
import 'package:devlink/main.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/theme_toggle.dart';
import '../../theme/theme_manager.dart';
import '../Common/welcome_page.dart';
import 'create_post_page.dart';
import 'widgets/post_card.dart';
import 'user_profile_page.dart';
import 'search_users_page.dart';
import 'contact_support_page.dart';

class CustomerHomePage extends StatefulWidget {
  final int userId;
  final String authorName;
  final String authorType;

  const CustomerHomePage({
    super.key,
    required this.userId,
    this.authorName = 'User',
    this.authorType = 'Customer',
  });

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _currentIndex = 0;

  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    final posts = await PostService.getFeed(userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await SessionManager.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          userId: widget.userId,
          authorName: widget.authorName,
          authorType: widget.authorType,
        ),
      ),
    );

    if (created == true) _loadFeed();
  }

  void _openProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: userId,
          currentUserId: widget.userId,
          authorName: widget.authorName,
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
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // ✅ ننشئ الـ pages هنا — داخل build
    final pages = [
      _buildFeedTab(),
      SearchUsersPage(currentUserId: widget.userId),
      ContactSupportPage(userId: widget.userId),
      UserProfilePage(
        userId: widget.userId,
        currentUserId: widget.userId,
        authorName: widget.authorName,
        authorType: widget.authorType,
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1.2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: cardColor,
            selectedItemColor: const Color(0xFF8B5CF6),
            unselectedItemColor: isDark
                ? const Color(0xFF64748B)
                : const Color(0xFF94A3B8),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.support_agent_rounded),
                label: 'Support',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openCreatePost,
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 6,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  // ============================================================
  // FEED TAB
  // ============================================================
  Widget _buildFeedTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: _loadFeed,
        child: CustomScrollView(
          slivers: [
            // ===== Top Bar =====
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'DevLink',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    ThemeToggle(themeManager: themeManager, compact: true),
                    const SizedBox(width: 8),
                    Material(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _logout,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== Create Post Box =====
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Material(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _openCreatePost,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: borderColor,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF8B5CF6)
                                  .withOpacity(0.12),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                PostService.getUserAvatarUrl(widget.userId),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF8B5CF6),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "What's on your mind?",
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.photo_library_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ===== Feed =====
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              )
            else if (_posts.isEmpty)
              SliverToBoxAdapter(
                child: _emptyFeed(textPrimary, textSecondary),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => PostCard(
                      post: _posts[i],
                      currentUserId: widget.userId,
                      onChanged: _loadFeed,
                      onOpenProfile: () => _openProfile(_posts[i].userId),
                    ),
                    childCount: _posts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFeed(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.article_outlined,
              size: 56,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to share something!',
            style: TextStyle(fontSize: 13.5, color: textSecondary),
          ),
        ],
      ),
    );
  }
}