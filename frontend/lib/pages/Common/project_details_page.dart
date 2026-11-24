import 'package:flutter/material.dart';

import '../../services/media_url.dart';
import '../../services/post_service.dart';
import '../../services/project_service.dart';
import '../../services/server_time.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../Customer/apply_to_post_page.dart';
import '../Customer/new_project_page.dart';
import '../Customer/post_applications_page.dart';

/// A customer project with its numbered acceptance criteria.
class ProjectDetailsPage extends StatefulWidget {
  final int projectId;
  final int currentUserId;
  final String currentUserType;

  const ProjectDetailsPage({super.key, required this.projectId, required this.currentUserId, required this.currentUserType});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  Map<String, dynamic>? _project;
  String? _error;
  bool _loading = true;
  bool _hasApplied = false;

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
    final result = await ProjectService.get(widget.projectId);
    var applied = false;
    if (result.ok && widget.currentUserType == 'Programmer') {
      applied = await PostService.hasUserApplied(postId: widget.projectId, userId: widget.currentUserId);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasApplied = applied;
      if (result.ok) {
        _project = result.body;
      } else {
        _error = result.statusCode == 404
            ? "This project isn't available. It may be under review or removed."
            : "We couldn't load this project. Check your connection and try again.";
      }
    });
  }

  List<String> get _criteria =>
      ((_project?['criteria'] as List?) ?? []).map((c) => (c as Map)['text'] as String? ?? '').toList();

  ProjectDraft _asDraft() {
    final p = _project!;
    return ProjectDraft(
      title: p['title'] ?? '',
      problemStatement: p['problemStatement'] ?? '',
      targetUsers: p['targetUsers'] ?? '',
      budgetMin: (p['budgetMin'] as num?)?.toDouble(),
      budgetMax: (p['budgetMax'] as num?)?.toDouble(),
      deadlineDays: p['deadlineDays'] as int?,
      criteria: _criteria,
    );
  }

  Future<void> _primaryAction() async {
    final p = _project!;
    final isMine = p['isMine'] == true;
    final status = p['status'] as String? ?? '';
    if (isMine && (status == 'Pending' || status == 'Rejected')) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewProjectPage(userId: widget.currentUserId, projectId: widget.projectId, initial: _asDraft()),
        ),
      );
      if (mounted) _load();
    } else if (isMine) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostApplicationsPage(postId: widget.projectId, requesterId: widget.currentUserId, postContent: p['title']),
        ),
      );
      if (mounted) _load();
    } else {
      final applied = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ApplyToPostPage(
            postId: widget.projectId,
            programmerId: widget.currentUserId,
            postAuthorName: p['authorName'] ?? 'Customer',
            postContent: p['title'],
          ),
        ),
      );
      if (applied == true && mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Project')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState(theme)
              : _content(theme),
    );
  }

  Widget _errorState(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(DevLinkTokens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: DevLinkTokens.spaceLg),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );

  Widget _content(ThemeData theme) {
    final p = _project!;
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final gutter = width < 720 ? 16.0 : (wide ? 32.0 : 24.0);
    final status = p['status'] as String? ?? 'Pending';
    final isClosed = p['isClosed'] == true;
    final reason = p['rejectionReason'] as String?;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Projects', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
        const SizedBox(height: DevLinkTokens.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(p['title'] ?? '',
                  style: (width < 720 ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall)?.copyWith(color: scheme.onSurface)),
            ),
            const SizedBox(width: DevLinkTokens.spaceMd),
            DLStatusChip.forPostStatus(isClosed ? 'Closed' : status),
          ],
        ),
        if (parseServerTime(p['createdAt'] as String?) case final posted?) ...[
          const SizedBox(height: DevLinkTokens.spaceXs),
          Text('Posted ${_formatLocal(posted)}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        if (status == 'Rejected' && reason != null) ...[
          const SizedBox(height: DevLinkTokens.spaceLg),
          _reviewerNote(theme, reason),
        ],
      ],
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(theme, 'The problem', p['problemStatement']),
        if ((p['targetUsers'] as String?)?.isNotEmpty == true) _section(theme, 'Who will use it', p['targetUsers']),
        Text('Acceptance criteria', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceXs),
        Text('Each application answers every one. Delivery is checked against the same list.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: DevLinkTokens.spaceMd),
        DLCriteriaList(criteria: _criteria),
      ],
    );

    final side = _summaryCard(theme);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: DevLinkTokens.spaceXl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: DevLinkTokens.spaceXl),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    const SizedBox(width: DevLinkTokens.space2xl),
                    SizedBox(width: 320, child: side),
                  ],
                )
              else ...[
                side,
                const SizedBox(height: DevLinkTokens.spaceXl),
                main,
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatLocal(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  Widget _section(ThemeData theme, String title, String? body) => Padding(
        padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: DevLinkTokens.spaceSm),
            Text(body ?? '', style: theme.textTheme.bodyLarge),
          ],
        ),
      );

  Widget _reviewerNote(ThemeData theme, String reason) {
    final dl = theme.extension<DevLinkColors>() ?? DevLinkColors.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DevLinkTokens.spaceMd),
      decoration: BoxDecoration(
        color: dl.warningC,
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm),
        border: BorderDirectional(start: BorderSide(color: dl.warning, width: 4)),
      ),
      child: Text('Reviewer note: $reason', style: theme.textTheme.bodyMedium?.copyWith(color: dl.onWarningC)),
    );
  }

  Widget _summaryCard(ThemeData theme) {
    final p = _project!;
    final scheme = theme.colorScheme;
    final isMine = p['isMine'] == true;
    final status = p['status'] as String? ?? '';
    final isClosed = p['isClosed'] == true;
    final isProgrammer = widget.currentUserType == 'Programmer';
    final avatar = MediaUrl.resolve(p['avatarUrl'] as String?);
    final name = (p['authorName'] as String?) ?? 'Customer';

    String? action;
    String? reason;
    if (isMine) {
      action = status == 'Pending' || status == 'Rejected' ? 'Edit project' : 'View applications';
    } else if (isProgrammer) {
      if (isClosed) {
        reason = 'This project has already been assigned.';
      } else if (_hasApplied) {
        reason = "You've applied to this project.";
      } else {
        action = 'Apply with your plan';
      }
    }

    final rows = [
      DLSummaryRow('Budget', formatBudget((p['budgetMin'] as num?)?.toDouble(), (p['budgetMax'] as num?)?.toDouble())),
      DLSummaryRow('Deadline', formatDeadline(p['deadlineDays'] as int?)),
      DLSummaryRow('Requirements', '${p['criteriaCount'] ?? 0}'),
      DLSummaryRow('Applicants', '${p['applicationsCount'] ?? 0}'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[rows[i], const DLDashedDivider()],
          const SizedBox(height: DevLinkTokens.spaceLg),
          if (action != null)
            FilledButton(onPressed: _primaryAction, child: Text(action))
          else if (reason != null)
            Text(reason, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: DevLinkTokens.spaceLg),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                foregroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
              ),
              const SizedBox(width: DevLinkTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(isMine ? 'Your project' : 'Customer',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DevLinkTokens.spaceLg),
          const DLPaymentNotice(),
        ],
      ),
    );
  }
}
