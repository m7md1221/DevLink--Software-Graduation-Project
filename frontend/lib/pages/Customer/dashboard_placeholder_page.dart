import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import '../Common/welcome_page.dart';

class DashboardPlaceholderPage extends StatefulWidget {
  final int userId;

  const DashboardPlaceholderPage({
    super.key,
    required this.userId,
  });

  @override
  State<DashboardPlaceholderPage> createState() =>
      _DashboardPlaceholderPageState();
}

class _DashboardPlaceholderPageState
    extends State<DashboardPlaceholderPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  final Color primary = const Color(0xFF10B981);
  final Color primaryDark = const Color(0xFF047857);
  final Color primaryDeep = const Color(0xFF064E3B);

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
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
    _loadProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.getCustomerProfile(widget.userId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) _profile = result.data;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFECFDF5);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF064E3B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade700;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : primary.withOpacity(0.15);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _glowCircle(
              360,
              primary.withOpacity(isDark ? 0.18 : 0.35),
            ),
          ),
          Positioned(
            top: 200,
            left: -140,
            child: _glowCircle(
              300,
              primary.withOpacity(isDark ? 0.08 : 0.15),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -100,
            child: _glowCircle(
              380,
              primaryDeep.withOpacity(isDark ? 0.12 : 0.22),
            ),
          ),

          // ===== Content (Responsive + maxWidth) =====
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // ✅ نفس breakpoints الداشبورد
                final isDesktop = constraints.maxWidth > 1100;
                final isTablet = constraints.maxWidth > 700 &&
                    constraints.maxWidth <= 1100;

                final hPad = isDesktop ? 40.0 : 20.0;
                final vTop = isDesktop ? 32.0 : 12.0;
                final vBottom = isDesktop ? 60.0 : 30.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            hPad,
                            vTop,
                            hPad,
                            vBottom,
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
                              SizedBox(height: isDesktop ? 28 : 20),
                              _isLoading
                                  ? _buildLoading(isDark, cardColor)
                                  : _buildHeroCard(
                                      isDesktop: isDesktop,
                                    ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              if (!_isLoading)
                                _buildStatsRow(
                                  isDark,
                                  isDesktop: isDesktop,
                                ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              if (!_isLoading)
                                _buildInfoGrid(
                                  isDark,
                                  isDesktop: isDesktop,
                                ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              _buildComingSoon(
                                isDesktop: isDesktop,
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

  // ============================================================
  // TOP BAR — responsive
  // ============================================================
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 28,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome back 👋',
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

  // ============================================================
  // LOADING
  // ============================================================
  Widget _buildLoading(bool isDark, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: CircularProgressIndicator(color: primary),
      ),
    );
  }

  // ============================================================
  // HERO CARD — responsive
  // ============================================================
  Widget _buildHeroCard({required bool isDesktop}) {
    final nickname = _profile?['nickname'] ?? 'User';
    final city = _profile?['city'] ?? '-';
    final hasImage = _profile?['hasImage'] == true;

    final avatarSize = isDesktop ? 104.0 : 86.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark, primaryDeep],
        ),
        borderRadius: BorderRadius.circular(28),
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
              width: 120,
              height: 120,
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? Image.network(
                              ApiService.getProfileImageUrl(
                                  widget.userId),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withOpacity(0.2),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: isDesktop ? 48 : 40,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.white.withOpacity(0.2),
                              child: Icon(
                                Icons.person_rounded,
                                size: isDesktop ? 48 : 40,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: isDesktop ? 20 : 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 26 : 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Customer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
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
        ],
      ),
    );
  }

  // ============================================================
  // STATS ROW — responsive
  // ============================================================
  Widget _buildStatsRow(bool isDark, {required bool isDesktop}) {
    final phone = _profile?['phoneNumber'] ?? '-';
    final city = _profile?['city'] ?? '-';
    final country = _profile?['country'] ?? '-';

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.phone_rounded,
            value: phone.length > 10
                ? '${phone.substring(0, 10)}...'
                : phone,
            label: 'Phone',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            isDesktop: isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 14 : 10),
        Expanded(
          child: _statCard(
            icon: Icons.location_city_rounded,
            value: city,
            label: 'City',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            isDesktop: isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 14 : 10),
        Expanded(
          child: _statCard(
            icon: Icons.public_rounded,
            value: country.length > 8
                ? '${country.substring(0, 8)}...'
                : country,
            label: 'Country',
            color: const Color(0xFF10B981),
            isDark: isDark,
            isDesktop: isDesktop,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
    required bool isDesktop,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF064E3B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade600;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 20 : 16,
        horizontal: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.15 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isDesktop ? 22 : 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isDesktop ? 14 : 13,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isDesktop ? 12 : 11,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO GRID — responsive
  // ============================================================
  Widget _buildInfoGrid(bool isDark, {required bool isDesktop}) {
    final phone = _profile?['phoneNumber'] ?? '-';
    final city = _profile?['city'] ?? '-';
    final country = _profile?['country'] ?? '-';

    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF064E3B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Profile Information',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        _infoCard(
          icon: Icons.phone_rounded,
          label: 'Phone Number',
          value: phone,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        SizedBox(height: isDesktop ? 14 : 10),
        _infoCard(
          icon: Icons.location_city_rounded,
          label: 'City / Village',
          value: city,
          color: const Color(0xFFF59E0B),
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        SizedBox(height: isDesktop ? 14 : 10),
        _infoCard(
          icon: Icons.public_rounded,
          label: 'Country',
          value: country,
          color: const Color(0xFF10B981),
          isDark: isDark,
          isDesktop: isDesktop,
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required bool isDesktop,
    Widget? trailing,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF064E3B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade600;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFD1FAE5);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 18 : 14,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 12 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isDesktop ? 22 : 18),
          ),
          SizedBox(width: isDesktop ? 16 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ============================================================
  // COMING SOON — responsive
  // ============================================================
  Widget _buildComingSoon({required bool isDesktop}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 28 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(0.95),
            primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.40),
            blurRadius: 26,
            spreadRadius: -5,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Icon(
              Icons.rocket_launch_rounded,
              size: isDesktop ? 140 : 120,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 10 : 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: isDesktop ? 22 : 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: isDesktop ? 19 : 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Browse services, place orders, and connect with programmers — all from your dashboard.',
                style: TextStyle(
                  fontSize: isDesktop ? 13.5 : 12.5,
                  color: Colors.white,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}