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

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final iconColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B);

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
                // ✅ زر الرجوع فوق ثابت
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

                // ✅ المحتوى يبدأ من فوق (مش في النص)
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isMobile ? 24 : 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8), // ✅ مسافة أقل

                                // Icon
                                Center(
                                  child: Container(
                                    width: isMobile ? 90 : 110, // ✅ صغرنا الأيقونة شوي
                                    height: isMobile ? 90 : 110,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.5 : 0.30),
                                          blurRadius: 25,
                                          spreadRadius: 3,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.lock_reset_rounded,
                                      size: isMobile ? 44 : 54,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isMobile ? 18 : 24), // ✅ مسافة أقل

                                // Title
                                Center(
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: isMobile ? 26 : 30, // ✅ صغرنا الخط شوي
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8), // ✅ مسافة أقل
                                Center(
                                  child: Text(
                                    'No worries! Enter your registered email and we will send you a reset code.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isMobile ? 13.5 : 14.5,
                                      color: textSecondary,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isMobile ? 24 : 32), // ✅ مسافة أقل

                                // Form Card
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(24), // ✅ زوايا أنعم شوي
                                    border: Border.all(color: borderColor, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF0F172A).withOpacity(0.05),
                                        blurRadius: 25,
                                        offset: const Offset(0, 12),
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
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          ),
                                        ),
                                        const SizedBox(height: 8), // ✅ مسافة أقل
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType: TextInputType.emailAddress,
                                          cursorColor: const Color(0xFF3B82F6),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'you@example.com',
                                            hintStyle: TextStyle(
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                              fontSize: 14,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.mail_outline_rounded,
                                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                              size: 20,
                                            ),
                                            filled: true,
                                            fillColor: inputFill,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // ✅ حشوة أقل
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: borderColor, width: 1.4),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
                                            ),
                                            focusedErrorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                                            ),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Email is required';
                                            }
                                            final ok = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(v.trim());
                                            if (!ok) return 'Enter a valid email';
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: isMobile ? 20 : 24), // ✅ مسافة أقل

                                        // Send Button
                                        SizedBox(
                                          width: double.infinity,
                                          height: isMobile ? 52 : 56, // ✅ زر أقصر شوي
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
                                              onPressed: _isLoading ? null : _onSend,
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
                                                  : const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.send_rounded, size: 18),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'SEND RESET CODE',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w900,
                                                            letterSpacing: 1.2,
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
                                SizedBox(height: isMobile ? 24 : 32), // ✅ مسافة أقل

                                // Footer
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shield_outlined, size: 16, color: textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Your data is secure and encrypted',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20), // مسافة أمان تحت
                              ],
                            ),
                          ),
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