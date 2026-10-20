import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import 'widgets/post_card.dart';

class UserProfilePage extends StatefulWidget {
  final int userId;
  final int currentUserId;
  final String authorName;
  final String authorType;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.currentUserId,
    required this.authorName,
    required this.authorType,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserPublicProfile? _profile;
  List<PostModel> _posts = [];
  List<UserSearchResult> _suggestedPeople = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final profile = await PostService.getUserProfile(widget.userId);
    final posts = await PostService.getUserPosts(
      userId: widget.userId,
      currentUserId: widget.currentUserId,
    );
    
    final people = await PostService.searchUsers(query: 'a');

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _posts = posts;
      _suggestedPeople = people.where((p) => p.userId != widget.userId).take(4).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final isProg = _profile?.userType == 'Programmer';
    final accent = isProg ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ThemeToggle(themeManager: themeManager, compact: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _profile == null
              ? Center(
                  child: Text(
                    'Profile not found',
                    style: TextStyle(color: textSecondary, fontSize: 15),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 1100;
                    
                    if (!isDesktop) {
                      // 🟢 الموبايل والتابلت (عمود واحد)
                      return _buildMainContent(isDark, cardColor, textPrimary, textSecondary, borderColor, accent);
                    }

                    // 🟢 الديسكتوب (3 أعمدة)
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // يسار: About & Skills
                        SizedBox(
                          width: 280,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 10, 100),
                            child: _buildLeftSidebar(cardColor, textPrimary, textSecondary, borderColor, accent),
                          ),
                        ),

                        // الوسط: المحتوى الرئيسي
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 750),
                              child: _buildMainContent(isDark, cardColor, textPrimary, textSecondary, borderColor, accent),
                            ),
                          ),
                        ),

                        // يمين: Suggested People & Communities
                        SizedBox(
                          width: 280,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(10, 16, 20, 100),
                            child: _buildRightSidebar(cardColor, textPrimary, textSecondary, borderColor, accent),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================
  Widget _buildMainContent(bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor, Color accent) {
    return RefreshIndicator(
      color: accent,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeader(isDark, cardColor, textPrimary, textSecondary, borderColor, accent),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsRow(cardColor, textPrimary, textSecondary, borderColor, accent),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLocationRow(cardColor, textPrimary, textSecondary, borderColor),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(width: 4, height: 18, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 10),
                      Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (_posts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor, width: 1.2)),
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => PostCard(
                    post: _posts[i],
                    currentUserId: widget.currentUserId,
                    currentUserType: widget.authorType,
                    onChanged: _load,
                  ),
                  childCount: _posts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // LEFT SIDEBAR
  // ============================================================
  Widget _buildLeftSidebar(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor, Color accent) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                  Icon(Icons.info_outline_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text('About', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _profile?.userType == 'Programmer' 
                    ? 'Passionate programmer specializing in ${_profile?.specialty ?? "software development"}. Always eager to learn and build great things.'
                    : 'Active member on DevLink. Looking for talented programmers to bring ideas to life.',
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.6),
              ),
              const SizedBox(height: 14),
              if (_profile?.university != null)
                _aboutRow(Icons.school_rounded, 'Studied at ${_profile!.university!}', textPrimary),
              if (_profile?.linkedInUrl != null && _profile!.linkedInUrl!.isNotEmpty)
                _aboutRow(Icons.link_rounded, 'LinkedIn Profile', textPrimary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aboutRow(IconData icon, String text, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RIGHT SIDEBAR
  // ============================================================
  Widget _buildRightSidebar(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor, Color accent) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                  const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text('People you may know', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 14),
              if (_suggestedPeople.isEmpty)
                Text('No suggestions', style: TextStyle(fontSize: 12, color: textSecondary))
              else
                ..._suggestedPeople.map((p) => _personTile(p, textPrimary, textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
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
                  const Icon(Icons.groups_rounded, size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text('Communities', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 14),
              _communityTile('Flutter Devs', '12K members', const Color(0xFF10B981), textPrimary, textSecondary),
              _communityTile('.NET Community', '8K members', const Color(0xFF8B5CF6), textPrimary, textSecondary),
              _communityTile('UI/UX Design', '5K members', const Color(0xFFF59E0B), textPrimary, textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _personTile(UserSearchResult p, Color textPrimary, Color textSecondary) {
    final isProg = p.userType == 'Programmer';
    final color = isProg ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
            child: ClipOval(
              child: p.hasImage 
                ? Image.network(PostService.getUserAvatarUrl(p.userId), fit: BoxFit.cover)
                : Icon(isProg ? Icons.code_rounded : Icons.person_rounded, size: 18, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary)),
                Text(p.userType, style: TextStyle(fontSize: 10.5, color: textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityTile(String title, String members, Color color, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.groups_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textPrimary)),
                Text(members, style: TextStyle(fontSize: 10.5, color: textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER (Responsive)
  // ============================================================
  Widget _buildHeader(bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor, Color accent) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            height: isMobile ? 100 : 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 0, isMobile ? 16 : 24, isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    width: isMobile ? 80 : 90,
                    height: isMobile ? 80 : 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardColor,
                      border: Border.all(color: cardColor, width: 4),
                    ),
                    child: ClipOval(
                      child: _profile!.hasImage
                          ? Image.network(PostService.getUserAvatarUrl(widget.userId), fit: BoxFit.cover)
                          : Icon(
                              _profile!.userType == 'Programmer' ? Icons.code_rounded : Icons.person_rounded,
                              color: accent,
                              size: isMobile ? 36 : 40,
                            ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _profile!.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 22,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (_profile!.isVerified == true) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profile!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withOpacity(0.3)),
                        ),
                        child: Text(
                          _profile!.userType,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent),
                        ),
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

  // ============================================================
  // STATS & INFO
  // ============================================================
  Widget _buildStatsRow(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor, width: 1.2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(Icons.article_rounded, '${_profile!.postCount}', 'Posts', accent, textPrimary, textSecondary),
          Container(width: 1, height: 40, color: borderColor),
          _statItem(Icons.work_rounded, _profile!.specialty ?? '-', 'Specialty', const Color(0xFFF59E0B), textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLocationRow(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor, width: 1.2)),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, size: 18, color: textSecondary),
          const SizedBox(width: 8),
          Text('${_profile!.city ?? 'Unknown'}, ${_profile!.country ?? 'Unknown'}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
        ],
      ),
    );
  }
}