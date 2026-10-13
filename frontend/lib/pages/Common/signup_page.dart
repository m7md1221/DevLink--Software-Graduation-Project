import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/google_sign_in_button.dart';
import '../Customer/customer_profile_setup_page.dart';
import '../Programmer/programmer_profile_setup_page.dart';
import 'verify_code_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  String? _selectedUserType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserType == null) {
      _showSnack('Please choose account type', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.sendCode(
      _emailController.text.trim().toLowerCase(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(
            email: _emailController.text.trim().toLowerCase(),
            userType: _selectedUserType!,
            expiresInMinutes: result.expiresInMinutes ?? 5,
          ),
        ),
      );
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _handleGoogleSignUp(String idToken) async {
    if (_selectedUserType == null) {
      _showSnack('Please choose account type first', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.googleLogin(
      idToken: idToken,
      userType: _selectedUserType!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final data = result.data!;
      final int userId = data['userId'] ?? 0;
      final String userType = data['userType'] ?? _selectedUserType!;
      final String email = data['email'] ?? '';
      final bool isNewUser = data['isNewUser'] == true;

      await SessionManager.saveUser(
        userId: userId,
        userType: userType,
        email: email,
        hasProfile: false,
      );

      if (!mounted) return;

      if (isNewUser) {
        if (userType == 'Customer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CustomerProfileSetupPage(userId: userId),
            ),
          );
        } else if (userType == 'Programmer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProgrammerProfileSetupPage(userId: userId),
            ),
          );
        }
      } else {
        _showSnack('Welcome back! Please login', isError: false);
      }
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : Colors.grey.shade400;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade500;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

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
                        Color(0xFF2563EB),
                        Color(0xFF3B82F6),
                        Color(0xFF60A5FA),
                        Color(0xFF7DD3FC),
                      ],
              ),
            ),
          ),

          // ===== Glow Orbs =====
          Positioned(
            top: -120,
            right: -100,
            child: _glowOrb(
              size: 320,
              color: Colors.white.withOpacity(isDark ? 0.10 : 0.35),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _glowOrb(
              size: 360,
              color: (isDark
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF93C5FD))
                  .withOpacity(isDark ? 0.20 : 0.55),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DotsPainter(),
              ),
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

                final hPad = isDesktop ? 40.0 : 26.0;
                final vPad = isDesktop ? 32.0 : 12.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: vPad,
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      isDesktop ? 14 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.30),
                                          Colors.white.withOpacity(0.10),
                                        ],
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.person_add_alt_1_rounded,
                                      color: Colors.white,
                                      size: isDesktop ? 30 : 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Create\nAccount',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isDesktop ? 38 : 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        height: 1.05,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join DevLink and start your journey today',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withOpacity(0.92),
                                      fontSize: isDesktop ? 15 : 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 3,
                                    width: isDesktop ? 180 : 130,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.white.withOpacity(0.6),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isDesktop ? 36 : 28),

                              // ===== Form Card =====
                              Container(
                                padding: EdgeInsets.all(
                                  isDesktop ? 32 : 22,
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: isDark
                                        ? borderColor
                                        : Colors.white.withOpacity(0.6),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.4)
                                          : const Color(0xFF1E40AF)
                                              .withOpacity(0.35),
                                      blurRadius: 45,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.alternate_email_rounded,
                                            size: 16,
                                            color: isDark
                                                ? const Color(0xFF60A5FA)
                                                : Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Email address',
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontWeight: FontWeight.w800,
                                              fontSize:
                                                  isDesktop ? 15 : 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction:
                                            TextInputAction.done,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                        decoration: _inputDecoration(
                                          hint: 'you@example.com',
                                          icon:
                                              Icons.mail_outline_rounded,
                                          isDark: isDark,
                                          isDesktop: isDesktop,
                                        ),
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().isEmpty) {
                                            return 'Email is required';
                                          }
                                          final ok = RegExp(
                                            r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$',
                                          ).hasMatch(v.trim());
                                          if (!ok) {
                                            return 'Enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(
                                          height: isDesktop ? 28 : 24),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.tune_rounded,
                                            size: 16,
                                            color: isDark
                                                ? const Color(0xFF60A5FA)
                                                : Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Account type',
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontWeight: FontWeight.w800,
                                              fontSize:
                                                  isDesktop ? 15 : 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _typeCard(
                                              label: 'Customer',
                                              subtitle: 'Hire developers',
                                              icon: Icons.person_rounded,
                                              color: const Color(0xFF10B981),
                                              value: 'Customer',
                                              isDark: isDark,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              isDesktop: isDesktop,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _typeCard(
                                              label: 'Programmer',
                                              subtitle: 'Find projects',
                                              icon: Icons.code_rounded,
                                              color: const Color(0xFF8B5CF6),
                                              value: 'Programmer',
                                              isDark: isDark,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              isDesktop: isDesktop,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height: isDesktop ? 24 : 20),

                                      // ===== Google Sign Up (mobile only) =====
                                      if (!kIsWeb) ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                color: borderColor,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                'OR',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: borderColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        GoogleSignInButton(
                                          accentColor:
                                              const Color(0xFF2563EB),
                                          onIdToken: _handleGoogleSignUp,
                                        ),
                                        const SizedBox(height: 20),
                                      ],

                                      // ===== Send Code Button =====
                                      SizedBox(
                                        width: double.infinity,
                                        height: isDesktop ? 62 : 56,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _onSendCode,
                                          style:
                                              ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.transparent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      16),
                                            ),
                                          ),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  Color(0xFF2563EB),
                                                  Color(0xFF3B82F6),
                                                  Color(0xFF06B6D4),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      16),
                                            ),
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color:
                                                            Colors.white,
                                                      ),
                                                    )
                                                  : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .send_rounded,
                                                          size: 18,
                                                          color:
                                                              Colors.white,
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          'Send Verification Code',
                                                          style: TextStyle(
                                                            fontSize:
                                                                isDesktop
                                                                    ? 16
                                                                    : 15,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: Colors
                                                                .white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 30 : 22),

                              // ===== Login Link =====
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.28),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withOpacity(0.85),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            Navigator.pop(context),
                                        child: const Text(
                                          'Login',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 30 : 20),
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

  Widget _glowOrb({required double size, required Color color}) {
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    required bool isDesktop,
  }) {
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : Colors.grey.shade400;
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : Colors.transparent;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: textMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
      filled: true,
      fillColor: inputFill,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDesktop ? 22 : 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }

  Widget _typeCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String value,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDesktop,
  }) {
    final selected = _selectedUserType == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedUserType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 20 : 16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(isDark ? 0.20 : 0.10)
              : (isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color
                : (isDark
                    ? const Color(0xFF334155)
                    : Colors.transparent),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: isDesktop ? 32 : 26,
              color: selected ? color : textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: isDesktop ? 15 : 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? color.withOpacity(0.75)
                    : textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: isDesktop ? 11.5 : 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    const double spacing = 28;
    const double radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}