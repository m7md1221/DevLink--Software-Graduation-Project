import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field_v2/intl_phone_field.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import 'dashboard_placeholder_page.dart';

class CustomerProfileSetupPage extends StatefulWidget {
  final int userId;

  const CustomerProfileSetupPage({
    super.key,
    required this.userId,
  });

  @override
  State<CustomerProfileSetupPage> createState() =>
      _CustomerProfileSetupPageState();
}

class _CustomerProfileSetupPageState
    extends State<CustomerProfileSetupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  String _fullPhone = '';

  File? _imageFile;
  Uint8List? _webImageBytes;

  bool _isLoading = false;
  bool _isPickingImage = false;

  final Color accentColor = const Color(0xFF10B981);
  final Color accentDark = const Color(0xFF047857);

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

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
    _nicknameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _webImageBytes = bytes;
          _imageFile = null;
          _isPickingImage = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _imageFile = File(picked.path);
          _webImageBytes = null;
          _isPickingImage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      _showSnack('تعذّر اختيار الصورة: $e', isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _webImageBytes = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final phoneToSend = _fullPhone.isNotEmpty
        ? _fullPhone
        : _phoneController.text.trim();

    final result = await ApiService.createCustomerProfile(
      userId: widget.userId,
      nickname: _nicknameController.text.trim(),
      phoneNumber: phoneToSend,
      country: _countryController.text.trim(),
      city: _cityController.text.trim(),
      imageFile: _imageFile,
      imageBytes: _webImageBytes,
      imageName: 'profile.jpg',
    );

    if (!mounted) return;

    if (result.success) {
      await SessionManager.updateHasProfile(true);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessDialog();
    } else {
      setState(() => _isLoading = false);
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

    // ✅ تحديد حجم مناسب للديسكتوب
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;
    final dialogMaxWidth = isDesktop ? 480.0 : 400.0;

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
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: accentColor,
                      size: isDesktop ? 48 : 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Profile Completed!',
                    style: TextStyle(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your DevLink profile is ready. Welcome aboard!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: isDesktop ? 14 : 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: isDesktop ? 56 : 50,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [accentColor, accentDark],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DashboardPlaceholderPage(
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: isDesktop ? 15 : 14,
                            letterSpacing: 0.5,
                          ),
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
            isError ? const Color(0xFFEF4444) : accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
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
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -180,
            right: -140,
            child: _glowCircle(
              380,
              accentColor.withOpacity(isDark ? 0.15 : 0.28),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -160,
            child: _glowCircle(
              420,
              accentColor.withOpacity(isDark ? 0.10 : 0.20),
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

                final hPad = isDesktop ? 40.0 : 24.0;
                final vTop = isDesktop ? 32.0 : 12.0;
                final vBottom = isDesktop ? 40.0 : 24.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        hPad,
                        vTop,
                        hPad,
                        vBottom,
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
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
                              SizedBox(height: isDesktop ? 36 : 26),

                              // ===== Icon =====
                              Center(
                                child: Container(
                                  padding: EdgeInsets.all(
                                    isDesktop ? 22 : 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        accentColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: isDesktop ? 52 : 42,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 28 : 20),

                              // ===== Title =====
                              Center(
                                child: Text(
                                  'Complete Your Profile',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 32 : 26,
                                    fontWeight: FontWeight.w900,
                                    color: textPrimary,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'Tell us a bit about yourself to personalize your DevLink experience',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize:
                                          isDesktop ? 14.5 : 13.5,
                                      color: textSecondary,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 40 : 30),

                              // ===== Form Card =====
                              Container(
                                padding: EdgeInsets.all(
                                  isDesktop ? 32 : 22,
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black
                                              .withOpacity(0.3)
                                          : const Color(0xFF0F172A)
                                              .withOpacity(0.06),
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
                                      Center(
                                        child: _buildImagePicker(
                                          isDark,
                                          isDesktop: isDesktop,
                                        ),
                                      ),
                                      SizedBox(
                                        height: isDesktop ? 32 : 28,
                                      ),

                                      // ===== Nickname =====
                                      _buildLabel('Nickname', isDark),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _nicknameController,
                                        cursorColor: accentColor,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        decoration: _inputDecoration(
                                          hint: 'e.g. eyas_dev',
                                          icon: Icons.badge_outlined,
                                          isDark: isDark,
                                          isDesktop: isDesktop,
                                        ),
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().isEmpty) {
                                            return 'Nickname is required';
                                          }
                                          if (v.trim().length < 3) {
                                            return 'At least 3 characters';
                                          }
                                          if (v.trim().length > 50) {
                                            return 'Max 50 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // ===== Phone =====
                                      _buildLabel(
                                        'Phone Number',
                                        isDark,
                                      ),
                                      const SizedBox(height: 10),
                                      IntlPhoneField(
                                        controller: _phoneController,
                                        initialCountryCode: 'PS',
                                        disableLengthCheck: false,
                                        showDropdownIcon: true,
                                        dropdownTextStyle: TextStyle(
                                          fontSize:
                                              isDesktop ? 16 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        style: TextStyle(
                                          fontSize:
                                              isDesktop ? 16 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '599123456',
                                          hintStyle: TextStyle(
                                            color: textSecondary,
                                            fontSize: 14,
                                          ),
                                          counterText: '',
                                          filled: true,
                                          fillColor: inputFill,
                                          contentPadding:
                                              EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical:
                                                isDesktop ? 22 : 18,
                                          ),
                                          enabledBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    14),
                                            borderSide: BorderSide(
                                              color: borderColor,
                                              width: 1.4,
                                            ),
                                          ),
                                          focusedBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    14),
                                            borderSide: BorderSide(
                                              color: accentColor,
                                              width: 2,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    14),
                                            borderSide:
                                                const BorderSide(
                                              color: Color(0xFFEF4444),
                                              width: 1.4,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    14),
                                            borderSide:
                                                const BorderSide(
                                              color: Color(0xFFEF4444),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (phone) {
                                          _fullPhone =
                                              phone.completeNumber;
                                        },
                                        validator: (phone) {
                                          if (phone == null ||
                                              phone.number
                                                  .trim()
                                                  .isEmpty) {
                                            return 'Phone is required';
                                          }
                                          if (phone.number
                                                  .trim()
                                                  .length <
                                              7) {
                                            return 'Enter a valid phone number';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // ===== Country =====
                                      _buildLabel('Country', isDark),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _countryController,
                                        cursorColor: accentColor,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        decoration: _inputDecoration(
                                          hint: 'e.g. Palestine',
                                          icon:
                                              Icons.public_outlined,
                                          isDark: isDark,
                                          isDesktop: isDesktop,
                                        ),
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().isEmpty) {
                                            return 'Country is required';
                                          }
                                          if (v.trim().length < 2) {
                                            return 'At least 2 characters';
                                          }
                                          if (v.trim().length > 50) {
                                            return 'Max 50 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // ===== City =====
                                      _buildLabel(
                                        'City / Village',
                                        isDark,
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _cityController,
                                        cursorColor: accentColor,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        decoration: _inputDecoration(
                                          hint: 'e.g. Nablus, Safleet',
                                          icon: Icons
                                              .location_city_outlined,
                                          isDark: isDark,
                                          isDesktop: isDesktop,
                                        ),
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().isEmpty) {
                                            return 'City or village is required';
                                          }
                                          if (v.trim().length < 2) {
                                            return 'At least 2 characters';
                                          }
                                          if (v.trim().length > 50) {
                                            return 'Max 50 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(
                                        height: isDesktop ? 36 : 30,
                                      ),

                                      // ===== Save Button =====
                                      SizedBox(
                                        width: double.infinity,
                                        height: isDesktop ? 62 : 58,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16),
                                            gradient: LinearGradient(
                                              colors: [
                                                accentColor,
                                                accentDark,
                                              ],
                                              begin: Alignment.topLeft,
                                              end:
                                                  Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accentColor
                                                    .withOpacity(0.40),
                                                blurRadius: 22,
                                                offset:
                                                    const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _save,
                                            style: ElevatedButton
                                                .styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor:
                                                  Colors.white,
                                              shadowColor:
                                                  Colors.transparent,
                                              disabledBackgroundColor:
                                                  Colors.transparent,
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(16),
                                              ),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color:
                                                          Colors.white,
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(
                                                          width: 10),
                                                      Text(
                                                        'SAVE & CONTINUE',
                                                        style:
                                                            TextStyle(
                                                          fontSize:
                                                              isDesktop
                                                                  ? 15
                                                                  : 14,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w900,
                                                          letterSpacing:
                                                              1.4,
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
                              SizedBox(height: isDesktop ? 30 : 22),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Your data is safe with us',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize:
                                          isDesktop ? 13.5 : 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildImagePicker(bool isDark, {required bool isDesktop}) {
    final hasImage = _imageFile != null || _webImageBytes != null;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade600;
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : Colors.grey.shade500;

    // ✅ حجم الصورة حسب الجهاز
    final imageSize = isDesktop ? 150.0 : 120.0;
    final iconSize = isDesktop ? 62.0 : 50.0;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: hasImage
                        ? accentColor
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(
                        hasImage ? 0.30 : 0.10,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _buildImageContent(
                    isDark,
                    imageSize: imageSize,
                    iconSize: iconSize,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(isDesktop ? 10 : 8),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isPickingImage
                      ? SizedBox(
                          width: isDesktop ? 16 : 14,
                          height: isDesktop ? 16 : 14,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: isDesktop ? 18 : 16,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          hasImage ? 'Tap to change photo' : 'Tap to add a profile photo',
          style: TextStyle(
            fontSize: isDesktop ? 13.5 : 12.5,
            color: hasImage ? accentColor : textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optional • Max 2MB • JPG/PNG',
          style: TextStyle(
            fontSize: isDesktop ? 12 : 11,
            color: textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (hasImage)
          TextButton.icon(
            onPressed: _removeImage,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: Color(0xFFEF4444),
            ),
            label: const Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent(
    bool isDark, {
    required double imageSize,
    required double iconSize,
  }) {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(
        _webImageBytes!,
        fit: BoxFit.cover,
        width: imageSize,
        height: imageSize,
      );
    }
    if (!kIsWeb && _imageFile != null) {
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
        width: imageSize,
        height: imageSize,
      );
    }
    return Icon(
      Icons.person_rounded,
      size: iconSize,
      color: isDark
          ? const Color(0xFF64748B)
          : Colors.grey.shade400,
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    required bool isDesktop,
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
          color: isDark ? accentColor : accentDark,
          size: 20,
        ),
      ),
      filled: true,
      fillColor: inputFill,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDesktop ? 22 : 18,
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
          color: accentColor,
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