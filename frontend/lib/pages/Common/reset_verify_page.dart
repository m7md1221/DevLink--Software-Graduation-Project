import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'reset_password_page.dart';

class ResetVerifyPage extends StatefulWidget {
  final String email;
  final String userType;
  final int expiresInMinutes;

  const ResetVerifyPage({
    super.key,
    required this.email,
    required this.userType,
    this.expiresInMinutes = 5,
  });

  @override
  State<ResetVerifyPage> createState() => _ResetVerifyPageState();
}

class _ResetVerifyPageState extends State<ResetVerifyPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      _showSnack('Please enter the full 6-digit code', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.verifyResetCode(
      email: widget.email,
      code: _code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            email: widget.email,
            userType: widget.userType,
          ),
        ),
      );
    } else {
      _showSnack(result.message, isError: true);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() {});
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
      ),
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
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

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
            final vPad = isDesktop ? 32.0 : 24.0;

            // ✅ حجم خانة الكود حسب الجهاز
            final boxW = isDesktop ? 56.0 : 46.0;
            final boxH = isDesktop ? 72.0 : 58.0;
            final boxFontSize = isDesktop ? 26.0 : 22.0;

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
                      SizedBox(height: isDesktop ? 44 : 30),

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
                              Icons.mark_email_read_rounded,
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
                          'Check Your Email',
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
                            'We sent a 6-digit reset code to\n${widget.email}',
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
                      const SizedBox(height: 12),

                      // ===== Timer Badge =====
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6)
                                .withOpacity(isDark ? 0.15 : 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF3B82F6)
                                  .withOpacity(isDark ? 0.4 : 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF3B82F6),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Code valid for ${widget.expiresInMinutes} minutes',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF1D4ED8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 42 : 32),

                      // ===== Form Card =====
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 32 : 22),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: borderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Enter the code',
                              style: TextStyle(
                                fontSize: isDesktop ? 15 : 14,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            SizedBox(height: isDesktop ? 26 : 20),

                            // ===== 6 Digits =====
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                final isFilled =
                                    _controllers[i].text.isNotEmpty;
                                return SizedBox(
                                  width: boxW,
                                  height: boxH,
                                  child: TextField(
                                    controller: _controllers[i],
                                    focusNode: _focusNodes[i],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: TextStyle(
                                      fontSize: boxFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: isFilled
                                          ? const Color(0xFF3B82F6)
                                              .withOpacity(0.15)
                                          : inputFill,
                                      contentPadding: EdgeInsets.zero,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: isFilled
                                              ? const Color(0xFF3B82F6)
                                              : borderColor,
                                          width: 1.6,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF3B82F6),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (v) => _onDigitChanged(i, v),
                                  ),
                                );
                              }),
                            ),
                            SizedBox(height: isDesktop ? 32 : 26),

                            // ===== Verify Button =====
                            SizedBox(
                              width: double.infinity,
                              height: isDesktop ? 62 : 56,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
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
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verify,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    disabledBackgroundColor:
                                        Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
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
                                          'VERIFY',
                                          style: TextStyle(
                                            fontSize: isDesktop ? 15 : 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.6,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ===== Resend =====
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final r =
                                          await ApiService.sendResetCode(
                                              widget.email);
                                      if (!mounted) return;
                                      _showSnack(
                                        r.message,
                                        isError: !r.success,
                                      );
                                    },
                              child: const Text(
                                'Resend code',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
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
}