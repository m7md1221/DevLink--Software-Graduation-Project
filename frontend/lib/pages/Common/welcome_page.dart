import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import 'login_page.dart';
import 'signup_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _entranceController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  late Animation<double> _fadeHeader;
  late Animation<Offset> _slideHeader;

  late Animation<double> _fadeAdmin;
  late Animation<Offset> _slideAdmin;

  late Animation<double> _fadeCustomer;
  late Animation<Offset> _slideCustomer;

  late Animation<double> _fadeProgrammer;
  late Animation<Offset> _slideProgrammer;

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );

    _fadeHeader = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.20, 0.60, curve: Curves.easeOut),
    );

    _slideHeader = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAdmin = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 0.75, curve: Curves.easeOut),
    );

    _slideAdmin = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    _fadeCustomer = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.55, 0.90, curve: Curves.easeOut),
    );

    _slideCustomer = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _fadeProgrammer = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );

    _slideProgrammer = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.70, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entranceController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _entranceController.reset();
          _entranceController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> openLoginWithLoading(
      BuildContext context, String userType) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (BuildContext dialogContext) {
        return _LoadingOverlay(userType: userType);
      },
    );

    await Future.delayed(const Duration(milliseconds: 1600));

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              LoginPage(userType: userType),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  void openSignUp(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignUpPage(),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        Color(0xFF1E3A8A),
                      ]
                    : const [
                        Color(0xFF1E3A8A),
                        Color(0xFF3B82F6),
                        Color(0xFF60A5FA),
                      ],
              ),
            ),
          ),

          // ===== Floating Icons =====
          Positioned(
            top: 60,
            left: 20,
            child: Opacity(
              opacity: 0.22,
              child:
                  Icon(Icons.code_rounded, size: 28, color: Colors.white),
            ),
          ),
          Positioned(
            top: 120,
            right: 30,
            child: Opacity(
              opacity: 0.22,
              child:
                  Icon(Icons.flutter_dash, size: 32, color: Colors.white),
            ),
          ),
          Positioned(
            top: 220,
            left: 40,
            child: Opacity(
              opacity: 0.22,
              child: Icon(Icons.terminal_rounded,
                  size: 24, color: Colors.white),
            ),
          ),
          Positioned(
            top: 320,
            right: 20,
            child: Opacity(
              opacity: 0.22,
              child: Icon(Icons.data_object_rounded,
                  size: 26, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 200,
            left: 30,
            child: Opacity(
              opacity: 0.22,
              child:
                  Icon(Icons.cloud_rounded, size: 30, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 40,
            child: Opacity(
              opacity: 0.22,
              child: Icon(Icons.storage_rounded,
                  size: 26, color: Colors.white),
            ),
          ),

          // ===== Glow Circles =====
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(isDark ? 0.08 : 0.20),
              ),
            ),
          ),
          Positioned(
            top: 150,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBFDBFE)
                    .withOpacity(isDark ? 0.08 : 0.20),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(isDark ? 0.08 : 0.20),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF93C5FD)
                    .withOpacity(isDark ? 0.08 : 0.20),
              ),
            ),
          ),

          // ===== Content (Responsive + maxWidth + Scrollable) =====
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // ✅ نفس breakpoints الداشبورد
                final isDesktop = constraints.maxWidth > 1100;
                final isTablet = constraints.maxWidth > 700 &&
                    constraints.maxWidth <= 1100;

                // ✅ كشف الشاشات القصيرة لمنع الـ Overflow
                final isCompact = constraints.maxHeight < 720;

                final hPad = isDesktop ? 40.0 : 26.0;

                // ✅ أحجام متغيرة حسب الحالة
                final logoSize = isDesktop
                    ? (isCompact ? 130.0 : 180.0)
                    : (isCompact ? 100.0 : 145.0);

                final welcomeFontSize = isDesktop
                    ? (isCompact ? 30.0 : 38.0)
                    : (isCompact ? 24.0 : 30.0);

                final spacerTop = isCompact ? 20.0 : (isDesktop ? 40.0 : 32.0);
                final spacerMid = isCompact ? 24.0 : (isDesktop ? 50.0 : 40.0);
                final spacerBottom = isCompact ? 20.0 : (isDesktop ? 36.0 : 28.0);

                return Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      // ✅ يمنع الـ Overflow نهائياً
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              // ===== Top Bar — Theme Toggle =====
                              Padding(
                                padding: EdgeInsets.only(
                                  top: isDesktop ? 20 : 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ThemeToggle(
                                    themeManager: themeManager,
                                    compact: true,
                                  ),
                                ),
                              ),

                              SizedBox(height: spacerTop),

                              // ===== Logo =====
                              ScaleTransition(
                                scale: _logoScale,
                                child: FadeTransition(
                                  opacity: _logoFade,
                                  child: Container(
                                    width: logoSize,
                                    height: logoSize,
                                    padding: EdgeInsets.all(
                                      logoSize * 0.15,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        logoSize * 0.25,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6)
                                              .withOpacity(0.5),
                                          blurRadius: 45,
                                          spreadRadius: 5,
                                          offset: const Offset(0, 18),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/devlink_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: spacerTop),

                              // ===== Header =====
                              FadeTransition(
                                opacity: _fadeHeader,
                                child: SlideTransition(
                                  position: _slideHeader,
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Welcome to ',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: welcomeFontSize,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'DevLink',
                                            style: TextStyle(
                                              color: const Color(
                                                  0xFFBFDBFE),
                                              fontSize: welcomeFontSize,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.25),
                                          ),
                                        ),
                                        child: Text(
                                          'Connect • Build • Deliver',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                isDesktop ? 14 : 13,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: spacerMid),

                              // ===== "Choose your account type" =====
                              FadeTransition(
                                opacity: _fadeAdmin,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBFDBFE),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Choose your account type',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                            isDesktop ? 19 : 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isDesktop ? 22 : 16),

                              // ===== Admin Button =====
                              FadeTransition(
                                opacity: _fadeAdmin,
                                child: SlideTransition(
                                  position: _slideAdmin,
                                  child: _AccountButton(
                                    title: 'Admin',
                                    subtitle:
                                        'Control panel & system configuration',
                                    icon: Icons
                                        .admin_panel_settings_rounded,
                                    accentColor:
                                        const Color(0xFF3B82F6),
                                    isDesktop: isDesktop,
                                    onTap: () => openLoginWithLoading(
                                        context, 'Admin'),
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 18 : 14),

                              // ===== Customer Button =====
                              FadeTransition(
                                opacity: _fadeCustomer,
                                child: SlideTransition(
                                  position: _slideCustomer,
                                  child: _AccountButton(
                                    title: 'Customer',
                                    subtitle:
                                        'Explore services & place new orders',
                                    icon: Icons.person_rounded,
                                    accentColor:
                                        const Color(0xFF10B981),
                                    isDesktop: isDesktop,
                                    onTap: () => openLoginWithLoading(
                                        context, 'Customer'),
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 18 : 14),

                              // ===== Programmer Button =====
                              FadeTransition(
                                opacity: _fadeProgrammer,
                                child: SlideTransition(
                                  position: _slideProgrammer,
                                  child: _AccountButton(
                                    title: 'Programmer',
                                    subtitle:
                                        'Manage tasks, code & deliver products',
                                    icon: Icons.code_rounded,
                                    accentColor:
                                        const Color(0xFF8B5CF6),
                                    isDesktop: isDesktop,
                                    onTap: () => openLoginWithLoading(
                                        context, 'Programmer'),
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 28 : 22),

                              // ===== Sign Up =====
                              FadeTransition(
                                opacity: _fadeProgrammer,
                                child: _SignUpButton(
                                  onTap: () => openSignUp(context),
                                  isDesktop: isDesktop,
                                ),
                              ),

                              // ✅ مساحة سفلية بدل Spacer
                              SizedBox(height: spacerBottom),
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
}

// ============================================================
// Account Type Button
// ============================================================
class _AccountButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDesktop;
  final VoidCallback onTap;

  const _AccountButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  State<_AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<_AccountButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _isHovered || _isPressed;

    final cardColor = isActive
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark
            ? const Color(0xFF1E293B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95));

    final titleColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

    final hPad = widget.isDesktop ? 24.0 : 18.0;
    final vPad = widget.isDesktop ? 18.0 : 14.0;
    final iconBoxPad = widget.isDesktop ? 16.0 : 12.0;
    final iconSize = widget.isDesktop ? 30.0 : 24.0;
    final titleSize = widget.isDesktop ? 18.0 : 16.0;
    final subtitleSize = widget.isDesktop ? 13.0 : 12.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.025 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: vPad,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isHovered
                    ? widget.accentColor.withOpacity(0.8)
                    : (isDark
                        ? const Color(0xFF334155)
                        : Colors.white),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.accentColor.withOpacity(0.35)
                      : Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                  blurRadius: _isHovered ? 24 : 14,
                  offset: Offset(0, _isHovered ? 10 : 5),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(iconBoxPad),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? widget.accentColor
                        : widget.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    size: iconSize,
                    color:
                        _isHovered ? Colors.white : widget.accentColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: subtitleSize,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(
                    _isHovered ? 6 : 0,
                    0,
                    0,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: _isHovered
                        ? widget.accentColor
                        : (isDark
                            ? const Color(0xFF64748B)
                            : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Sign Up Button
// ============================================================
class _SignUpButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDesktop;

  const _SignUpButton({
    required this.onTap,
    required this.isDesktop,
  });

  @override
  State<_SignUpButton> createState() => _SignUpButtonState();
}

class _SignUpButtonState extends State<_SignUpButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDesktop ? 22 : 16,
              vertical: widget.isDesktop ? 12 : 9,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withOpacity(0.95)
                  : Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered
                    ? Colors.white
                    : Colors.white.withOpacity(0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    _isHovered ? 0.18 : 0.10,
                  ),
                  blurRadius: _isHovered ? 14 : 8,
                  offset: Offset(0, _isHovered ? 6 : 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: widget.isDesktop ? 16 : 14,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Text(
                  "Don't have an account?",
                  style: TextStyle(
                    color: const Color(0xFF475569),
                    fontSize: widget.isDesktop ? 13 : 12,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Sign Up',
                  style: TextStyle(
                    color: const Color(0xFF1E3A8A),
                    fontSize: widget.isDesktop ? 13.5 : 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Loading Overlay
// ============================================================
class _LoadingOverlay extends StatelessWidget {
  final String userType;

  const _LoadingOverlay({required this.userType});

  Color _accentFor(String type) {
    switch (type) {
      case 'Admin':
        return const Color(0xFF3B82F6);
      case 'Customer':
        return const Color(0xFF10B981);
      case 'Programmer':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF60A5FA);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Admin':
        return Icons.admin_panel_settings_rounded;
      case 'Customer':
        return Icons.person_rounded;
      case 'Programmer':
        return Icons.code_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(userType);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E3A8A),
                Color(0xFF1E40AF),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: accent.withOpacity(0.35),
                blurRadius: 40,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _iconFor(userType),
                  size: 34,
                  color: accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Preparing $userType Portal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your workspace...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}