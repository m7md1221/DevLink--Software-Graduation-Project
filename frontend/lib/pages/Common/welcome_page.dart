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
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _cardsFade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );

    _cardsSlide = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _cardsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _entranceController.reset();
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> openLoginWithLoading(BuildContext context, String userType) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => _LoadingOverlay(userType: userType),
    );

    await Future.delayed(const Duration(milliseconds: 1600));

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              LoginPage(userType: userType),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignUpPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
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
          // ✅ الخلفية
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF0F172A), Color(0xFF1E1B4B)]
                    : const [Color(0xFF0EA5E9), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
            ),
          ),

          // ✅ دوائر جمالية في الخلفية
          Positioned(
            top: -100,
            right: -100,
            child: _buildBlurCircle(400, Colors.white.withOpacity(0.1)),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _buildBlurCircle(300, Colors.white.withOpacity(0.1)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: isDesktop
                        ? _buildDesktopLayout(context)
                        : _buildMobileLayout(context),
                  ),
                );
              },
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: ThemeToggle(
              themeManager: themeManager,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 📌 Desktop Layout (Split Screen)
  // ============================================================
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // اليسار: اللوجو والعنوان
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/devlink_logo.png'),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              letterSpacing: -1,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Welcome to\n',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: 'DevLink',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Connect. Build. Deliver.\nThe ultimate platform for programmers and clients.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'منصتك الأولى للربط بين المبرمجين وأصحاب المشاريع.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // ✅ شعارات الثقة (Trust Badges) بعد التعديل
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildTrustBadge(Icons.verified_rounded, 'Verified Programmers'),
                            _buildTrustBadge(Icons.support_agent_rounded, 'Strong Support'),
                            _buildTrustBadge(Icons.high_quality_rounded, 'High Quality Projects'), // ✅ الإضافة الجديدة
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // اليمين: كروت الدخول
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: FadeTransition(
              opacity: _cardsFade,
              child: SlideTransition(
                position: _cardsSlide,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModernCard(
                      title: 'Admin',
                      desc: 'Full system control',
                      icon: Icons.admin_panel_settings_rounded,
                      color: const Color(0xFF3B82F6),
                      onTap: () => openLoginWithLoading(context, 'Admin'),
                    ),
                    const SizedBox(height: 16),
                    _buildModernCard(
                      title: 'Customer',
                      desc: 'Hire top developers',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => openLoginWithLoading(context, 'Customer'),
                    ),
                    const SizedBox(height: 16),
                    _buildModernCard(
                      title: 'Programmer',
                      desc: 'Find your next project',
                      icon: Icons.code_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => openLoginWithLoading(context, 'Programmer'),
                    ),
                    const SizedBox(height: 40),
                    _buildSignUpLink(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 📌 Mobile Layout
  // ============================================================
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(
              scale: _logoScale,
              child: Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset('assets/images/devlink_logo.png'),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _headerFade,
            child: SlideTransition(
              position: _headerSlide,
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Welcome to ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'DevLink',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect. Build. Deliver.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'منصتك الأولى للربط بين المبرمجين وأصحاب المشاريع',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          FadeTransition(
            opacity: _cardsFade,
            child: SlideTransition(
              position: _cardsSlide,
              child: Column(
                children: [
                  _buildModernCard(
                    title: 'Admin',
                    desc: 'Full system control',
                    icon: Icons.admin_panel_settings_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: () => openLoginWithLoading(context, 'Admin'),
                  ),
                  const SizedBox(height: 16),
                  _buildModernCard(
                    title: 'Customer',
                    desc: 'Hire top developers',
                    icon: Icons.person_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => openLoginWithLoading(context, 'Customer'),
                  ),
                  const SizedBox(height: 16),
                  _buildModernCard(
                    title: 'Programmer',
                    desc: 'Find your next project',
                    icon: Icons.code_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => openLoginWithLoading(context, 'Programmer'),
                  ),
                  const SizedBox(height: 32),
                  _buildSignUpLink(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 
  Widget _buildTrustBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2), // خلفية داكنة شفافة
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 100, spreadRadius: 50),
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _HoverCard(
      color: color,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return GestureDetector(
      onTap: () => openSignUp(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 10),
            Text(
              "Don't have an account? ",
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
            const Text(
              'Sign Up',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 🌟 Hover Card Widget
// ============================================================
class _HoverCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback onTap;

  const _HoverCard({
    required this.child,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
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
          scale: _isPressed ? 0.97 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                if (_isHovered)
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ⏳ Loading Overlay
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.3),
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
                  color: accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(userType), size: 36, color: accent),
              ),
              const SizedBox(height: 24),
              Text(
                'Entering $userType Portal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}