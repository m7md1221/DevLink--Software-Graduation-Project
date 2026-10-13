import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';

class AdminVerificationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> programmer;

  const AdminVerificationDetailsPage({
    super.key,
    required this.programmer,
  });

  @override
  State<AdminVerificationDetailsPage> createState() =>
      _AdminVerificationDetailsPageState();
}

class _AdminVerificationDetailsPageState
    extends State<AdminVerificationDetailsPage> {
  final Color primary = const Color(0xFF3B82F6);
  final Color accentGreen = const Color(0xFF10B981);
  final Color accentAmber = const Color(0xFFF59E0B);
  final Color accentRed = const Color(0xFFEF4444);

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  bool _isLoading = false;
  late bool _isVerified;

  int get userId => widget.programmer['userId'] ?? 0;

  @override
  void initState() {
    super.initState();
    _isVerified = widget.programmer['isVerified'] == true;
  }

  Future<void> _openUrl(String url, String label) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        _showSnack('Could not open $label', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _toggleVerification() async {
    setState(() => _isLoading = true);

    final result = _isVerified
        ? await ApiService.unverifyProgrammer(userId)
        : await ApiService.verifyProgrammer(userId);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _isVerified = !_isVerified);
      _showSnack(result.message, isError: false);
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? accentRed : accentGreen,
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

    final nickname = widget.programmer['nickname'] ?? 'User';
    final email = widget.programmer['email'] ?? '';
    final specialty = widget.programmer['specialty'] ?? '-';
    final university = widget.programmer['university'] ?? '-';
    final country = widget.programmer['country'] ?? '-';
    final city = widget.programmer['city'] ?? '-';
    final phone = widget.programmer['phoneNumber'] ?? '-';
    final linkedInUrl = widget.programmer['linkedInUrl'] ?? '';
    final rating = widget.programmer['rating'] ?? 0;
    final hasImage = widget.programmer['hasImage'] == true;
    final hasCV = widget.programmer['hasCV'] == true;
    final hasCertificate = widget.programmer['hasCertificate'] == true;

    final statusColor = _isVerified ? accentGreen : accentAmber;

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
                    ? (_isVerified
                        ? const [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                            Color(0xFF064E3B),
                          ]
                        : const [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                            Color(0xFF78350F),
                          ])
                    : (_isVerified
                        ? const [
                            Color(0xFFECFDF5),
                            Color(0xFFD1FAE5),
                            Color(0xFFEFF6FF),
                          ]
                        : const [
                            Color(0xFFFFFBEB),
                            Color(0xFFFEF3C7),
                            Color(0xFFEFF6FF),
                          ]),
              ),
            ),
          ),

          Positioned(
            top: -100,
            right: -100,
            child: _glow(
              280,
              statusColor.withOpacity(isDark ? 0.15 : 0.25),
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
                final vTop = isDesktop ? 24.0 : 12.0;
                final vBottom = isDesktop ? 60.0 : 30.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, vTop, hPad, vBottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAppBar(
                            isDark,
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                            iconColor,
                            isDesktop: isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 28 : 20),
                          _buildProfileHeader(
                            nickname,
                            email,
                            hasImage,
                            statusColor,
                            isDark,
                            cardColor,
                            textPrimary,
                            textSecondary,
                            isDesktop: isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 22 : 18),
                          _buildInfoCard(
                            phone: phone,
                            country: country,
                            city: city,
                            specialty: specialty,
                            university: university,
                            rating: rating,
                            linkedInUrl: linkedInUrl,
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDesktop: isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 22 : 18),
                          _buildDocumentsCard(
                            hasCV,
                            hasCertificate,
                            isDark,
                            cardColor,
                            textPrimary,
                            textSecondary,
                            isDesktop: isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 28 : 24),
                          _buildActionButton(
                            isDark,
                            cardColor,
                            isDesktop: isDesktop,
                          ),
                        ],
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
  // APP BAR (مع ThemeToggle) — responsive
  // ============================================================
  Widget _buildAppBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color iconColor, {
    required bool isDesktop,
  }) {
    return Row(
      children: [
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          elevation: isDark ? 0 : 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(
              context,
              _isVerified != (widget.programmer['isVerified'] == true),
            ),
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
              Text(
                'Verification',
                style: TextStyle(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review applicant details',
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12,
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
  // PROFILE HEADER — responsive
  // ============================================================
  Widget _buildProfileHeader(
    String nickname,
    String email,
    bool hasImage,
    Color statusColor,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
  }) {
    final avatarSize = isDesktop ? 92.0 : 78.0;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : statusColor.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: hasImage
                  ? Image.network(
                      ApiService.getProgrammerImageUrl(userId),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: statusColor.withOpacity(0.12),
                        child: Icon(
                          Icons.person_rounded,
                          color: statusColor,
                          size: isDesktop ? 42 : 36,
                        ),
                      ),
                    )
                  : Container(
                      color: statusColor.withOpacity(0.12),
                      child: Icon(
                        Icons.person_rounded,
                        color: statusColor,
                        size: isDesktop ? 42 : 36,
                      ),
                    ),
            ),
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
                    fontSize: isDesktop ? 22 : 19,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 13.5 : 12.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isVerified
                            ? Icons.verified_rounded
                            : Icons.pending_rounded,
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isVerified ? 'Verified' : 'Pending Review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
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
    );
  }

  // ============================================================
  // INFO CARD — responsive
  // ============================================================
  Widget _buildInfoCard({
    required String phone,
    required String country,
    required String city,
    required String specialty,
    required String university,
    required dynamic rating,
    required String linkedInUrl,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 22 : 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 18,
                color: isDark ? const Color(0xFF60A5FA) : primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Profile Information',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14.5,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.phone_outlined, 'Phone', phone, isDark, textPrimary, textSecondary),
          _infoRow(Icons.public_outlined, 'Country', country, isDark, textPrimary, textSecondary),
          _infoRow(Icons.location_city_outlined, 'City', city, isDark, textPrimary, textSecondary),
          _infoRow(
            Icons.workspace_premium_outlined,
            'Specialty',
            specialty,
            isDark,
            textPrimary,
            textSecondary,
          ),
          _infoRow(Icons.school_outlined, 'University', university, isDark, textPrimary, textSecondary),
          _infoRow(
            Icons.star_outline_rounded,
            'Rating',
            '$rating / 5',
            isDark,
            textPrimary,
            textSecondary,
          ),
          if (linkedInUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _openUrl(linkedInUrl, 'LinkedIn'),
              child: _infoRow(
                Icons.link_rounded,
                'LinkedIn',
                linkedInUrl,
                isDark,
                textPrimary,
                textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(isDark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 15,
              color: isDark ? const Color(0xFF60A5FA) : primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENTS CARD — responsive
  // ============================================================
  Widget _buildDocumentsCard(
    bool hasCV,
    bool hasCertificate,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 22 : 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              Text(
                'Documents',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14.5,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasCV)
            _documentButton(
              icon: Icons.description_rounded,
              label: 'View CV',
              color: const Color(0xFF3B82F6),
              isDark: isDark,
              onTap: () => _openUrl(
                ApiService.getProgrammerCvUrl(userId),
                'CV',
              ),
            ),
          if (hasCV && hasCertificate) const SizedBox(height: 10),
          if (hasCertificate)
            _documentButton(
              icon: Icons.verified_rounded,
              label: 'View Certificate',
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: () => _openUrl(
                ApiService.getProgrammerCertificateUrl(userId),
                'Certificate',
              ),
            ),
          if (!hasCV && !hasCertificate)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'No documents uploaded',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _documentButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.4 : 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON — responsive
  // ============================================================
  Widget _buildActionButton(
    bool isDark,
    Color cardColor, {
    required bool isDesktop,
  }) {
    final color = _isVerified ? accentRed : accentGreen;
    final icon = _isVerified
        ? Icons.cancel_rounded
        : Icons.verified_rounded;
    final label = _isVerified ? 'UNVERIFY' : 'VERIFY PROGRAMMER';
    final desc = _isVerified
        ? 'Remove verification badge from this programmer'
        : 'Grant verification badge to this programmer';

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.3 : 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  desc,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: isDesktop ? 62 : 58,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _isVerified
                    ? [accentRed, const Color(0xFFDC2626)]
                    : [accentGreen, const Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.40),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _toggleVerification,
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
                        Icon(icon, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isDesktop ? 15 : 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
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