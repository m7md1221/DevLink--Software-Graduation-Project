import 'dart:convert';
import 'dart:io' show Platform;
import 'package:devlink/main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/session_manager.dart';
import '../../services/api_service.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/theme_toggle.dart';
import '../../theme/theme_manager.dart';
import '../Customer/customer_home_page.dart';
import '../Programmer/programmer_profile_setup_page.dart';
import '../Programmer/programmer_dashboard_page.dart';
import '../admin/admin_dashboard_page.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final String userType;

  const LoginPage({
    super.key,
    required this.userType,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();

  bool isLoading = false;
  bool hidePassword = true;

  static const double maxWidth = 1200;

  late AnimationController _cardController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _cardFade = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOut,
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutCubic,
      ),
    );

    _cardController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  Color get accentColor {
    switch (widget.userType) {
      case 'Admin':
        return const Color(0xFF3B82F6);
      case 'Customer':
        return const Color(0xFF10B981);
      case 'Programmer':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color get accentDark {
    switch (widget.userType) {
      case 'Admin':
        return const Color(0xFF1D4ED8);
      case 'Customer':
        return const Color(0xFF047857);
      case 'Programmer':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF1E40AF);
    }
  }

  Color get accentSoft {
    switch (widget.userType) {
      case 'Admin':
        return const Color(0xFFDBEAFE);
      case 'Customer':
        return const Color(0xFFD1FAE5);
      case 'Programmer':
        return const Color(0xFFEDE9FE);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  IconData get roleIcon {
    switch (widget.userType) {
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

  String get roleSubtitleAr {
    switch (widget.userType) {
      case 'Admin':
        return 'دخول لوحة التحكم وإدارة النظام';
      case 'Customer':
        return 'تسجيل الدخول لاستعراض الخدمات وإنشاء الطلبات';
      case 'Programmer':
        return 'تسجيل الدخول لإدارة المهام وتسليم المشاريع';
      default:
        return 'تسجيل الدخول للمتابعة';
    }
  }

  String get roleSubtitleEn {
    switch (widget.userType) {
      case 'Admin':
        return 'Access the control panel & manage the system';
      case 'Customer':
        return 'Sign in to explore services & place orders';
      case 'Programmer':
        return 'Sign in to manage tasks & deliver projects';
      default:
        return 'Sign in to continue to DevLink';
    }
  }

  String get emailHint {
    switch (widget.userType) {
      case 'Admin':
        return 'admin@devlink.com';
      case 'Customer':
        return 'your.email@example.com';
      case 'Programmer':
        return 'dev@devlink.com';
      default:
        return 'Enter your email';
    }
  }

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('الرجاء إدخال البريد وكلمة المرور', false);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'userType': widget.userType,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final int userId = data['userId'] ?? 0;
        final String userType = data['userType'] ?? widget.userType;
        final String email = data['email'] ?? '';

        final bool hasProfile = userType == 'Programmer'
            ? (data['hasProgrammerProfile'] ?? false)
            : (data['hasProfile'] ?? false);

        await SessionManager.saveUser(
          userId: userId,
          userType: userType,
          email: email,
          hasProfile: hasProfile,
        );

        if (!mounted) return;
        setState(() => isLoading = false);
        _navigateByUserType(userType, userId, hasProfile, email);
      } else {
        setState(() => isLoading = false);
        showMessage('البريد أو كلمة المرور غير صحيح', false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage('تعذّر الاتصال بالخادم', false);
    }
  }

  Future<void> _handleGoogleLogin(String idToken) async {
    setState(() => isLoading = true);

    final result = await ApiService.googleLogin(
      idToken: idToken,
      userType: widget.userType,
      mode: 'login',
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (result.success) {
      final data = result.data!;
      final int userId = data['userId'] ?? 0;
      final String userType = data['userType'] ?? widget.userType;
      final String email = data['email'] ?? '';

      final bool hasProfile = userType == 'Programmer'
          ? (data['hasProgrammerProfile'] ?? false)
          : (data['hasProfile'] ?? false);

      await SessionManager.saveUser(
        userId: userId,
        userType: userType,
        email: email,
        hasProfile: hasProfile,
      );

      if (!mounted) return;
      _navigateByUserType(userType, userId, hasProfile, email);
    } else {
      showMessage(result.message, false);
    }
  }

  void _navigateByUserType(
    String userType,
    int userId,
    bool hasProfile,
    String email,
  ) {
    if (userType == 'Customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerHomePage(
            userId: userId,
            authorName: email,
            authorType: 'Customer',
          ),
        ),
      );
    } else if (userType == 'Programmer') {
      if (!hasProfile) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProgrammerProfileSetupPage(userId: userId),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProgrammerDashboardPage(userId: userId),
          ),
        );
      }
    } else if (userType == 'Admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardPage(userId: userId),
        ),
      );
    }
  }

  void showMessage(String message, bool success) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(
          userType: widget.userType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -180,
            right: -140,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(isDark ? 0.18 : 0.28),
                    accentColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: -120,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(isDark ? 0.10 : 0.16),
                    accentColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -160,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(isDark ? 0.14 : 0.20),
                    accentColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(isDark ? 0.10 : 0.14),
                    accentColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1100;
                final isTablet = constraints.maxWidth > 700 &&
                    constraints.maxWidth <= 1100;

                final topBarPad = EdgeInsets.fromLTRB(
                  isDesktop ? 40 : 12,
                  isDesktop ? 24 : 8,
                  isDesktop ? 40 : 12,
                  0,
                );

                final contentHPad = isDesktop ? 40.0 : 26.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      children: [
                        Padding(
                          padding: topBarPad,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
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
                                      borderRadius:
                                          BorderRadius.circular(14),
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
                              ThemeToggle(
                                themeManager: themeManager,
                                compact: true,
                              ),
                            ],
                          ),
                        ),

                        // ✅ التعديل هنا: شلنا شريط التمرير من الويب
                        Expanded(
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context)
                                .copyWith(scrollbars: false),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: contentHPad,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 12),
                                  FadeTransition(
                                    opacity: _cardFade,
                                    child: SlideTransition(
                                      position: _cardSlide,
                                      child: Column(
                                        children: [
                                          Center(
                                            child: Container(
                                              width: isDesktop ? 140 : 120,
                                              height: isDesktop ? 140 : 120,
                                              padding: EdgeInsets.all(
                                                isDesktop ? 24 : 20,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  isDesktop ? 40 : 34,
                                                ),
                                                border: Border.all(
                                                  color: isDark
                                                      ? accentColor
                                                          .withOpacity(0.4)
                                                      : accentSoft,
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: accentColor
                                                        .withOpacity(0.35),
                                                    blurRadius: 45,
                                                    spreadRadius: -5,
                                                    offset:
                                                        const Offset(0, 20),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(
                                                      isDark ? 0.5 : 0.05,
                                                    ),
                                                    blurRadius: 14,
                                                    offset:
                                                        const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Image.asset(
                                                'assets/images/devlink_logo.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: isDesktop ? 38 : 30,
                                          ),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      accentColor,
                                                      accentDark,
                                                    ],
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  roleIcon,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${widget.userType} Login',
                                                style: TextStyle(
                                                  fontSize:
                                                      isDesktop ? 32 : 28,
                                                  fontWeight: FontWeight.w900,
                                                  color: textPrimary,
                                                  letterSpacing: -0.6,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            roleSubtitleAr,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize:
                                                  isDesktop ? 16 : 15,
                                              color: isDark
                                                  ? accentColor
                                                  : accentDark
                                                      .withOpacity(0.85),
                                              height: 1.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Text(
                                              roleSubtitleEn,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize:
                                                    isDesktop ? 13.5 : 12.5,
                                                color: textMuted,
                                                height: 1.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: isDesktop ? 42 : 34,
                                          ),

                                          Container(
                                            padding: EdgeInsets.all(
                                              isDesktop ? 28 : 22,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                              border: Border.all(
                                                color: borderColor,
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isDark
                                                      ? Colors.black
                                                          .withOpacity(0.3)
                                                      : const Color(
                                                              0xFF0F172A)
                                                          .withOpacity(0.07),
                                                  blurRadius: 35,
                                                  spreadRadius: -5,
                                                  offset:
                                                      const Offset(0, 14),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildLabel(
                                                  'Email Address',
                                                  isDark,
                                                ),
                                                const SizedBox(height: 10),
                                                _buildTextField(
                                                  controller:
                                                      emailController,
                                                  focusNode: emailFocus,
                                                  hint: emailHint,
                                                  icon: Icons
                                                      .mail_outline_rounded,
                                                  keyboardType:
                                                      TextInputType
                                                          .emailAddress,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  isDark: isDark,
                                                  onSubmitted: (_) =>
                                                      passwordFocus
                                                          .requestFocus(),
                                                ),
                                                const SizedBox(height: 20),
                                                _buildLabel(
                                                  'Password',
                                                  isDark,
                                                ),
                                                const SizedBox(height: 10),
                                                _buildTextField(
                                                  controller:
                                                      passwordController,
                                                  focusNode: passwordFocus,
                                                  hint:
                                                      'Enter your password',
                                                  icon: Icons
                                                      .lock_outline_rounded,
                                                  obscure: hidePassword,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  isDark: isDark,
                                                  onSubmitted: (_) {
                                                    if (!isLoading) login();
                                                  },
                                                  suffix: IconButton(
                                                    splashRadius: 20,
                                                    onPressed: () {
                                                      setState(
                                                        () =>
                                                            hidePassword =
                                                                !hidePassword,
                                                      );
                                                    },
                                                    icon: Icon(
                                                      hidePassword
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      color: textMuted,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: TextButton(
                                                    onPressed:
                                                        _goToForgotPassword,
                                                    style:
                                                        TextButton.styleFrom(
                                                      padding:
                                                          EdgeInsets.zero,
                                                      minimumSize:
                                                          const Size(0, 0),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    child: Text(
                                                      'Forgot Password?',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: accentColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 18),

                                                SizedBox(
                                                  width: double.infinity,
                                                  height:
                                                      isDesktop ? 62 : 60,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(18),
                                                      gradient:
                                                          LinearGradient(
                                                        colors: [
                                                          accentColor,
                                                          accentDark,
                                                        ],
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: accentColor
                                                              .withOpacity(
                                                                  0.45),
                                                          blurRadius: 24,
                                                          offset:
                                                              const Offset(
                                                                  0,
                                                                  12),
                                                        ),
                                                      ],
                                                    ),
                                                    child: ElevatedButton(
                                                      onPressed: isLoading
                                                          ? null
                                                          : login,
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors
                                                                .transparent,
                                                        foregroundColor:
                                                            Colors.white,
                                                        shadowColor:
                                                            Colors
                                                                .transparent,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      18),
                                                        ),
                                                      ),
                                                      child: isLoading
                                                          ? const SizedBox(
                                                              width: 24,
                                                              height: 24,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2.5,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            )
                                                          : Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  'LOGIN',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        isDesktop
                                                                            ? 16
                                                                            : 15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                    letterSpacing:
                                                                        1.8,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 10),
                                                                const Icon(
                                                                  Icons
                                                                      .arrow_forward_rounded,
                                                                  size: 20,
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                  ),
                                                ),

                                                if (widget.userType !=
                                                        'Admin' &&
                                                    !kIsWeb) ...[
                                                  const SizedBox(
                                                      height: 18),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Divider(
                                                          color:
                                                              borderColor,
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
                                                                FontWeight
                                                                    .w800,
                                                            color: textMuted,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Divider(
                                                          color:
                                                              borderColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                      height: 14),
                                                  GoogleSignInButton(
                                                    accentColor: accentColor,
                                                    onIdToken:
                                                        _handleGoogleLogin,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          if (widget.userType ==
                                                  'Customer' ||
                                              widget.userType ==
                                                  'Programmer') ...[
                                            const SizedBox(height: 22),
                                            Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal: 18,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cardColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                  border: Border.all(
                                                    color: borderColor,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "Don't have an account? ",
                                                      style: TextStyle(
                                                        color:
                                                            textSecondary,
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight
                                                                .w500,
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                const SignUpPage(),
                                                          ),
                                                        );
                                                      },
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize
                                                                .min,
                                                        children: [
                                                          Text(
                                                            'Sign Up',
                                                            style: TextStyle(
                                                              color:
                                                                  accentColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize:
                                                                  12.5,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: 14,
                                                            color:
                                                                accentColor,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          SizedBox(
                                            height: isDesktop ? 40 : 30,
                                          ),
                                        ],
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: isDark
            ? const Color(0xFFCBD5E1)
            : const Color(0xFF334155),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      cursorColor: accentColor,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Icon(
            icon,
            color: isDark ? accentColor : accentDark,
            size: 20,
          ),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
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
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
    );
  }
}