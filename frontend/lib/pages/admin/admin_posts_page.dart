import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({super.key});

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

class _AdminPostsPageState extends State<AdminPostsPage>
    with TickerProviderStateMixin {
  final Color primary = const Color(0xFFF59E0B);
  final Color primaryDark = const Color(0xFFD97706);

  static const double maxWidth = 1200;

  late AnimationController _entranceController;
  late AnimationController _floatController;
  late Animation<double> _fade;
  late Animation<Offset> _slideHeader;
  late Animation<Offset> _slideCard;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideHeader = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _slideCard = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
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
    final iconColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF1E293B);

    return Scaffold(
      body: Stack(
        children: [
          // ===== Background Gradient =====
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF292524),
                      ]
                    : const [
                        Color(0xFFFFFBEB),
                        Color(0xFFFEF3C7),
                        Color(0xFFF5F3FF),
                      ],
              ),
            ),
          ),

          // ===== Animated Glow =====
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -120 + (_floatController.value * 15),
                    right: -120 - (_floatController.value * 10),
                    child: _glow(
                      400,
                      primary.withOpacity(isDark ? 0.15 : 0.28),
                    ),
                  ),
                  Positioned(
                    bottom: -140 - (_floatController.value * 15),
                    left: -120 + (_floatController.value * 10),
                    child: _glow(
                      420,
                      primaryDark.withOpacity(isDark ? 0.10 : 0.18),
                    ),
                  ),
                ],
              );
            },
          ),

          // ===== Content =====
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1100;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 40 : 20,
                        vertical: isDesktop ? 24 : 12,
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== App Bar =====
                            SlideTransition(
                              position: _slideHeader,
                              child: _buildAppBar(
                                isDark,
                                cardColor,
                                textPrimary,
                                textSecondary,
                                borderColor,
                                iconColor,
                              ),
                            ),
                            SizedBox(height: isDesktop ? 48 : 40),

                            // ===== Coming Soon Card =====
                            SlideTransition(
                              position: _slideCard,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 700,
                                  ),
                                  child: _buildComingSoon(
                                    isDark,
                                    cardColor,
                                    textPrimary,
                                    textSecondary,
                                    borderColor,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  Widget _buildAppBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color iconColor,
  ) {
    return Row(
      children: [
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          elevation: isDark ? 0 : 2,
          shadowColor: primary.withOpacity(0.2),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: iconColor,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Posts Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Review and approve customer posts',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ThemeToggle(
          themeManager: themeManager,
          compact: true,
        ),
      ],
    );
  }

  // ============================================================
  // COMING SOON
  // ============================================================
  Widget _buildComingSoon(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // ===== Icon =====
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withOpacity(0.20),
                  primaryDark.withOpacity(0.20),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: primary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.article_rounded,
              size: 48,
              color: primary,
            ),
          ),
          const SizedBox(height: 22),

          // ===== Title =====
          Text(
            'Posts Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review and approve posts from customers before they go live',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: textSecondary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),

          // ===== Features Preview =====
          _buildFeatureRow(
            isDark,
            textPrimary,
            textSecondary,
            Icons.visibility_rounded,
            'Review Posts',
            'See all pending customer posts',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            isDark,
            textPrimary,
            textSecondary,
            Icons.check_circle_rounded,
            'Approve / Reject',
            'Approve good posts or reject bad ones',
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            isDark,
            textPrimary,
            textSecondary,
            Icons.flag_rounded,
            'Flag Content',
            'Report inappropriate content',
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    IconData icon,
    String title,
    String desc,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.15),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
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