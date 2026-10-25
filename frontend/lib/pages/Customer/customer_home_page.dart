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
  List<UserSearchResult> _suggestedPeople = [];
  bool _isLoading = true;

  static double _getFeedWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 700;
    if (width > 1100) return 650;
    if (width > 800) return 600;
    return width;
  }

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadSuggestedPeople();
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

  Future<void> _loadSuggestedPeople() async {
    final people = await PostService.searchUsers(query: 'a');
    if (!mounted) return;
    setState(() {
      _suggestedPeople = people
          .where((p) => p.userId != widget.userId)
          .take(5)
          .toList();
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
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

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
      appBar: _currentIndex == 0
          ? AppBar(
              elevation: 0,
              toolbarHeight: 60,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x228B5CF6),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'DevLink',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                ThemeToggle(themeManager: themeManager, compact: true),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor, width: 1.2)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: cardColor,
            selectedItemColor: const Color(0xFF8B5CF6),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: 'Support'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
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

  Widget _buildFeedTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1100;
        final feedWidth = _getFeedWidth(context);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 100),
                  child: _buildLeftSidebar(isDark, cardColor, textPrimary, textSecondary, borderColor),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: feedWidth),
                  child: _buildFeedContent(isDark, cardColor, textPrimary, textSecondary, borderColor),
                ),
              ),
            ),
            if (isDesktop)
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 16, 20, 100),
                  child: _buildRightSidebar(isDark, cardColor, textPrimary, textSecondary, borderColor),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeedContent(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: _loadFeed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF8B5CF6).withOpacity(0.12),
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
                          const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
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
                      currentUserType: widget.authorType,
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

  Widget _buildLeftSidebar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final totalLikes = _posts.fold<int>(0, (sum, p) => sum + p.likeCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 3),
                ),
                child: ClipOval(
                  child: Image.network(
                    PostService.getUserAvatarUrl(widget.userId),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.authorType,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            children: [
              _quickLink(Icons.home_rounded, 'Home', true, textPrimary, textSecondary),
              _quickLink(Icons.search_rounded, 'Search', false, textPrimary, textSecondary),
              _quickLink(Icons.support_agent_rounded, 'Support', false, textPrimary, textSecondary),
              _quickLink(Icons.person_rounded, 'Profile', false, textPrimary, textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Stats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),
              _statRow(Icons.article_rounded, 'Posts', '${_posts.length}', const Color(0xFF3B82F6), textPrimary),
              const SizedBox(height: 10),
              _statRow(Icons.favorite_rounded, 'Likes', '$totalLikes', const Color(0xFFEF4444), textPrimary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickLink(IconData icon, String label, bool active, Color textPrimary, Color textSecondary) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (label == 'Search') setState(() => _currentIndex = 1);
          else if (label == 'Support') setState(() => _currentIndex = 2);
          else if (label == 'Profile') setState(() => _currentIndex = 3);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? const Color(0xFF8B5CF6) : textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? const Color(0xFF8B5CF6) : textPrimary,
                ),
              ),
              if (active) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value, Color color, Color textPrimary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRightSidebar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  Text(
                    'Suggested People',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_suggestedPeople.isEmpty)
                Text(
                  'No suggestions',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                )
              else
                ..._suggestedPeople.map((p) => _suggestedPersonTile(p, textPrimary, textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    'Trending',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _trendingTag('#Flutter', '2.5K posts', const Color(0xFF10B981), textPrimary, textSecondary),
              _trendingTag('#DotNet', '1.8K posts', const Color(0xFF8B5CF6), textPrimary, textSecondary),
              _trendingTag('#JavaScript', '3.2K posts', const Color(0xFFF59E0B), textPrimary, textSecondary),
              _trendingTag('#Mobile', '980 posts', const Color(0xFF3B82F6), textPrimary, textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lightbulb_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Pro Tip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Add a profile photo and complete your profile to get 3x more engagement on your posts!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _suggestedPersonTile(UserSearchResult p, Color textPrimary, Color textSecondary) {
    final isProg = p.userType == 'Programmer';
    final accent = isProg ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openProfile(p.userId),
        borderRadius: BorderRadius.circular(10),
        child: Row(
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
                child: p.hasImage
                    ? Image.network(
                        PostService.getUserAvatarUrl(p.userId),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    p.userType,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: accent,
                      fontWeight: FontWeight.w700,
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

  Widget _trendingTag(String tag, String count, Color color, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            child: const Icon(Icons.article_outlined, size: 56, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
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