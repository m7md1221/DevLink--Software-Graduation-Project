import 'dart:io';
import 'dart:typed_data';
import 'package:devlink/main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/media_url.dart';
import '../../widgets/sign_out_dialog.dart';
import '../../services/api_service.dart';

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

class _ProgrammerDashboardPageState extends State<ProgrammerDashboardPage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  final Color primary = const Color(0xFF3B82F6);
  final Color primaryDark = const Color(0xFF1D4ED8);

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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.getProgrammerProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) _profile = result.data;
    });
  }

  Future<void> _logout() async {
    // M2.12 (F10): ends the session on the server too; offers "all devices".
    await showSignOutDialog(context);
  }

  Future<void> _openUrl(String url, String label) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showSnack('Could not open $label', isError: true);
    } catch (e) {
      if (mounted) _showSnack('Error opening $label: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFEF4444) : primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickCv() async {
    if (_isPickingCv || _isUploadingCv) return;
    setState(() => _isPickingCv = true);
    try {
      const XTypeGroup pdfGroup = XTypeGroup(label: 'PDF', extensions: ['pdf']);
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
      _showSnack('CV uploaded successfully');
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _deleteCv() async {
    final confirmed = await _confirmDelete('Delete CV?', 'Are you sure?');
    if (confirmed != true) return;
    setState(() => _isUploadingCv = true);
    final result = await ApiService.deleteProgrammerCV(widget.userId);
    if (!mounted) return;
    setState(() => _isUploadingCv = false);
    if (result.success) {
      _showSnack('CV deleted successfully');
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _pickCertificate() async {
    if (_isPickingCert || _isUploadingCert) return;
    setState(() => _isPickingCert = true);
    try {
      const XTypeGroup certGroup =
          XTypeGroup(label: 'Certificate', extensions: ['pdf', 'jpg', 'jpeg', 'png']);
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
      _showSnack(result.message);
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _deleteCertificate() async {
    final confirmed = await _confirmDelete(
        'Delete Certificate?', 'Your verification will be removed.');
    if (confirmed != true) return;
    setState(() => _isUploadingCert = true);
    final result = await ApiService.deleteProgrammerCertificate(widget.userId);
    if (!mounted) return;
    setState(() => _isUploadingCert = false);
    if (result.success) {
      _showSnack('Certificate deleted successfully');
      _loadProfile();
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<bool?> _confirmDelete(String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Profile',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: _profile?['hasImage'] == true
                              ? Image.network(
                                  MediaUrl.resolve(_profile?['avatarUrl'] as String?),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      size: 40,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.person_rounded,
                                  size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profile?['nickname'] ?? 'User',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white),
                            ),
                            Text(
                              _profile?['specialty'] ?? 'Specialty',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            if (_profile?['isVerified'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        color: Colors.greenAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text('Verified',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoCard('Phone', _profile?['phoneNumber'] ?? '-', Icons.phone_rounded, textPrimary, cardColor, borderColor),
                _buildInfoCard('City', _profile?['city'] ?? '-', Icons.location_city_rounded, textPrimary, cardColor, borderColor),
                _buildInfoCard('University', _profile?['university'] ?? '-', Icons.school_rounded, textPrimary, cardColor, borderColor),
                if (_profile?['linkedInUrl'] != null && _profile!['linkedInUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _openUrl(_profile!['linkedInUrl'], 'LinkedIn'),
                    child: _buildInfoCard('LinkedIn', _profile!['linkedInUrl'], Icons.link_rounded, textPrimary, cardColor, borderColor, isLink: true),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Documents',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textPrimary)),
                      const SizedBox(height: 16),
                      _buildDocRow(
                        title: 'CV',
                        hasFile: _profile?['hasCV'] == true,
                        fileName: _profile?['cvName'] ?? 'cv.pdf',
                        isLoading: _isUploadingCv || _isPickingCv,
                        onView: () => _openUrl(ApiService.getProgrammerCvUrl(widget.userId), 'CV'),
                        onUpload: _pickCv,
                        onDelete: _deleteCv,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const Divider(),
                      _buildDocRow(
                        title: 'Certificate',
                        hasFile: _profile?['hasCertificate'] == true,
                        fileName: _profile?['certificateName'] ?? 'certificate.pdf',
                        isLoading: _isUploadingCert || _isPickingCert,
                        onView: () => _openUrl(ApiService.getProgrammerCertificateUrl(widget.userId), 'Certificate'),
                        onUpload: _pickCertificate,
                        onDelete: _deleteCertificate,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color textPrimary, Color cardColor, Color borderColor, {bool isLink = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: textPrimary.withOpacity(0.6))),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isLink ? Colors.blue : textPrimary)),
              ],
            ),
          ),
          if (isLink) const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _buildDocRow({
    required String title,
    required bool hasFile,
    required String fileName,
    required bool isLoading,
    required VoidCallback onView,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              color: hasFile ? const Color(0xFF10B981) : textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                Text(hasFile ? fileName : 'No file uploaded', style: TextStyle(fontSize: 12, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (hasFile)
              IconButton(onPressed: onView, icon: const Icon(Icons.visibility, color: Colors.blue, size: 20)),
            IconButton(
                onPressed: onUpload,
                icon: Icon(hasFile ? Icons.refresh : Icons.upload, color: const Color(0xFFF59E0B), size: 20)),
            if (hasFile)
              IconButton(
                  onPressed: onDelete, icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20)),
          ]
        ],
      ),
    );
  }
}