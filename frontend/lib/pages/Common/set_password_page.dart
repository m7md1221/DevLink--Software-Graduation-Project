import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../Customer/customer_profile_setup_page.dart';
import '../Programmer/programmer_profile_setup_page.dart';
import 'login_page.dart';

class SetPasswordPage extends StatefulWidget {
  final String email;
  final String userType;

  const SetPasswordPage({
    super.key,
    required this.email,
    required this.userType,
  });

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
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
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.signUp(
      email: widget.email,
      password: _passController.text,
      userType: widget.userType,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final int userId = result.data?['userId'] ?? 0;

      if (widget.userType == 'Customer' && userId > 0) {
        await SessionManager.saveUser(
          userId: userId,
          userType: widget.userType,
          email: widget.email,
          hasProfile: false,
        );

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerProfileSetupPage(userId: userId),
          ),
          (route) => false,
        );
      } else if (widget.userType == 'Programmer' && userId > 0) {
        await SessionManager.saveUser(
          userId: userId,
          userType: widget.userType,
          email: widget.email,
          hasProfile: false,
        );

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ProgrammerProfileSetupPage(userId: userId),
          ),
          (route) => false,
        );
      } else {
        _showSuccessDialog();
      }
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    // ✅ تحديد حجم مناسب للديسكتوب
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMaxWidth = screenWidth > 1100 ? 480.0 : 400.0;
    final isDesktop = screenWidth > 1100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogMaxWidth),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 32 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 20 : 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: const Color(0xFF10B981),
                      size: isDesktop ? 48 : 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Account Created!',
                    style: TextStyle(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your DevLink account is ready. Please log in to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: isDesktop ? 14 : 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: isDesktop ? 54 : 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(
                              userType: widget.userType,
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Go to Login',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isDesktop ? 15 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

    return Scaffold(
      body: Stack(
        children: [
          // ===== Background =====
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
          Positioned(
            top: -60,
            left: -40,
            child: _blurCircle(200, Colors.white.withOpacity(0.18)),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _blurCircle(260, Colors.white.withOpacity(0.16)),
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
                              Text(
                                'Set Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isDesktop ? 36 : 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Almost done! Create a secure password.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: isDesktop ? 15 : 14,
                                ),
                              ),
                              SizedBox(height: isDesktop ? 42 : 32),

                              // ===== Form Card =====
                              Container(
                                padding: EdgeInsets.all(isDesktop ? 32 : 22),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(isDark ? 0.4 : 0.15),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Password',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: isDesktop ? 15 : 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _passController,
                                        obscureText: _obscurePass,
                                        decoration: _inputDecoration(
                                          hint: 'Enter password',
                                          icon: Icons.lock_outline_rounded,
                                          isDark: isDark,
                                          isDesktop: isDesktop,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscurePass
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              color: isDark
                                                  ? const Color(0xFF64748B)
                                                  : Colors.grey.shade500,
                                            ),
                                            onPressed: () => setState(() =>
                                                _obscurePass = !_obscurePass),
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Password is required';
                                          }
                                          if (v.length < 6) {
                                            return 'At least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Confirm Password',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: isDesktop ? 15 : 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _confirmController,
                                        obscureText: _obscureConfirm,
                                        decoration: _inputDecoration(
                                          hint: 'Re-enter password',
                                          icon: Icons.lock_outline_rounded,
                                          isDark: isDark,
                                          isDesktop: isDesktop,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscureConfirm
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              color: isDark
                                                  ? const Color(0xFF64748B)
                                                  : Colors.grey.shade500,
                                            ),
                                            onPressed: () => setState(() =>
                                                _obscureConfirm =
                                                    !_obscureConfirm),
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Please confirm your password';
                                          }
                                          if (v != _passController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: isDesktop ? 32 : 28),

                                      // ===== Create Account Button =====
                                      SizedBox(
                                        width: double.infinity,
                                        height: isDesktop ? 60 : 54,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _createAccount,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  'Create Account',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isDesktop ? 16 : 15,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                        ),
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

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 40, spreadRadius: 5),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    required bool isDesktop,
    Widget? suffix,
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
      prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
      suffixIcon: suffix,
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
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.8),
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
}