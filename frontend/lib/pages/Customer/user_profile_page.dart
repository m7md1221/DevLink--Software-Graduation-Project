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

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _posts = posts;
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
          _profile?.nickname ?? 'Profile',
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : _profile == null
              ? Center(
                  child: Text(
                    'Profile not found',
                    style: TextStyle(color: textSecondary, fontSize: 15),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF8B5CF6),
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.75)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.20),
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipOval(
                                child: _profile!.hasImage
                                    ? Image.network(
                                        PostService.getUserAvatarUrl(widget.userId),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          isProg ? Icons.code_rounded : Icons.person_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      )
                                    : Icon(
                                        isProg ? Icons.code_rounded : Icons.person_rounded,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _profile!.nickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profile!.email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isProg ? Icons.code_rounded : Icons.person_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _profile!.userType,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (_profile!.isVerified == true) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              icon: Icons.article_rounded,
                              value: '${_profile!.postCount}',
                              label: 'Posts',
                              color: accent,
                              cardColor: cardColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                            ),
                          ),
                          if (_profile!.specialty != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statCard(
                                icon: Icons.workspace_premium_rounded,
                                value: _profile!.specialty!,
                                label: 'Specialty',
                                color: const Color(0xFFF59E0B),
                                cardColor: cardColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_profile!.city != null || _profile!.country != null) ...[
                        _infoCard(
                          icon: Icons.location_on_rounded,
                          value: '${_profile!.city ?? ''}, ${_profile!.country ?? ''}',
                          cardColor: cardColor,
                          textPrimary: textPrimary,
                          borderColor: borderColor,
                          color: const Color(0xFF3B82F6),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_profile!.university != null) ...[
                        _infoCard(
                          icon: Icons.school_rounded,
                          value: _profile!.university!,
                          cardColor: cardColor,
                          textPrimary: textPrimary,
                          borderColor: borderColor,
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Posts',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_posts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor, width: 1.2),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 42,
                                color: textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No posts yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._posts.map(
                          (p) => PostCard(
                            post: p,
                            currentUserId: widget.currentUserId,
                            onChanged: _load,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String value,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}