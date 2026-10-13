import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String userType;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.userType,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.resetPassword(
      email: widget.email,
      newPassword: _passController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showSuccessDialog();
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
              padding: EdgeInsets.all(screenWidth > 1100 ? 32 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(screenWidth > 1100 ? 20 : 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: const Color(0xFF10B981),
                      size: screenWidth > 1100 ? 48 : 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Password Reset!',
                    style: TextStyle(
                      fontSize: screenWidth > 1100 ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your password has been updated. You can now log in with your new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: screenWidth > 1100 ? 14 : 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: screenWidth > 1100 ? 54 : 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
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
                        'Back to Login',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: screenWidth > 1100 ? 15 : 14,
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

  @override
  Widget build(BuildContext context) {
    // ✅ كشف الوضع
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final iconColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF1E293B);
    final iconBg = isDark
        ? const Color(0xFF3B82F6).withOpacity(0.15)
        : const Color(0xFFE0EAFF);
    final iconFg = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF1D4ED8);

    return Scaffold(
      backgroundColor: bgColor,
      // ===== Content (Responsive + maxWidth) =====
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ✅ نفس breakpoints الداشبورد
            final isDesktop = constraints.maxWidth > 1100;
            final isTablet = constraints.maxWidth > 700 &&
                constraints.maxWidth <= 1100;

            final hPad = isDesktop ? 40.0 : 24.0;
            final vPad = isDesktop ? 32.0 : 12.0;

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

                      SizedBox(height: isDesktop ? 44 : 32),

                      // ===== Icon =====
                      Center(
                        child: Container(
                          width: isDesktop ? 104 : 84,
                          height: isDesktop ? 104 : 84,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.password_rounded,
                              size: isDesktop ? 46 : 38,
                              color: iconFg,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 32 : 24),

                      // ===== Title =====
                      Center(
                        child: Text(
                          'New Password',
                          style: TextStyle(
                            fontSize: isDesktop ? 32 : 27,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Create a strong new password for your account',
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

                      SizedBox(height: isDesktop ? 42 : 34),

                      // ===== Form Card =====
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 32 : 24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: borderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Password',
                                style: TextStyle(
                                  fontSize: isDesktop ? 14 : 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passController,
                                obscureText: _obscurePass,
                                cursorColor: const Color(0xFF3B82F6),
                                style: TextStyle(
                                  fontSize: isDesktop ? 16 : 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                decoration: _inputDecoration(
                                  hint: 'Enter new password',
                                  icon: Icons.lock_outline_rounded,
                                  isDark: isDark,
                                  isDesktop: isDesktop,
                                  suffix: IconButton(
                                    onPressed: () => setState(
                                        () => _obscurePass = !_obscurePass),
                                    icon: Icon(
                                      _obscurePass
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: textMuted,
                                      size: 20,
                                    ),
                                  ),
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
                                  fontSize: isDesktop ? 14 : 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmController,
                                obscureText: _obscureConfirm,
                                cursorColor: const Color(0xFF3B82F6),
                                style: TextStyle(
                                  fontSize: isDesktop ? 16 : 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                decoration: _inputDecoration(
                                  hint: 'Re-enter new password',
                                  icon: Icons.lock_outline_rounded,
                                  isDark: isDark,
                                  isDesktop: isDesktop,
                                  suffix: IconButton(
                                    onPressed: () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm),
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: textMuted,
                                      size: 20,
                                    ),
                                  ),
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

                              SizedBox(height: isDesktop ? 28 : 24),

                              // ===== Reset Button =====
                              SizedBox(
                                width: double.infinity,
                                height: isDesktop ? 62 : 58,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF3B82F6),
                                        Color(0xFF06B6D4),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6)
                                            .withOpacity(0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _onReset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'RESET PASSWORD',
                                            style: TextStyle(
                                              fontSize: isDesktop ? 15 : 14,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.6,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 36 : 26),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
        : const Color(0xFF94A3B8);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final iconColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF1D4ED8);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textMuted,
        fontSize: 14,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: inputFill,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDesktop ? 22 : 20,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.4,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF3B82F6),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 2,
        ),
      ),
    );
  }
}