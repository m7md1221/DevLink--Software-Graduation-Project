import 'dart:io';
import 'dart:typed_data';
import 'package:devlink/main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/session_manager.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import '../Common/welcome_page.dart';

class ProgrammerDashboardPage extends StatefulWidget {
  final int userId;

  const ProgrammerDashboardPage({
    super.key,
    required this.userId,
  });

  @override
  State<ProgrammerDashboardPage> createState() =>
      _ProgrammerDashboardPageState();
}

class _ProgrammerDashboardPageState
    extends State<ProgrammerDashboardPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  final Color primary = const Color(0xFF8B5CF6);
  final Color primaryDark = const Color(0xFF6D28D9);
  final Color primaryDeep = const Color(0xFF4C1D95);

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // ===== File picking =====
  File? _cvFile;
  Uint8List? _cvBytes;
  String? _cvName;

  File? _certFile;
  Uint8List? _certBytes;
  String? _certName;

  bool _isPickingCv = false;
  bool _isPickingCert = false;
  bool _isUploadingCv = false;
  bool _isUploadingCert = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result =
        await ApiService.getProgrammerProfile(widget.userId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) _profile = result.data;
    });
  }

  Future<void> _logout() async {
    await SessionManager.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  Future<void> _openUrl(String url, String label) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        _showSnack('Could not open $label', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error opening $label: $e', isError: true);
      }
    }
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
        backgroundColor:
            isError ? const Color(0xFFEF4444) : primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================================
  // CV MANAGEMENT
  // ============================================================
  Future<void> _pickCv() async {
    if (_isPickingCv || _isUploadingCv) return;
    setState(() => _isPickingCv = true);

    try {
      const XTypeGroup pdfGroup = XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [pdfGroup]);

      if (file == null) {
        if (mounted) setState(() => _isPickingCv = false);
        return;
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _cvBytes = bytes;
          _cvFile = null;
          _cvName = file.name;
          _isPickingCv = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _cvFile = File(file.path);
          _cvBytes = null;
          _cvName = file.name;
          _isPickingCv = false;
        });
      }

      await _uploadCv();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPickingCv = false);
      _showSnack('Could not pick CV: $e', isError: true);
    }
  }

  Future<void> _uploadCv() async {
    setState(() => _isUploadingCv = true);

    final result = await ApiService.uploadProgrammerCV(
      userId: widget.userId,
      cvFile: _cvFile,
      cvBytes: _cvBytes,
      cvName: _cvName,
    );

    if (!mounted) return;
    setState(() => _isUploadingCv = false);

    if (result.success) {
      _showSnack('CV uploaded successfully', isError: false);
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _deleteCv() async {
    final confirmed = await _confirmDelete(
      title: 'Delete CV?',
      message: 'Are you sure you want to delete your CV?',
    );

    if (confirmed != true) return;

    setState(() => _isUploadingCv = true);

    final result = await ApiService.deleteProgrammerCV(widget.userId);

    if (!mounted) return;
    setState(() => _isUploadingCv = false);

    if (result.success) {
      _showSnack('CV deleted successfully', isError: false);
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  // ============================================================
  // CERTIFICATE MANAGEMENT
  // ============================================================
  Future<void> _pickCertificate() async {
    if (_isPickingCert || _isUploadingCert) return;
    setState(() => _isPickingCert = true);

    try {
      const XTypeGroup certGroup = XTypeGroup(
        label: 'Certificate',
        extensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [certGroup]);

      if (file == null) {
        if (mounted) setState(() => _isPickingCert = false);
        return;
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _certBytes = bytes;
          _certFile = null;
          _certName = file.name;
          _isPickingCert = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _certFile = File(file.path);
          _certBytes = null;
          _certName = file.name;
          _isPickingCert = false;
        });
      }

      await _uploadCertificate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPickingCert = false);
      _showSnack('Could not pick certificate: $e', isError: true);
    }
  }

  Future<void> _uploadCertificate() async {
    setState(() => _isUploadingCert = true);

    final result = await ApiService.uploadProgrammerCertificate(
      userId: widget.userId,
      certFile: _certFile,
      certBytes: _certBytes,
      certName: _certName,
    );

    if (!mounted) return;
    setState(() => _isUploadingCert = false);

    if (result.success) {
      _showSnack(result.message, isError: false);
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _deleteCertificate() async {
    final confirmed = await _confirmDelete(
      title: 'Delete Certificate?',
      message:
          'Are you sure you want to delete your certificate?\n\nYour verification will be removed.',
    );

    if (confirmed != true) return;

    setState(() => _isUploadingCert = true);

    final result =
        await ApiService.deleteProgrammerCertificate(widget.userId);

    if (!mounted) return;
    setState(() => _isUploadingCert = false);

    if (result.success) {
      _showSnack('Certificate deleted successfully', isError: false);
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);

    // ✅ تحديد حجم مناسب للديسكتوب
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;
    final dialogMaxWidth = isDesktop ? 480.0 : 400.0;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 28 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: isDesktop ? 14.5 : 14,
                    height: 1.5,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF5F3FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E1B4B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade700;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : primary.withOpacity(0.15);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _glowCircle(
              360,
              primary.withOpacity(isDark ? 0.18 : 0.35),
            ),
          ),
          Positioned(
            top: 200,
            left: -140,
            child: _glowCircle(
              300,
              primary.withOpacity(isDark ? 0.08 : 0.15),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -100,
            child: _glowCircle(
              380,
              primaryDeep.withOpacity(isDark ? 0.12 : 0.22),
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

                final hPad = isDesktop ? 40.0 : 20.0;
                final vTop = isDesktop ? 32.0 : 12.0;
                final vBottom = isDesktop ? 60.0 : 30.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            hPad,
                            vTop,
                            hPad,
                            vBottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(
                                isDark,
                                cardColor,
                                textPrimary,
                                textSecondary,
                                borderColor,
                                isDesktop: isDesktop,
                              ),
                              SizedBox(height: isDesktop ? 28 : 20),
                              _isLoading
                                  ? _buildLoading(isDark, cardColor)
                                  : _buildHeroCard(
                                      isDesktop: isDesktop,
                                    ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              if (!_isLoading)
                                _buildStatsRow(
                                  isDark,
                                  isDesktop: isDesktop,
                                ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              if (!_isLoading)
                                _buildInfoGrid(
                                  isDark,
                                  isDesktop: isDesktop,
                                ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              if (!_isLoading)
                                _buildDocumentsCard(
                                  isDark,
                                  isDesktop: isDesktop,
                                ),
                              SizedBox(height: isDesktop ? 24 : 18),
                              _buildComingSoon(
                                isDesktop: isDesktop,
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

  // ============================================================
  // TOP BAR — responsive
  // ============================================================
  Widget _buildTopBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor, {
    required bool isDesktop,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 28,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome back 👋',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            ThemeToggle(
              themeManager: themeManager,
              compact: true,
            ),
            const SizedBox(width: 10),
            Material(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              elevation: isDark ? 0 : 2,
              shadowColor: primary.withOpacity(0.2),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // LOADING
  // ============================================================
  Widget _buildLoading(bool isDark, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: CircularProgressIndicator(color: primary),
      ),
    );
  }

  // ============================================================
  // HERO CARD — responsive
  // ============================================================
  Widget _buildHeroCard({required bool isDesktop}) {
    final nickname = _profile?['nickname'] ?? 'User';
    final specialty = _profile?['specialty'] ?? '-';
    final isVerified = _profile?['isVerified'] == true;
    final hasImage = _profile?['hasImage'] == true;

    final avatarSize = isDesktop ? 104.0 : 86.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark, primaryDeep],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.45),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? Image.network(
                              ApiService.getProgrammerImageUrl(
                                  widget.userId),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withOpacity(0.2),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: isDesktop ? 48 : 40,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.white.withOpacity(0.2),
                              child: Icon(
                                Icons.person_rounded,
                                size: isDesktop ? 48 : 40,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  if (isVerified)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(
                          isDesktop ? 6 : 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: isDesktop ? 14 : 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isDesktop ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 26 : 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Programmer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS ROW — responsive
  // ============================================================
  Widget _buildStatsRow(bool isDark, {required bool isDesktop}) {
    final rating = _profile?['rating'] ?? 0;
    final isVerified = _profile?['isVerified'] == true;
    final country = _profile?['country'] ?? '-';

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.star_rounded,
            value: '$rating',
            label: 'Rating',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            isDesktop: isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 14 : 10),
        Expanded(
          child: _statCard(
            icon: Icons.verified_rounded,
            value: isVerified ? 'Yes' : 'No',
            label: 'Verified',
            color: isVerified
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8),
            isDark: isDark,
            isDesktop: isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 14 : 10),
        Expanded(
          child: _statCard(
            icon: Icons.public_rounded,
            value: country.length > 8
                ? '${country.substring(0, 8)}...'
                : country,
            label: 'Country',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            isDesktop: isDesktop,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
    required bool isDesktop,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E1B4B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade600;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 20 : 16,
        horizontal: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.15 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isDesktop ? 22 : 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 15,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isDesktop ? 12 : 11,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO GRID — responsive
  // ============================================================
  Widget _buildInfoGrid(bool isDark, {required bool isDesktop}) {
    final phone = _profile?['phoneNumber'] ?? '-';
    final city = _profile?['city'] ?? '-';
    final university = _profile?['university'] ?? '-';
    final linkedInUrl = _profile?['linkedInUrl'] ?? '';

    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E1B4B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Profile Information',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        _infoCard(
          icon: Icons.phone_rounded,
          label: 'Phone Number',
          value: phone,
          color: const Color(0xFF10B981),
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        SizedBox(height: isDesktop ? 14 : 10),
        _infoCard(
          icon: Icons.location_city_rounded,
          label: 'City / Village',
          value: city,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        SizedBox(height: isDesktop ? 14 : 10),
        _infoCard(
          icon: Icons.school_rounded,
          label: 'University',
          value: university,
          color: const Color(0xFFF59E0B),
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        if (linkedInUrl.isNotEmpty) ...[
          SizedBox(height: isDesktop ? 14 : 10),
          GestureDetector(
            onTap: () => _openUrl(linkedInUrl, 'LinkedIn'),
            child: _infoCard(
              icon: Icons.link_rounded,
              label: 'LinkedIn',
              value: linkedInUrl,
              color: const Color(0xFF0A66C2),
              isDark: isDark,
              isDesktop: isDesktop,
              trailing: const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: Color(0xFF0A66C2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required bool isDesktop,
    Widget? trailing,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E1B4B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : Colors.grey.shade600;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFEDE9FE);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 18 : 14,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 12 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isDesktop ? 22 : 18),
          ),
          SizedBox(width: isDesktop ? 16 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENTS CARD — responsive
  // ============================================================
  Widget _buildDocumentsCard(bool isDark, {required bool isDesktop}) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E1B4B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : primary.withOpacity(0.15);

    final hasCV = _profile?['hasCV'] == true;
    final hasCertificate = _profile?['hasCertificate'] == true;
    final cvName = _profile?['cvName'] ?? '';
    final certName = _profile?['certificateName'] ?? '';
    final isVerified = _profile?['isVerified'] == true;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 18,
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
                padding: EdgeInsets.all(isDesktop ? 10 : 8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: primary,
                  size: isDesktop ? 22 : 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Documents',
                style: TextStyle(
                  fontSize: isDesktop ? 17 : 15,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 20 : 16),

          // CV Section
          _buildDocumentRow(
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.description_rounded,
            title: 'CV',
            fileName: hasCV ? cvName : null,
            hasFile: hasCV,
            isLoading: _isUploadingCv || _isPickingCv,
            onView: hasCV
                ? () => _openUrl(
                      ApiService.getProgrammerCvUrl(widget.userId),
                      'CV',
                    )
                : null,
            onUpload: _pickCv,
            onDelete: hasCV ? _deleteCv : null,
            color: const Color(0xFF3B82F6),
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 14 : 12),

          // Certificate Section
          _buildDocumentRow(
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.verified_rounded,
            title: 'Certificate',
            fileName: hasCertificate ? certName : null,
            hasFile: hasCertificate,
            isLoading: _isUploadingCert || _isPickingCert,
            onView: hasCertificate
                ? () => _openUrl(
                      ApiService.getProgrammerCertificateUrl(
                          widget.userId),
                      'Certificate',
                    )
                : null,
            onUpload: _pickCertificate,
            onDelete: hasCertificate ? _deleteCertificate : null,
            color: const Color(0xFF10B981),
            showVerificationNote: hasCertificate,
            isVerified: isVerified,
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required String title,
    required String? fileName,
    required bool hasFile,
    required bool isLoading,
    required VoidCallback? onView,
    required VoidCallback onUpload,
    required VoidCallback? onDelete,
    required Color color,
    required bool isDesktop,
    bool showVerificationNote = false,
    bool isVerified = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: hasFile
            ? color.withOpacity(isDark ? 0.15 : 0.08)
            : (isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile
              ? color.withOpacity(isDark ? 0.4 : 0.3)
              : (isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: isDesktop ? 22 : 20,
                        height: isDesktop ? 22 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(
                        hasFile
                            ? Icons.check_circle_rounded
                            : icon,
                        color: color,
                        size: isDesktop ? 22 : 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 15 : 14,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFile
                          ? (fileName?.isNotEmpty == true
                              ? fileName!
                              : 'Uploaded')
                          : 'No $title uploaded',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 12.5 : 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFile && onView != null)
                    _docActionButton(
                      icon: Icons.visibility_rounded,
                      color: color,
                      onTap: onView,
                      isDesktop: isDesktop,
                    ),
                  if (hasFile) ...[
                    const SizedBox(width: 6),
                    _docActionButton(
                      icon: Icons.refresh_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: onUpload,
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(width: 6),
                    _docActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: onDelete ?? () {},
                      isDesktop: isDesktop,
                    ),
                  ] else ...[
                    _docActionButton(
                      icon: Icons.upload_rounded,
                      color: color,
                      onTap: onUpload,
                      isDesktop: isDesktop,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (showVerificationNote && hasFile && !isVerified) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B)
                    .withOpacity(isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Waiting for admin verification',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _docActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDesktop,
  }) {
    final size = isDesktop ? 38.0 : 34.0;
    final iconSize = isDesktop ? 19.0 : 17.0;

    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }

  // ============================================================
  // COMING SOON — responsive
  // ============================================================
  Widget _buildComingSoon({required bool isDesktop}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 28 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(0.95),
            primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.40),
            blurRadius: 26,
            spreadRadius: -5,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Icon(
              Icons.rocket_launch_rounded,
              size: isDesktop ? 140 : 120,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 10 : 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: isDesktop ? 22 : 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: isDesktop ? 19 : 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Browse projects, submit proposals, and get hired — all from your dashboard.',
                style: TextStyle(
                  fontSize: isDesktop ? 13.5 : 12.5,
                  color: Colors.white,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
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
}