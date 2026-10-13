import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';

class AdminUserFormPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const AdminUserFormPage({super.key, this.user});

  @override
  State<AdminUserFormPage> createState() => _AdminUserFormPageState();
}

class _AdminUserFormPageState extends State<AdminUserFormPage>
    with SingleTickerProviderStateMixin {
  final Color primary = const Color(0xFF3B82F6);
  final Color primaryDark = const Color(0xFF1D4ED8);

  static const double maxWidth = 1200;
  static const double formMaxWidth = 700;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedType = 'Customer';
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get isEditing => widget.user != null;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slideHeader;
  late Animation<Offset> _slideForm;
  late Animation<Offset> _slideButton;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      _emailController.text = widget.user!['email'] ?? '';
      _selectedType = widget.user!['userType'] ?? 'Customer';
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideHeader = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _slideForm = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _slideButton = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    ApiResult result;

    if (isEditing) {
      result = await ApiService.updateUser(
        id: widget.user!['id'],
        email: _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        userType: _selectedType,
      );
    } else {
      result = await ApiService.createUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: _selectedType,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E3A8A);
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
                        Color(0xFF1E3A8A),
                      ]
                    : const [
                        Color(0xFFEEF2FF),
                        Color(0xFFE0E7FF),
                        Color(0xFFF5F3FF),
                      ],
              ),
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

                            // Desktop: form متمركز بعرض 700
                            if (isDesktop)
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: formMaxWidth,
                                  ),
                                  child: Column(
                                    children: [
                                      SlideTransition(
                                        position: _slideForm,
                                        child: _buildForm(
                                          isDark,
                                          cardColor,
                                          textPrimary,
                                          textSecondary,
                                          borderColor,
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
                              )
                            else ...[
                              SlideTransition(
                                position: _slideForm,
                                child: _buildForm(
                                  isDark,
                                  cardColor,
                                  textPrimary,
                                  textSecondary,
                                  borderColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SlideTransition(
                                position: _slideButton,
                                child: _buildSaveButton(),
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
                    isEditing ? 'Edit User' : 'Add New User',
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
                      isEditing ? Icons.edit_rounded : Icons.add_rounded,
                      size: 14,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isEditing
                    ? 'Update user information'
                    : 'Create a new user account',
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
    Color borderColor,
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
                hint: 'user@example.com',
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

            _buildLabel(
              isEditing
                  ? 'Password (leave empty to keep current)'
                  : 'Password',
              isDark,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: primary,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
              decoration: _inputDecoration(
                hint: isEditing
                    ? 'New password (optional)'
                    : 'At least 6 characters',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ),
              validator: (v) {
                if (isEditing) {
                  if (v != null && v.isNotEmpty && v.length < 6) {
                    return 'At least 6 characters';
                  }
                  return null;
                }
                if (v == null || v.isEmpty) {
                  return 'Password is required';
                }
                if (v.length < 6) {
                  return 'At least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            _buildLabel('User Type', isDark),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _typeCard(
                    'Customer',
                    Icons.person_rounded,
                    const Color(0xFF10B981),
                    isDark,
                    textPrimary,
                    textSecondary,
                    borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _typeCard(
                    'Programmer',
                    Icons.code_rounded,
                    const Color(0xFF8B5CF6),
                    isDark,
                    textPrimary,
                    textSecondary,
                    borderColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeCard(
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final selected = _selectedType == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(isDark ? 0.20 : 0.10)
              : (isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : borderColor,
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
              size: 28,
              color: selected ? color : textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? color : textPrimary,
              ),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isEditing
                          ? Icons.save_rounded
                          : Icons.add_circle_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'SAVE CHANGES' : 'CREATE USER',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
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
}