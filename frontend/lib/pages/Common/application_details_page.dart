import 'package:flutter/material.dart';

import '../../services/post_service.dart';
import '../../services/project_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';

/// One application with every requirement and its answer. The owner may accept it from here.
class ApplicationDetailsPage extends StatefulWidget {
  final int projectId;
  final int applicationId;
  final int currentUserId;
  final bool projectClosed;

  const ApplicationDetailsPage({
    super.key,
    required this.projectId,
    required this.applicationId,
    required this.currentUserId,
    this.projectClosed = false,
  });

  @override
  State<ApplicationDetailsPage> createState() => _ApplicationDetailsPageState();
}

class _ApplicationDetailsPageState extends State<ApplicationDetailsPage> {
  Map<String, dynamic>? _app;
  String? _error;
  bool _loading = true;
  bool _accepting = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ProjectService.application(widget.projectId, widget.applicationId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _app = result.body;
      } else {
        _error = result.statusCode == 403 || result.statusCode == 404
            ? "This application isn't available to you."
            : "We couldn't load this application. Check your connection and try again.";
      }
    });
  }

  Future<void> _accept() async {
    final name = _app?['programmerName'] ?? 'this programmer';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Accept $name?'),
        content: const Text('The project is assigned to this programmer and closes to new applications.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep looking')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accept')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _accepting = true);
    final result = await PostService.acceptApplication(
        postId: widget.projectId, applicationId: widget.applicationId, requesterId: widget.currentUserId);
    if (!mounted) return;
    setState(() => _accepting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '')));
    if (result['success'] == true) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Application')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DevLinkTokens.spaceXl),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: DevLinkTokens.spaceLg),
                        OutlinedButton(onPressed: _load, child: const Text('Try again')),
                      ]),
                    ),
                  )
                : _content(theme),
      ),
    );
  }

  Widget _content(ThemeData theme) {
    final a = _app!;
    final scheme = theme.colorScheme;
    final isMine = a['isMine'] == true;
    final status = a['status'] as String? ?? 'Pending';
    final canAccept = !isMine && status == 'Pending' && !widget.projectClosed;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final answers = ((a['answers'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map((x) => DLAnswer(order: x['order'] as int, text: x['text'] ?? '', response: x['response'], note: x['note']))
        .toList();

    final statusChip = switch (status) {
      'Accepted' => const DLStatusChip(label: 'Accepted', icon: Icons.check_rounded, kind: DLChipKind.success),
      'Rejected' => const DLStatusChip(label: 'Not selected', icon: Icons.close_rounded, kind: DLChipKind.neutral),
      _ => const DLStatusChip(label: 'Submitted', icon: Icons.schedule_rounded, kind: DLChipKind.info),
    };

    final summary = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DLSummaryRow('Amount', formatBudget((a['amount'] as num?)?.toDouble(), (a['amount'] as num?)?.toDouble())),
          const DLDashedDivider(),
          DLSummaryRow('Duration', formatDeadline(a['durationDays'] as int?)),
          const DLDashedDivider(),
          DLSummaryRow('Requirements', coverageLabel(a['coverage'] as Map<String, dynamic>?)),
          const DLDashedDivider(),
          DLSummaryRow('Rating', a['rating'] == null ? 'No reviews yet' : '${a['rating']}/5'),
          const SizedBox(height: DevLinkTokens.spaceLg),
          if (canAccept)
            FilledButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Accept this application'),
            ),
          const SizedBox(height: DevLinkTokens.spaceLg),
          const DLPaymentNotice(),
        ],
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Answers to the requirements', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceMd),
        DLAnswerList(answers: answers),
        const SizedBox(height: DevLinkTokens.spaceXl),
        Text('Approach', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceSm),
        Text(a['approach'] ?? '', style: theme.textTheme.bodyLarge),
        if ((a['framework'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: DevLinkTokens.spaceLg),
          Text('Framework: ${a['framework']}', style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: width < 720 ? 16 : 32, vertical: DevLinkTokens.spaceXl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a['projectTitle'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
              const SizedBox(height: DevLinkTokens.spaceSm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: DevLinkTokens.spaceMd,
                      runSpacing: DevLinkTokens.spaceSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(isMine ? 'Your application' : (a['programmerName'] ?? 'Programmer'),
                            style: (width < 720 ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall)),
                        // Shown only when the server says the programmer is verified.
                        if (a['isVerified'] == true)
                          const DLStatusChip(label: 'Verified', icon: Icons.verified_outlined, kind: DLChipKind.info),
                      ],
                    ),
                  ),
                  statusChip,
                ],
              ),
              const SizedBox(height: DevLinkTokens.spaceXl),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: main),
                  const SizedBox(width: DevLinkTokens.space2xl),
                  SizedBox(width: 320, child: summary),
                ])
              else ...[
                summary,
                const SizedBox(height: DevLinkTokens.spaceXl),
                main,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
