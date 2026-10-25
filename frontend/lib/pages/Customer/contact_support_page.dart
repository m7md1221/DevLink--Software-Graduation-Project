import 'package:flutter/material.dart';
import '../../services/support_service.dart';
import '../../services/session_manager.dart';
import 'customer_support_messages_page.dart';

class ContactSupportPage extends StatefulWidget {
  final int userId;

  const ContactSupportPage({super.key, required this.userId});

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;
  String _userName = 'User';
  String _userEmail = '';
  int _unreadRepliesCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserInfo();
    _checkUnreadReplies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // مراقبة حالة التطبيق (لو رجعت له من الخلفية أو من صفحة تانية)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUnreadReplies();
    }
  }

  Future<void> _loadUserInfo() async {
    final email = await SessionManager.getEmail();
    if (!mounted) return;
    setState(() {
      _userEmail = email ?? 'user@devlink.com';
    });
  }

  Future<void> _checkUnreadReplies() async {
    final count = await SupportService.getUnreadRepliesCount(widget.userId);
    if (!mounted) return;
    setState(() {
      _unreadRepliesCount = count;
    });
  }

  Future<void> _openMessages() async {
    // بنفتح صفحة الرسائل
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerSupportMessagesPage(userId: widget.userId),
      ),
    );
    
    // أول ما نرجع من صفحة الرسائل، بنحدث العداد عشان لو اتقرت تختفي
    if (mounted) {
      _checkUnreadReplies();
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    final result = await SupportService.sendMessage(
      userId: widget.userId,
      name: _userName,
      email: _userEmail,
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success'] == true) {
      _subjectController.clear();
      _messageController.clear();
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to send message'),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: Color(0xFF10B981),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Message Sent!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We received your message and will get back to you soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x338B5CF6),
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
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
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Contact Support',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openMessages,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.message_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          if (_unreadRepliesCount > 0)
                            Positioned(
                              top: -6,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_unreadRepliesCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Received Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundDecorations(isDark),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: RefreshIndicator(
                color: const Color(0xFF8B5CF6),
                onRefresh: _checkUnreadReplies, // سحب للتحديث
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 20,
                      vertical: isDesktop ? 32 : 16,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isDesktop ? 32 : 24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.support_agent_rounded,
                                  color: Color(0xFF8B5CF6),
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Contact Support',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'We usually respond within 24 hours',
                                style: TextStyle(fontSize: 13, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 1.2),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: inputFill,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor, width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Your Account Info',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(Icons.person_rounded, size: 14, color: textSecondary),
                                          const SizedBox(width: 6),
                                          Text(_userName, style: TextStyle(fontSize: 13, color: textPrimary)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.email_rounded, size: 14, color: textSecondary),
                                          const SizedBox(width: 6),
                                          Text(_userEmail, style: TextStyle(fontSize: 13, color: textPrimary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Subject',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _subjectController,
                                  style: TextStyle(color: textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Brief subject of your issue',
                                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                                    prefixIcon: const Icon(Icons.subject_rounded, color: Color(0xFF8B5CF6), size: 20),
                                    filled: true,
                                    fillColor: inputFill,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Subject is required';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Message',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _messageController,
                                  maxLines: 6,
                                  style: TextStyle(color: textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Describe your issue in detail...',
                                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(bottom: 90),
                                      child: Icon(Icons.message_rounded, color: Color(0xFF8B5CF6), size: 20),
                                    ),
                                    filled: true,
                                    fillColor: inputFill,
                                    contentPadding: const EdgeInsets.all(16),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Message is required';
                                    if (v.trim().length < 10) return 'Please write at least 10 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSending ? null : _send,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: _isSending
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.send_rounded, size: 20),
                                    label: Text(
                                      _isSending ? 'SENDING...' : 'SEND MESSAGE',
                                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations(bool isDark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -50,
              child: _glowCircle(250, const Color(0xFF8B5CF6).withOpacity(isDark ? 0.1 : 0.15)),
            ),
            Positioned(
              bottom: 50,
              left: -80,
              child: _glowCircle(300, const Color(0xFF6D28D9).withOpacity(isDark ? 0.1 : 0.10)),
            ),
            Positioned(
              top: 150,
              left: 40,
              child: Opacity(
                opacity: isDark ? 0.05 : 0.08,
                child: const Icon(Icons.forum_rounded, size: 60, color: Color(0xFF8B5CF6)),
              ),
            ),
            Positioned(
              top: 350,
              right: 60,
              child: Opacity(
                opacity: isDark ? 0.05 : 0.08,
                child: const Icon(Icons.question_answer_rounded, size: 80, color: Color(0xFF8B5CF6)),
              ),
            ),
            Positioned(
              bottom: 150,
              right: 150,
              child: Opacity(
                opacity: isDark ? 0.05 : 0.08,
                child: const Icon(Icons.support_agent_rounded, size: 100, color: Color(0xFF8B5CF6)),
              ),
            ),
            Positioned(
              bottom: 250,
              left: 100,
              child: Opacity(
                opacity: isDark ? 0.05 : 0.08,
                child: const Icon(Icons.email_rounded, size: 50, color: Color(0xFF8B5CF6)),
              ),
            ),
            Positioned(
              top: 500,
              left: 20,
              child: Opacity(
                opacity: isDark ? 0.04 : 0.06,
                child: const Icon(Icons.chat_bubble_rounded, size: 70, color: Color(0xFF10B981)),
              ),
            ),
          ],
        ),
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