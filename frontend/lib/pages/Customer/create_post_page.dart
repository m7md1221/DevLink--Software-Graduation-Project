import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/post_service.dart';

class CreatePostPage extends StatefulWidget {
  final int userId;
  final String authorName;
  final String authorType;

  const CreatePostPage({
    super.key,
    required this.userId,
    required this.authorName,
    required this.authorType,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();

  List<XFile> _images = [];
  final Map<String, Uint8List> _previewBytes = {};

  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 10 images'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final remaining = 10 - _images.length;
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (picked.isEmpty) return;

    final selected = picked.take(remaining).toList();

    for (final f in selected) {
      if (kIsWeb) {
        final bytes = await f.readAsBytes();
        _previewBytes[f.path] = bytes;
      }
    }

    setState(() => _images.addAll(selected));
  }

  void _removeImage(int index) {
    final removed = _images[index];
    _previewBytes.remove(removed.path);
    setState(() => _images.removeAt(index));
  }

  Future<void> _post() async {
    final text = _controller.text.trim();

    if (text.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add text or an image'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    final result = await PostService.createPost(
      userId: widget.userId,
      content: text.isEmpty ? null : text,
      images: _images.isEmpty ? null : _images,
    );

    if (!mounted) return;
    setState(() => _isPosting = false);

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.schedule_send_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Post Submitted!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your post has been sent to the admin team for review.\n\nYou will receive an email notification once it is approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
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
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    // ✅ اكتشاف إذا كان ديسكتوب
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: bgColor,
      // ===== العصر الجديد للـ AppBar =====
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF8B5CF6), // Purple
                Color(0xFF6D28D9), // Deep Purple
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x338B5CF6), // 20% opacity
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context, false),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Create Post',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: isDesktop ? 24 : 16),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _post,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8B5CF6),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 24),
              ),
              child: _isPosting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)))
                  : const Text('Post', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
      ),
      // ===== Body =====
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // ✅ كارت الإرشادات
                _buildGuidelines(isDark, cardColor, textPrimary, textSecondary),
                const SizedBox(height: 16),

                // ✅ كارت الكتابة
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (widget.authorType == 'Programmer' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)).withOpacity(0.12),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                PostService.getUserAvatarUrl(widget.userId),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  widget.authorType == 'Programmer' ? Icons.code_rounded : Icons.person_rounded,
                                  color: widget.authorType == 'Programmer' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.authorName,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
                              ),
                              Text(
                                'Public post',
                                style: TextStyle(fontSize: 11.5, color: textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: borderColor, height: 1),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controller,
                        maxLines: null,
                        minLines: 6,
                        maxLength: 5000,
                        style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5),
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          hintStyle: TextStyle(color: textSecondary, fontSize: 15),
                          filled: true,
                          fillColor: inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_images.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _images.length,
                          itemBuilder: (_, i) {
                            final img = _images[i];
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.memory(_previewBytes[img.path]!, fit: BoxFit.cover)
                                      : Image.file(File(img.path), fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _toolButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Add Photos',
                          color: const Color(0xFF10B981),
                          onTap: _pickImages,
                          cardColor: cardColor,
                        ),
                      ),
                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${_images.length} / 10 images',
                          style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ كارت الإرشادات (نقاط)
  Widget _buildGuidelines(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Text(
                'Community Guidelines',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFEF4444)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _guidelineItem('No political, religious, or offensive content.', textSecondary),
          _guidelineItem('No hate speech, discrimination, or harassment.', textSecondary),
          _guidelineItem('No spam, scams, or misleading information.', textSecondary),
          _guidelineItem('Content must align with ethical & community standards.', textSecondary),
          const SizedBox(height: 8),
          Text(
            'Posts that violate these rules will be rejected by the admin.',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _guidelineItem(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: textColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Color cardColor,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}