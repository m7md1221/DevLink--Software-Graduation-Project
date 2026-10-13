import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'set_password_page.dart';

class VerifyCodePage extends StatefulWidget {
  final String email;
  final String userType;
  final int expiresInMinutes;

  const VerifyCodePage({
    super.key,
    required this.email,
    required this.userType,
    this.expiresInMinutes = 5,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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

    final result = await ApiService.verifyCode(
      email: widget.email,
      code: _code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetPasswordPage(
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

    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : Colors.transparent;
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

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
          Positioned(
            top: -60,
            left: -40,
            child: _blurCircle(
              200,
              Colors.white.withOpacity(isDark ? 0.08 : 0.18),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _blurCircle(
              260,
              Colors.white.withOpacity(isDark ? 0.06 : 0.16),
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
                                'Verify Email',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isDesktop ? 36 : 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'We sent a 6-digit code to\n${widget.email}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: isDesktop ? 15 : 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ===== Timer Badge =====
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Code valid for ${widget.expiresInMinutes} minutes',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isDesktop ? 42 : 32),

                              // ===== Form Card =====
                              Container(
                                padding: EdgeInsets.all(
                                  isDesktop ? 32 : 22,
                                ),
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
                                child: Column(
                                  children: [
                                    Text(
                                      'Enter verification code',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: isDesktop ? 17 : 15,
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 26 : 20),

                                    // ===== 6 Digit Inputs =====
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
                                            keyboardType:
                                                TextInputType.number,
                                            maxLength: 1,
                                            style: TextStyle(
                                              fontSize: boxFontSize,
                                              fontWeight: FontWeight.w800,
                                              color: textPrimary,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: InputDecoration(
                                              counterText: '',
                                              filled: true,
                                              fillColor: isFilled
                                                  ? const Color(0xFF3B82F6)
                                                      .withOpacity(0.15)
                                                  : inputFill,
                                              contentPadding:
                                                  EdgeInsets.zero,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14),
                                                borderSide: BorderSide(
                                                  color: borderColor,
                                                ),
                                              ),
                                              enabledBorder:
                                                  OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14),
                                                borderSide: BorderSide(
                                                  color: isFilled
                                                      ? const Color(
                                                          0xFF3B82F6)
                                                      : borderColor,
                                                  width: 1.8,
                                                ),
                                              ),
                                              focusedBorder:
                                                  OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14),
                                                borderSide:
                                                    const BorderSide(
                                                  color: Color(0xFF3B82F6),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            onChanged: (v) =>
                                                _onDigitChanged(i, v),
                                          ),
                                        );
                                      }),
                                    ),
                                    SizedBox(height: isDesktop ? 34 : 28),

                                    // ===== Verify Button =====
                                    SizedBox(
                                      width: double.infinity,
                                      height: isDesktop ? 62 : 54,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _verify,
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
                                                'Verify',
                                                style: TextStyle(
                                                  fontSize:
                                                      isDesktop ? 16 : 15,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // ===== Resend =====
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              final r = await ApiService
                                                  .sendCode(widget.email);
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
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
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
}