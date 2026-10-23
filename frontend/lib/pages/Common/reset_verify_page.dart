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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B);
    final iconBg = isDark ? const Color(0xFF3B82F6).withOpacity(0.15) : const Color(0xFFE0EAFF);
    final iconFg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    final inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

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
                    ? const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)]
                    : const [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              ),
            ),
          ),

          // ===== Glows =====
          Positioned(
            top: -100,
            right: -100,
            child: _glowCircle(320, const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.25)),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _glowCircle(300, const Color(0xFF1D4ED8).withOpacity(isDark ? 0.10 : 0.20)),
          ),

          // ===== Content =====
          SafeArea(
            child: Column(
              children: [
                // ✅ زر الرجوع فوق
                Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 24 : 40, 12, isMobile ? 24 : 40, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
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
                            border: Border.all(color: borderColor, width: 1.2),
                          ),
                          child: Icon(Icons.arrow_back_rounded, color: iconColor, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),

                // ✅ المحتوى يبدأ من فوق
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 24 : 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),

                            // Icon
                            Center(
                              child: Container(
                                width: isMobile ? 90 : 110,
                                height: isMobile ? 90 : 110,
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: iconBg.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.mark_email_read_rounded,
                                  size: isMobile ? 44 : 54,
                                  color: iconFg,
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 18 : 24),

                            // Title
                            Center(
                              child: Text(
                                'Check Your Email',
                                style: TextStyle(
                                  fontSize: isMobile ? 26 : 30,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'We sent a 6-digit reset code to\n${widget.email}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isMobile ? 13.5 : 14.5,
                                  color: textSecondary,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Timer Badge
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.4 : 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Code valid for ${widget.expiresInMinutes} minutes',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 24 : 32),

                            // Form Card
                            Container(
                              padding: EdgeInsets.all(isMobile ? 20 : 28),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF0F172A).withOpacity(0.05),
                                    blurRadius: 25,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Enter the code',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 16 : 20),

                                  // 6 Digits
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(6, (i) {
                                      final isFilled = _controllers[i].text.isNotEmpty;
                                      return SizedBox(
                                        width: isMobile ? 42 : 52,
                                        height: isMobile ? 54 : 66,
                                        child: TextField(
                                          controller: _controllers[i],
                                          focusNode: _focusNodes[i],
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          maxLength: 1,
                                          style: TextStyle(
                                            fontSize: isMobile ? 20 : 24,
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
                                                ? const Color(0xFF3B82F6).withOpacity(0.15)
                                                : inputFill,
                                            contentPadding: EdgeInsets.zero,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isFilled ? const Color(0xFF3B82F6) : borderColor,
                                                width: 1.6,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                                            ),
                                          ),
                                          onChanged: (v) => _onDigitChanged(i, v),
                                        ),
                                      );
                                    }),
                                  ),
                                  SizedBox(height: isMobile ? 22 : 28),

                                  // Verify Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: isMobile ? 52 : 56,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3B82F6).withOpacity(0.35),
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
                                          disabledBackgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                              )
                                            : const Text(
                                                'VERIFY',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.4,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Resend
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            final r = await ApiService.sendResetCode(widget.email);
                                            if (!mounted) return;
                                            _showSnack(r.message, isError: !r.success);
                                          },
                                    child: const Text(
                                      'Resend code',
                                      style: TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
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