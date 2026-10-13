import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';

class AdminAddAdminPage extends StatefulWidget {
  const AdminAddAdminPage({super.key});

  @override
  State<AdminAddAdminPage> createState() => _AdminAddAdminPageState();
}

class _AdminAddAdminPageState extends State<AdminAddAdminPage>
    with TickerProviderStateMixin {
  final Color primary = const Color(0xFF8B5CF6);
  final Color primaryDark = const Color(0xFF6D28D9);
  final Color accentAmber = const Color(0xFFF59E0B);

  static const double maxWidth = 1200;
  static const double formMaxWidth = 700;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  int _passwordStrength = 0;

  late AnimationController _entranceController;
  late Animation<double> _fade;
  late Animation<Offset> _slideHeader;
  late Animation<Offset> _slideForm;
  late Animation<Offset> _slideButton;
  late Animation<Offset> _slideTips;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideHeader = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _slideForm = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _slideButton = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _slideTips = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ============================================================
  // PASSWORD STRENGTH
  // ============================================================
  void _checkPasswordStrength(String value) {
    int strength = 0;
    if (value.length >= 6) strength++;
    if (value.length >= 10) strength++;
    if (value.contains(RegExp(r'[A-Z]'))) strength++;
    if (value.contains(RegExp(r'[0-9]'))) strength++;
    if (value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength++;

    setState(() => _passwordStrength = strength);
  }

  Color _strengthColor() {
    if (_passwordStrength <= 2) return const Color(0xFFEF4444);
    if (_passwordStrength <= 3) return accentAmber;
    return const Color(0xFF10B981);
  }

  String _strengthText() {
    if (_passwordStrength == 0) return '';
    if (_passwordStrength <= 2) return 'Weak';
    if (_passwordStrength <= 3) return 'Medium';
    return 'Strong';
  }

  String _getStrengthHint() {
    if (_passwordStrength <= 2) {
      return 'Add uppercase, numbers, and symbols';
    }
    if (_passwordStrength <= 3) {
      return 'Almost there — add more complexity';
    }
    return 'Your password is strong 💪';
  }

  // ============================================================
  // SAVE
  // ============================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final result = await ApiService.createAdmin(
      email: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showSuccessDialog();
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
        : Colors.grey.shade600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF10B981).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Admin Created!',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The new admin account is ready to use.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [primary, primaryDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'DONE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
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
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF4C1D95);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final iconColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF1E293B);

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
                        Color(0xFF2E1065),
                      ]
                    : const [
                        Color(0xFFF5F3FF),
                        Color(0xFFEDE9FE),
                        Color(0xFFEEF2FF),
                      ],
              ),
            ),
          ),

          // ===== Glow Circles =====
          Positioned(
            top: -150,
            right: -150,
            child: _glow(
              320,
              primary.withOpacity(isDark ? 0.12 : 0.18),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: _glow(
              340,
              primaryDark.withOpacity(isDark ? 0.08 : 0.12),
            ),
          ),

          // ===== Content =====
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1100;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 40 : 20,
                        vertical: isDesktop ? 24 : 12,
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== App Bar =====
                            SlideTransition(
                              position: _slideHeader,
                              child: _buildAppBar(
                                isDark,
                                cardColor,
                                textPrimary,
                                textSecondary,
                                borderColor,
                                iconColor,
                              ),
                            ),
                            SizedBox(height: isDesktop ? 32 : 24),

                            // ===== Desktop: 2 Columns =====
                            if (isDesktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left: Form + Button
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        SlideTransition(
                                          position: _slideForm,
                                          child: _buildForm(
                                            isDark,
                                            cardColor,
                                            textPrimary,
                                            textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SlideTransition(
                                          position: _slideButton,
                                          child: _buildSaveButton(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right: Tips
                                  Expanded(
                                    flex: 2,
                                    child: SlideTransition(
                                      position: _slideTips,
                                      child: _buildTipsSection(
                                        isDark,
                                        cardColor,
                                        textPrimary,
                                        textSecondary,
                                        borderColor,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              // ===== Mobile: Vertical =====
                              SlideTransition(
                                position: _slideForm,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: formMaxWidth,
                                  ),
                                  child: _buildForm(
                                    isDark,
                                    cardColor,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SlideTransition(
                                position: _slideButton,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: formMaxWidth,
                                  ),
                                  child: _buildSaveButton(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SlideTransition(
                                position: _slideTips,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: formMaxWidth,
                                  ),
                                  child: _buildTipsSection(
                                    isDark,
                                    cardColor,
                                    textPrimary,
                                    textSecondary,
                                    borderColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  // ============================================================
  // TIPS SECTION
  // ============================================================
  Widget _buildTipsSection(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final tips = [
      {
        'icon': Icons.security_rounded,
        'title': 'Strong Password',
        'desc': 'Use 10+ characters with mix of letters, numbers & symbols',
        'color': const Color(0xFFEF4444),
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Full Access',
        'desc': 'Admins can manage users, posts, and verify programmers',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.share_rounded,
        'title': 'Share Carefully',
        'desc': 'Never share admin credentials with untrusted people',
        'color': const Color(0xFF3B82F6),
      },
      {
        'icon': Icons.history_rounded,
        'title': 'Track Activity',
        'desc': 'All admin actions are logged for security purposes',
        'color': const Color(0xFFF59E0B),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
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
                : primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tips_and_updates_rounded,
                  color: primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Security Tips',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...tips.asMap().entries.map((entry) {
            final index = entry.key;
            final tip = entry.value;
            final isLast = index == tips.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (tip['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tip['icon'] as IconData,
                      color: tip['color'] as Color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['title'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tip['desc'] as String,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  Widget _buildAppBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color iconColor,
  ) {
    return Row(
      children: [
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          elevation: isDark ? 0 : 2,
          shadowColor: primary.withOpacity(0.2),
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
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Add New Admin',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Create a new admin account',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ThemeToggle(
          themeManager: themeManager,
          compact: true,
        ),
      ],
    );
  }

  // ============================================================
  // FORM
  // ============================================================
  Widget _buildForm(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withOpacity(0.15),
                      primaryDark.withOpacity(0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: primary,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Admin Account',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 13,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Full system access',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // Email
            _buildLabel('Email Address', isDark),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              cursorColor: primary,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
              decoration: _inputDecoration(
                hint: 'admin@example.com',
                icon: Icons.mail_outline_rounded,
                isDark: isDark,
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
            const SizedBox(height: 20),

            // Password
            _buildLabel('Password', isDark),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePass,
              cursorColor: primary,
              onChanged: _checkPasswordStrength,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
              decoration: _inputDecoration(
                hint: 'At least 6 characters',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
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

            // Password Strength
            if (_passwordStrength > 0) ...[
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: List.generate(4, (index) {
                              final isActive = index < _passwordStrength;
                              return Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(
                                    right: index < 3 ? 4 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _strengthColor()
                                        : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _strengthText(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _strengthColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getStrengthHint(),
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Confirm Password
            _buildLabel('Confirm Password', isDark),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              cursorColor: primary,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
              decoration: _inputDecoration(
                hint: 'Re-enter password',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirm = !_obscureConfirm,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm the password';
                }
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [primary, primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.40),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
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
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'CREATE ADMIN ACCOUNT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _buildLabel(String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isDark
                ? const Color(0xFFCBD5E1)
                : const Color(0xFF334155),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    Widget? suffix,
  }) {
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

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
          color: isDark ? primary : primaryDark,
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
        borderSide: BorderSide(
          color: primary,
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
    );
  }

  Widget _glow(double size, Color color) {
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