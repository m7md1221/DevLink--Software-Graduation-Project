import 'package:flutter/material.dart';

import '../../services/project_service.dart';
import '../../services/server_time.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../Common/application_details_page.dart';
import '../Common/engagement_page.dart';

/// The programmer's applications to customer projects, with their answers one tap away.
class MyApplicationsPage extends StatefulWidget {
  final int userId;

  const MyApplicationsPage({super.key, required this.userId});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

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
    final result = await ProjectService.myApplications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _rows = ((result.body['applications'] as List?) ?? []).cast<Map<String, dynamic>>();
      } else {
        _error = "We couldn't load your applications. Check your connection and try again.";
      }
    });
  }

  static DLStatusChip _chip(Map<String, dynamic> r) {
    if (r['status'] == 'Accepted') return const DLStatusChip(label: 'Accepted', icon: Icons.check_rounded, kind: DLChipKind.success);
    if (r['status'] == 'Rejected' || r['isClosed'] == true) {
      return const DLStatusChip(label: 'Not selected', icon: Icons.close_rounded, kind: DLChipKind.neutral);
    }
    return const DLStatusChip(label: 'Submitted', icon: Icons.schedule_rounded, kind: DLChipKind.info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('My applications')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: width < 720 ? 16 : 32, vertical: DevLinkTokens.spaceXl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(DevLinkTokens.space2xl), child: Center(child: CircularProgressIndicator()))
                    : _error != null
                        ? Column(children: [
                            Text(_error!, style: theme.textTheme.bodyLarge),
                            const SizedBox(height: DevLinkTokens.spaceMd),
                            OutlinedButton(onPressed: _load, child: const Text('Try again')),
                          ])
                        : _rows.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(DevLinkTokens.spaceXl),
                                decoration: BoxDecoration(
                                  border: Border.all(color: scheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
                                ),
                                child: Text('No applications yet. Projects you apply to appear here with your answers.',
                                    style: theme.textTheme.bodyLarge),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  border: Border.all(color: scheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < _rows.length; i++) ...[
                                      if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                                      _row(theme, _rows[i]),
                                    ],
                                  ],
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, Map<String, dynamic> r) {
    final scheme = theme.colorScheme;
    final submitted = parseServerTime(r['submittedAt'] as String?);
    String two(int v) => v.toString().padLeft(2, '0');
    final when = submitted == null ? '' : 'Sent ${two(submitted.day)}/${two(submitted.month)}/${submitted.year}';
    final amount = (r['amount'] as num?)?.toDouble();

    return InkWell(
      // An accepted application opens its engagement; the answers stay one tap away from there.
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => r['engagementId'] is int
              ? EngagementPage(engagementId: r['engagementId'] as int)
              : ApplicationDetailsPage(
                  projectId: r['projectId'] as int,
                  applicationId: r['applicationId'] as int,
                  currentUserId: widget.userId,
                ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DevLinkTokens.spaceLg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['projectTitle'] ?? '', style: theme.textTheme.titleMedium),
                  const SizedBox(height: DevLinkTokens.spaceXs),
                  Text('${coverageLabel(r['coverage'] as Map<String, dynamic>?)} · ${formatBudget(amount, amount)} · ${formatDeadline(r['durationDays'] as int?)}',
                      style: theme.textTheme.bodyMedium),
                  if (when.isNotEmpty)
                    Text(when, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: DevLinkTokens.spaceMd),
            _chip(r),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
