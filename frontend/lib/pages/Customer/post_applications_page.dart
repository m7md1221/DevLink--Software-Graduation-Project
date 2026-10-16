import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';

class PostApplicationsPage extends StatefulWidget {
  final int postId;
  final int requesterId;
  final String? postContent;

  const PostApplicationsPage({
    super.key,
    required this.postId,
    required this.requesterId,
    this.postContent,
  });

  @override
  State<PostApplicationsPage> createState() => _PostApplicationsPageState();
}

class _PostApplicationsPageState extends State<PostApplicationsPage> {
  List<PostApplicationModel> _applications = [];
  bool _isLoading = true;
  int? _acceptingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final list = await PostService.getPostApplications(
      postId: widget.postId,
      requesterId: widget.requesterId,
    );

    if (!mounted) return;
    setState(() {
      _applications = list;
      _isLoading = false;
    });
  }

  Future<void> _accept(PostApplicationModel app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Accept Application?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Accept ${app.programmerName} for this post?\n\nThis will reject all other applications and close the post.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Accept',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _acceptingId = app.id);

    final result = await PostService.acceptApplication(
      postId: widget.postId,
      applicationId: app.id,
      requesterId: widget.requesterId,
    );

    if (!mounted) return;
    setState(() => _acceptingId = null);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application accepted!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          'Applications (${_applications.length})',
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
          : _applications.isEmpty
              ? _emptyState(textPrimary, textSecondary)
              : RefreshIndicator(
                  color: const Color(0xFF8B5CF6),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _applications.length,
                    itemBuilder: (_, i) => _applicationCard(
                      _applications[i],
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
              Icons.people_outline_rounded,
              size: 56,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Applications Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Programmers will apply soon',
            style: TextStyle(fontSize: 13.5, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _applicationCard(
    PostApplicationModel app,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (app.status) {
      case 'Accepted':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Accepted';
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_rounded;
        statusLabel = 'Pending';
    }

    final isAccepting = _acceptingId == app.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: app.status == 'Pending'
              ? borderColor
              : statusColor.withOpacity(0.4),
          width: app.status == 'Pending' ? 1.2 : 1.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: app.programmerHasImage
                      ? Image.network(
                          PostService.getUserAvatarUrl(app.programmerId),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.code_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.code_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            app.programmerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        if (app.programmerIsVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (app.programmerSpecialty != null)
                      Text(
                        app.programmerSpecialty!,
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              app.proposal,
              style: TextStyle(
                fontSize: 13.5,
                color: textPrimary,
                height: 1.5,
              ),
            ),
          ),
          if (app.price != null || app.duration != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (app.price != null) ...[
                  _infoChip(
                    icon: Icons.attach_money_rounded,
                    label: '${app.price}',
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                ],
                if (app.duration != null)
                  _infoChip(
                    icon: Icons.schedule_rounded,
                    label: app.duration!,
                    color: const Color(0xFFF59E0B),
                  ),
              ],
            ),
          ],
          if (app.status == 'Pending') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isAccepting ? null : () => _accept(app),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'ACCEPT THIS PROGRAMMER',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}