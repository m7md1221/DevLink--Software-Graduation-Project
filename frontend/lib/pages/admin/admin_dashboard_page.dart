import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import '../common/welcome_page.dart';
import 'admin_users_page.dart';
import 'admin_posts_page.dart';
import 'admin_verifications_page.dart';
import 'admin_add_admin_page.dart';
import 'admin_support_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final int userId;

  const AdminDashboardPage({
    super.key,
    required this.userId,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final Color primary = const Color(0xFF3B82F6);
  final Color primaryDark = const Color(0xFF1D4ED8);
  final Color primaryDeep = const Color(0xFF1E3A8A);
  final Color accentViolet = const Color(0xFF8B5CF6);

  static const double maxWidth = 1200;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  void _openUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
    );
  }

  void _openPosts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminPostsPage()),
    );
  }

  void _openVerifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminVerificationsPage()),
    );
  }

  void _openAddAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAddAdminPage()),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminSupportPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = isDark
        ? const [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF1E3A8A),
            Color(0xFF2E1065),
          ]
        : const [
            Color(0xFFEEF2FF),
            Color(0xFFE0E7FF),
            Color(0xFFF5F3FF),
            Color(0xFFFAF5FF),
          ];

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E3A8A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade700;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : primary.withOpacity(0.15);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradient,
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(
                  color: primary.withOpacity(isDark ? 0.03 : 0.05),
                ),
              ),
            ),
          ),

          Positioned(
            top: -100,
            right: -100,
            child: _glowCircle(
              400,
              primary.withOpacity(isDark ? 0.18 : 0.28),
            ),
          ),
          Positioned(
            top: 180,
            left: -130,
            child: _glowCircle(
              350,
              accentViolet.withOpacity(isDark ? 0.12 : 0.20),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: _glowCircle(
              450,
              primaryDeep.withOpacity(isDark ? 0.10 : 0.18),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1100;
                final isTablet = constraints.maxWidth > 700 &&
                    constraints.maxWidth <= 1100;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 40 : 20,
                            vertical: isDesktop ? 24 : 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(
                                isDark,
                                cardColor,
                                textPrimary,
                                textSecondary,
                                borderColor,
                                isDesktop: isDesktop,
                              ),
                              SizedBox(height: isDesktop ? 32 : 20),
                              _buildHeroCard(isDesktop),
                              SizedBox(height: isDesktop ? 36 : 24),
                              _buildSectionTitle('Management', textPrimary),
                              SizedBox(height: isDesktop ? 20 : 14),
                              _buildManagementGrid(
                                isDark,
                                cardColor,
                                textPrimary,
                                textSecondary,
                                isDesktop: isDesktop,
                                isTablet: isTablet,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor, {
    required bool isDesktop,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 28,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage your platform',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeToggle(
              themeManager: themeManager,
              compact: true,
            ),
            const SizedBox(width: 10),
            Material(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              elevation: isDark ? 0 : 2,
              shadowColor: primary.withOpacity(0.2),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark, primaryDeep],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 32 : 28),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.45),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: isDesktop ? 90 : 78,
                height: isDesktop ? 90 : 78,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  size: isDesktop ? 46 : 40,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: isDesktop ? 22 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, Admin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 8 : 4),
                    Text(
                      'You have full access to manage the platform',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12.5,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildManagementGrid(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    final cards = [
      _MenuCardData(
        icon: Icons.people_alt_rounded,
        title: 'User Management',
        subtitle: 'View, add, edit, and delete users',
        color: const Color(0xFF3B82F6),
        onTap: _openUsers,
      ),
      _MenuCardData(
        icon: Icons.article_rounded,
        title: 'Posts Management',
        subtitle: 'Review and approve customer posts',
        color: const Color(0xFFF59E0B),
        onTap: _openPosts,
      ),
      _MenuCardData(
        icon: Icons.verified_user_rounded,
        title: 'User Verification',
        subtitle: 'Review CVs and verify programmers',
        color: const Color(0xFF10B981),
        onTap: _openVerifications,
      ),
      _MenuCardData(
        icon: Icons.admin_panel_settings_rounded,
        title: 'Add New Admin',
        subtitle: 'Create a new admin account',
        color: const Color(0xFF8B5CF6),
        onTap: _openAddAdmin,
      ),
      _MenuCardData(
        icon: Icons.support_agent_rounded,
        title: 'Support Messages',
        subtitle: 'Reply to user messages',
        color: const Color(0xFF10B981),
        onTap: _openSupport,
      ),
    ];

    if (isDesktop || isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 3.2,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return _buildMenuCard(
            data: cards[index],
            isDark: isDark,
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDesktop: isDesktop,
          );
        },
      );
    }

    return Column(
      children: cards.asMap().entries.map((entry) {
        final isLast = entry.key == cards.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: _buildMenuCard(
            data: entry.value,
            isDark: isDark,
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDesktop: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMenuCard({
    required _MenuCardData data,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDesktop,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: data.onTap,
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 22 : 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: data.color.withOpacity(isDark ? 0.3 : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: data.color.withOpacity(isDark ? 0.15 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 16 : 14),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: isDesktop ? 30 : 26,
                ),
              ),
              SizedBox(width: isDesktop ? 18 : 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        fontSize: isDesktop ? 17 : 15.5,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: data.color,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class _MenuCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _MenuCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const double spacing = 40;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}