
import 'dart:ui';
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
import 'admin_statistics_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final int userId;

  const AdminDashboardPage({
    super.key,
    required this.userId,
  });

  @override
  State<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  static const Color primary = Color(0xFF3B82F6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color pink = Color(0xFFEC4899);
  static const Color cyan = Color(0xFF06B6D4);

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
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
      MaterialPageRoute(
        builder: (_) => const WelcomePage(),
      ),
      (route) => false,
    );
  }

  void _navigate(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1120)
          : const Color(0xFFF4F7FC),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildBackground(isDark),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final horizontalPadding =
                        width < 600 ? 16.0 : 28.0;

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1440,
                        ),
                        child: CustomScrollView(
                          physics:
                              const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  18,
                                  horizontalPadding,
                                  0,
                                ),
                                child: _buildTopBar(isDark),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  28,
                                  horizontalPadding,
                                  0,
                                ),
                                child: _buildHero(
                                  isDark,
                                  width,
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  26,
                                  horizontalPadding,
                                  0,
                                ),
                                child: _buildSectionHeading(
                                  isDark,
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                16,
                                horizontalPadding,
                                32,
                              ),
                              sliver: SliverLayoutBuilder(
                                builder: (context, sliver) {
                                  final availableWidth =
                                      sliver.crossAxisExtent;

                                  final columns =
                                      availableWidth >= 1100
                                          ? 3
                                          : availableWidth >= 650
                                              ? 2
                                              : 1;

                                  return SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent:
                                          columns == 1
                                              ? 116
                                              : 156,
                                    ),
                                    delegate:
                                        SliverChildListDelegate(
                                      _buildCards(isDark),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  0,
                                  horizontalPadding,
                                  28,
                                ),
                                child: _buildFooter(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(
              color: isDark
                  ? Colors.white.withOpacity(0.025)
                  : const Color(0xFF64748B)
                      .withOpacity(0.045),
            ),
          ),
        ),
        Positioned(
          top: -180,
          right: -100,
          child: _orb(
            420,
            primary.withOpacity(isDark ? 0.15 : 0.09),
          ),
        ),
        Positioned(
          bottom: -180,
          left: -100,
          child: _orb(
            400,
            violet.withOpacity(isDark ? 0.13 : 0.08),
          ),
        ),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 90,
        sigmaY: 90,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111C30).withOpacity(0.94)
            : Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFE5EAF3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 400;

          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primary, violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DevLink',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF17233B),
                      ),
                    ),
                    if (!compact)
                      Text(
                        'ADMINISTRATION PORTAL',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white54
                              : Colors.blueGrey,
                        ),
                      ),
                  ],
                ),
              ),
              ThemeToggle(
                themeManager: themeManager,
                compact: true,
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Logout',
                child: Material(
                  color: const Color(0xFFEF4444)
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(13),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFEF4444),
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero(bool isDark, double width) {
    final compact = width < 700;

    return Container(
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF4F46E5),
            Color(0xFF7138C9),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.23),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -35,
            child: Icon(
              Icons.hub_rounded,
              size: compact ? 130 : 200,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          Positioned(
            right: compact ? 0 : 30,
            bottom: -25,
            child: Icon(
              Icons.code_rounded,
              size: compact ? 80 : 120,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'ADMIN CONTROL CENTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Welcome back, Admin',
                style: TextStyle(
                  fontSize: compact ? 27 : 38,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 510,
                ),
                child: Text(
                  'Your platform, your control. Manage users, '
                  'review projects and keep DevLink running smoothly.',
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    height: 1.7,
                    color: Colors.white.withOpacity(0.83),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _heroPill(
                    Icons.bolt_rounded,
                    'Platform management',
                  ),
                  _heroPill(
                    Icons.verified_user_rounded,
                    'Admin access',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(bool isDark) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 34,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF17233B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Everything you need, in one place.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white54
                      : Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_rounded,
                color: primary,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                '6 modules',
                style: TextStyle(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCards(bool isDark) {
    return [
      _moduleCard(
        title: 'User Management',
        subtitle: 'Manage platform accounts',
        description: 'Users & roles',
        icon: Icons.people_alt_rounded,
        color: primary,
        isDark: isDark,
        onTap: () => _navigate(const AdminUsersPage()),
        number: '01',
      ),
      _moduleCard(
        title: 'Posts Management',
        subtitle: 'Review project requests',
        description: 'Posts & moderation',
        icon: Icons.article_rounded,
        color: amber,
        isDark: isDark,
        onTap: () => _navigate(const AdminPostsPage()),
        number: '02',
      ),
      _moduleCard(
        title: 'Verifications',
        subtitle: 'Review programmer profiles',
        description: 'Verification center',
        icon: Icons.verified_user_rounded,
        color: green,
        isDark: isDark,
        onTap: () =>
            _navigate(const AdminVerificationsPage()),
        number: '03',
      ),
      _moduleCard(
        title: 'Support Center',
        subtitle: 'Manage support requests',
        description: 'Tickets & assistance',
        icon: Icons.support_agent_rounded,
        color: cyan,
        isDark: isDark,
        onTap: () => _navigate(const AdminSupportPage()),
        number: '04',
      ),
      _moduleCard(
        title: 'Statistics',
        subtitle: 'Explore platform insights',
        description: 'Reports & analytics',
        icon: Icons.insights_rounded,
        color: pink,
        isDark: isDark,
        onTap: () =>
            _navigate(const AdminStatisticsPage()),
        number: '05',
      ),
      _moduleCard(
        title: 'Add Administrator',
        subtitle: 'Create an admin account',
        description: 'Access management',
        icon: Icons.admin_panel_settings_rounded,
        color: violet,
        isDark: isDark,
        onTap: () =>
            _navigate(const AdminAddAdminPage()),
        number: '06',
      ),
    ];
  }

  Widget _moduleCard({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    required String number,
  }) {
    return _ModuleCard(
      title: title,
      subtitle: subtitle,
      description: description,
      icon: icon,
      color: color,
      isDark: isDark,
      number: number,
      onTap: onTap,
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111C30)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFE5EAF3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hub_rounded,
            color: primary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DevLink Administration',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isDark
                    ? Colors.white70
                    : const Color(0xFF334155),
              ),
            ),
          ),
          Text(
            'CONTROL PANEL',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? Colors.white38
                  : Colors.blueGrey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;
  final String number;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.number,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final color = widget.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(
          0,
          _hovered ? -4 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF111C30)
              : Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: _hovered
                ? color.withOpacity(0.55)
                : isDark
                    ? Colors.white.withOpacity(0.07)
                    : const Color(0xFFE8EDF5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? color.withOpacity(0.12)
                  : Colors.black.withOpacity(
                      isDark ? 0.06 : 0.025,
                    ),
              blurRadius: _hovered ? 25 : 14,
              offset: Offset(0, _hovered ? 10 : 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(23),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(23),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal =
                      constraints.maxWidth < 450;

                  return Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: color.withOpacity(
                            isDark ? 0.16 : 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(17),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 27,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: horizontal ? 14 : 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF17233B),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.blueGrey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.description,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFF5F7FB),
                          borderRadius:
                              BorderRadius.circular(11),
                        ),
                        child: Icon(
                          _hovered
                              ? Icons.arrow_forward_rounded
                              : Icons.chevron_right_rounded,
                          color: _hovered
                              ? color
                              : isDark
                                  ? Colors.white38
                                  : Colors.blueGrey.shade300,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 44.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
