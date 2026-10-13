import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'reset_verify_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String userType;

  const ForgotPasswordPage({
    super.key,
    required this.userType,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.sendResetCode(
      _emailController.text.trim().toLowerCase(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetVerifyPage(
            email: _emailController.text.trim().toLowerCase(),
            userType: widget.userType,
            expiresInMinutes: result.expiresInMinutes ?? 5,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ كشف الوضع (Light / Dark)
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ ألوان حسب الوضع
    final bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final iconColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF1E293B);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ]
                : const [
                    Color(0xFFEFF6FF),
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        // ===== Content (Responsive + maxWidth) =====
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ✅ نفس breakpoints الداشبورد
              final isDesktop = constraints.maxWidth > 1100;
              final isTablet = constraints.maxWidth > 700 &&
                  constraints.maxWidth <= 1100;

              final hPad = isDesktop ? 40.0 : 24.0;
              final vPad = isDesktop ? 32.0 : 24.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPad,
                      vertical: vPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== Back Button =====
                        Material(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          elevation: 0,
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
                        SizedBox(height: isDesktop ? 56 : 40),

                        // ===== Icon =====
                        Center(
                          child: Container(
                            width: isDesktop ? 110 : 90,
                            height: isDesktop ? 110 : 90,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF60A5FA),
                                  Color(0xFF3B82F6),
                                  Color(0xFF1D4ED8),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6)
                                      .withOpacity(isDark ? 0.5 : 0.30),
                                  blurRadius: 24,
                                  spreadRadius: -4,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              size: isDesktop ? 50 : 42,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 32 : 26),

                        // ===== Title =====
                        Center(
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: isDesktop ? 32 : 28,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Enter your registered email and we will send you a reset code',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isDesktop ? 14.5 : 13.5,
                                color: textSecondary,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 44 : 36),

                        // ===== Form Card =====
                        Container(
                          padding: EdgeInsets.all(isDesktop ? 32 : 24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: borderColor,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : const Color(0xFF0F172A)
                                        .withOpacity(0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Address',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 14.5 : 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  cursorColor: const Color(0xFF3B82F6),
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'you@example.com',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                      color: isDark
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF1D4ED8),
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: inputFill,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: isDesktop ? 20 : 18,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: borderColor,
                                        width: 1.4,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3B82F6),
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEF4444),
                                        width: 1.4,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEF4444),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    final ok = RegExp(
                                      r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$',
                                    ).hasMatch(v.trim());
                                    if (!ok) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                SizedBox(height: isDesktop ? 28 : 24),

                                // ===== Send Code Button =====
                                SizedBox(
                                  width: double.infinity,
                                  height: isDesktop ? 60 : 56,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFF2563EB),
                                          Color(0xFF3B82F6),
                                          Color(0xFF06B6D4),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6)
                                              .withOpacity(0.28),
                                          blurRadius: 18,
                                          spreadRadius: -4,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _onSend,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
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
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.send_rounded,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'SEND RESET CODE',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isDesktop ? 15 : 14,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    letterSpacing: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 36 : 28),

                        // ===== Footer =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Your data is secure and encrypted',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: isDesktop ? 13.5 : 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}