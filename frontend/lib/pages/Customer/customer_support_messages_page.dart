import 'package:flutter/material.dart';
import '../../models/support_message_model.dart';
import '../../services/support_service.dart';

class CustomerSupportMessagesPage extends StatefulWidget {
  final int userId;

  const CustomerSupportMessagesPage({super.key, required this.userId});

  @override
  State<CustomerSupportMessagesPage> createState() =>
      _CustomerSupportMessagesPageState();
}

class _CustomerSupportMessagesPageState
    extends State<CustomerSupportMessagesPage> {
  List<SupportMessageModel> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await SupportService.getMyMessages(widget.userId);
    if (!mounted) return;
    setState(() {
      _messages = list;
      _isLoading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'New':
        return const Color(0xFF3B82F6);
      case 'Read':
        return const Color(0xFFF59E0B);
      case 'Replied':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'New':
        return 'Pending';
      case 'Read':
        return 'In Review';
      case 'Replied':
        return 'Replied';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Replied':
        return Icons.check_circle_rounded;
      case 'Read':
        return Icons.visibility_rounded;
      default:
        return Icons.pending_rounded;
    }
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
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
        ),
        title: Text(
          'My Messages',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : _messages.isEmpty
              ? _emptyState(textPrimary, textSecondary)
              : RefreshIndicator(
                  color: const Color(0xFF8B5CF6),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _messageCard(
                      _messages[i],
                      isDark,
                      cardColor,
                      textPrimary,
                      textSecondary,
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 56,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Messages Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You haven't contacted support yet",
            style: TextStyle(fontSize: 13.5, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(
    SupportMessageModel msg,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final statusColor = _statusColor(msg.status);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final hasReply = msg.adminReply != null && msg.adminReply!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasReply
              ? const Color(0xFF10B981).withOpacity(0.4)
              : borderColor,
          width: hasReply ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          onExpansionChanged: (expanded) {
            if (expanded && hasReply) {
              SupportService.markReplyAsRead(msg.id);
            }
          },
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _statusIcon(msg.status),
              color: statusColor,
              size: 20,
            ),
          ),
          title: Text(
            msg.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(msg.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (hasReply)
                  Row(
                    children: [
                      const Icon(
                        Icons.mark_email_read_rounded,
                        size: 12,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'Has reply',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          iconColor: textSecondary,
          collapsedIconColor: textSecondary,
          children: [
            const SizedBox(height: 4),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Your Message',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg.message,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            if (hasReply) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Support Team Reply',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        if (msg.repliedAt != null)
                          Text(
                            msg.repliedAt!.toString().substring(5, 16),
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      msg.adminReply!,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textPrimary,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for support team response',
                        style: TextStyle(
                          fontSize: 12,
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}