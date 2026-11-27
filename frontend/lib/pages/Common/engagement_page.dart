import 'package:flutter/material.dart';

import '../../services/engagement_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../../widgets/dl/engagement_widgets.dart';
import '../Customer/review_delivery_page.dart';
import '../Programmer/delivery_form_page.dart';

/// One engagement for either party: the requirements checklist, progress, timeline and the caller's actions.
class EngagementPage extends StatefulWidget {
  final int engagementId;

  const EngagementPage({super.key, required this.engagementId});

  @override
  State<EngagementPage> createState() => _EngagementPageState();
}

class _EngagementPageState extends State<EngagementPage> {
  Map<String, dynamic>? _e;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _e == null;
      _error = null;
    });
    final result = await EngagementService.get(widget.engagementId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _e = result.body;
      } else {
        _error = result.statusCode == 403 || result.statusCode == 404
            ? "This engagement isn't available to you."
            : "We couldn't load this engagement. Check your connection and try again.";
      }
    });
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _open(Widget page) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page));
    if (changed == true && mounted) _load();
  }

  Future<String?> _askReason({required String title, required String action}) {
    final controller = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Reason', errorText: error),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep working')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length < 5) {
                  setDialog(() => error = 'Give a reason of 5–500 characters.');
                  return;
                }
                Navigator.pop(context, controller.text.trim());
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<dynamic> Function() call) async {
    setState(() => _busy = true);
    final result = await call();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(result.message);
    _load();
  }

  Future<void> _requestCancellation() async {
    final reason = await _askReason(title: 'Request cancellation?', action: 'Send request');
    if (reason == null) return;
    await _run(() => EngagementService.requestCancellation(widget.engagementId, reason));
  }

  Future<void> _adminCancel() async {
    final reason = await _askReason(title: 'Cancel this engagement?', action: 'Cancel engagement');
    if (reason == null) return;
    await _run(() => EngagementService.adminCancel(widget.engagementId, reason));
  }

  Future<void> _answer(bool agree) async {
    if (agree) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Agree to cancel?'),
          content: const Text('The engagement ends for both of you. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Agree to cancel')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() => EngagementService.answerCancellation(widget.engagementId, agree: agree));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Engagement')),
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
              : RefreshIndicator(onRefresh: _load, child: _content(theme)),
    );
  }

  Widget _content(ThemeData theme) {
    final e = _e!;
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final role = e['role'] as String? ?? 'customer';
    final actions = (e['actions'] as Map?)?.cast<String, dynamic>() ?? {};
    final criteria = ((e['criteria'] as List?) ?? []).cast<Map<String, dynamic>>();
    final timeline = ((e['timeline'] as List?) ?? []).cast<Map<String, dynamic>>();
    final other = role == 'programmer' ? e['customerName'] : e['programmerName'];
    final heading = role == 'admin' ? '${e['customerName']} and ${e['programmerName']}' : 'Working with $other';
    final amount = (e['agreedAmount'] as num?)?.toDouble();
    final revisionsUsed = e['revisionsUsed'] as int? ?? 0;
    final maxRevisions = e['maxRevisions'] as int? ?? 2;

    final summary = DLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DLAcceptedProgress(accepted: e['criteriaAccepted'] as int? ?? 0, total: e['criteriaTotal'] as int? ?? 0),
          const SizedBox(height: DevLinkTokens.spaceLg),
          DLSummaryRow('Agreed amount', formatBudget(amount, amount)),
          const DLDashedDivider(),
          DLSummaryRow('Deadline', formatWhen(e['deadlineAt'] as String?, withTime: false)),
          const DLDashedDivider(),
          DLSummaryRow('Revision rounds', '$revisionsUsed of $maxRevisions used'),
          if (e['criteriaMet'] != null) ...[
            const DLDashedDivider(),
            DLSummaryRow('Result', criteriaMetLabel(e['criteriaMet'] as int, e['criteriaTotal'] as int? ?? 0)),
          ],
          const SizedBox(height: DevLinkTokens.spaceLg),
          if (actions['canDeliver'] == true)
            FilledButton(
              onPressed: _busy ? null : () => _open(DeliveryFormPage(engagement: e)),
              child: Text(revisionsUsed > 0 ? 'Submit revised delivery' : 'Submit delivery'),
            ),
          if (actions['canReview'] == true)
            FilledButton(
              onPressed: _busy ? null : () => _open(ReviewDeliveryPage(engagement: e)),
              child: const Text('Review delivery'),
            ),
          if (actions['canRequestCancellation'] == true) ...[
            const SizedBox(height: DevLinkTokens.spaceSm),
            OutlinedButton(onPressed: _busy ? null : _requestCancellation, child: const Text('Request cancellation')),
          ],
          if (actions['canAdminCancel'] == true) OutlinedButton(onPressed: _busy ? null : _adminCancel, child: const Text('Cancel as admin')),
          const SizedBox(height: DevLinkTokens.spaceLg),
          const DLPaymentNotice(),
        ],
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_cancellationBanner(theme, e, actions) case final banner?) ...[banner, const SizedBox(height: DevLinkTokens.spaceXl)],
        Text('Requirements', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceMd),
        DLCard(
          child: Column(children: [
            for (var i = 0; i < criteria.length; i++) ...[
              if (i > 0) const DLDashedDivider(),
              _criterion(theme, criteria[i]),
            ],
          ]),
        ),
        const SizedBox(height: DevLinkTokens.spaceXl),
        Text('Timeline', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceMd),
        DLCard(child: DLTimeline(events: timeline)),
      ],
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: width < 720 ? 16 : 32, vertical: DevLinkTokens.spaceXl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e['projectTitle'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
              const SizedBox(height: DevLinkTokens.spaceSm),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(heading, style: width < 720 ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall),
                ),
                engagementStatusChip(e['status'] as String?, role: role, revisionsUsed: revisionsUsed),
              ]),
              const SizedBox(height: DevLinkTokens.spaceXs),
              Text('Started ${formatWhen(e['createdAt'] as String?)}', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: DevLinkTokens.spaceXl),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: main),
                  const SizedBox(width: DevLinkTokens.space2xl),
                  SizedBox(width: 340, child: summary),
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

  Widget? _cancellationBanner(ThemeData theme, Map<String, dynamic> e, Map<String, dynamic> actions) {
    final c = (e['cancellation'] as Map?)?.cast<String, dynamic>();
    if (c == null || e['status'] == EngagementStatus.completed) return null;
    final scheme = theme.colorScheme;
    final cancelled = e['status'] == EngagementStatus.cancelled;
    final text = cancelled
        ? 'Cancelled${(c['reason'] as String?)?.isNotEmpty == true ? ': ${c['reason']}' : '.'}'
        : '${c['requestedByName']} asked to cancel: ${c['reason']}';
    return DLCard(
      borderColor: scheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, color: scheme.error),
            const SizedBox(width: DevLinkTokens.spaceSm),
            Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
          ]),
          if (actions['canAnswerCancellation'] == true) ...[
            const SizedBox(height: DevLinkTokens.spaceMd),
            Wrap(spacing: DevLinkTokens.spaceMd, runSpacing: DevLinkTokens.spaceSm, children: [
              FilledButton(onPressed: _busy ? null : () => _answer(true), child: const Text('Agree to cancel')),
              OutlinedButton(onPressed: _busy ? null : () => _answer(false), child: const Text('Decline and keep working')),
            ]),
          ] else if (!cancelled) ...[
            const SizedBox(height: DevLinkTokens.spaceSm),
            Text('Waiting for the other party to answer.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _criterion(ThemeData theme, Map<String, dynamic> c) {
    final scheme = theme.colorScheme;
    final claim = c['claim'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DLNumberChip(c['order'] as int? ?? 0),
          const SizedBox(width: DevLinkTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['text'] ?? '', style: theme.textTheme.bodyLarge),
                if (claim != null) ...[
                  const SizedBox(height: DevLinkTokens.spaceXs),
                  Text('${claim == 'Met' ? 'Marked met' : 'Marked not met'} · ${c['evidence'] ?? ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                if ((c['reviewNote'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: DevLinkTokens.spaceXs),
                  Text('Customer: ${c['reviewNote']}', style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(width: DevLinkTokens.spaceMd),
          criterionStatusChip(c['status'] as String?, waived: c['waived'] == true),
        ],
      ),
    );
  }
}
