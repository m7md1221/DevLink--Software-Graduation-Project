import 'package:flutter/material.dart';

import '../../services/engagement_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../../widgets/dl/engagement_widgets.dart';

/// The customer's review: accept each delivered requirement or ask for a revision with a note.
class ReviewDeliveryPage extends StatefulWidget {
  final Map<String, dynamic> engagement;

  const ReviewDeliveryPage({super.key, required this.engagement});

  @override
  State<ReviewDeliveryPage> createState() => _ReviewDeliveryPageState();
}

class _ReviewDeliveryPageState extends State<ReviewDeliveryPage> {
  final _draft = ReviewDraft();
  final Map<int, TextEditingController> _notes = {};
  String? _error;
  int? _errorCriterion;
  bool _sending = false;

  late final List<Map<String, dynamic>> _items =
      ((widget.engagement['criteria'] as List?) ?? []).cast<Map<String, dynamic>>().where((c) => c['status'] == CriterionStatus.inReview).toList();

  bool get _canRevise => (widget.engagement['actions'] as Map?)?['canRequestRevision'] == true;

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _noteFor(int id) => _notes.putIfAbsent(id, TextEditingController.new);

  (String, int?)? _check() {
    for (final c in _items) {
      final id = c['id'] as int;
      final order = c['order'] as int;
      final decision = _draft.decisions[id];
      if (decision == null) return ('Decide on requirement $order.', id);
      if (decision == 'Revise' && _noteFor(id).text.trim().length < 5) {
        return ('Requirement $order: explain what needs revision in 5–500 characters.', id);
      }
      if (decision == 'Accept' && c['claim'] == 'NotMet' && !_draft.waived.contains(id)) {
        return ('Requirement $order was marked not met. Confirm the waiver to accept it.', id);
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _check();
    if (problem != null) {
      setState(() {
        _error = problem.$1;
        _errorCriterion = problem.$2;
      });
      return;
    }
    final completes = _items.every((c) => _draft.decisions[c['id']] == 'Accept') &&
        (widget.engagement['criteriaAccepted'] as int? ?? 0) + _items.length == (widget.engagement['criteriaTotal'] as int? ?? -1);
    if (completes) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Accept everything?'),
          content: const Text('Every requirement will be accepted and the engagement completes. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accept and complete')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    for (final c in _items) {
      _draft.notes[c['id'] as int] = _noteFor(c['id'] as int).text;
    }
    setState(() {
      _sending = true;
      _error = null;
      _errorCriterion = null;
    });
    final result = await EngagementService.review(widget.engagement['id'] as int, _draft, _items.map((c) => c['id'] as int));
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final deliveries = ((widget.engagement['deliveries'] as List?) ?? []).cast<Map<String, dynamic>>();
    final latest = deliveries.isEmpty ? null : deliveries.last;
    final used = widget.engagement['revisionsUsed'] as int? ?? 0;
    final max = widget.engagement['maxRevisions'] as int? ?? 2;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Review delivery')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: width < 720 ? 16 : 32, vertical: DevLinkTokens.spaceXl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.engagement['projectTitle'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
                const SizedBox(height: DevLinkTokens.spaceSm),
                Text('Delivery ${latest?['round'] ?? ''} from ${widget.engagement['programmerName'] ?? 'the programmer'}',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: DevLinkTokens.spaceXs),
                Text(
                    _canRevise
                        ? 'Accept each requirement or ask for a revision. Revision rounds used: $used of $max.'
                        : 'No revision rounds are left. Accept the remaining requirements, or request cancellation from the engagement page.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (latest != null) ...[
                  const SizedBox(height: DevLinkTokens.spaceLg),
                  DLCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Programmer's note", style: theme.textTheme.labelLarge),
                      const SizedBox(height: DevLinkTokens.spaceXs),
                      Text(latest['note'] ?? '', style: theme.textTheme.bodyLarge),
                    ]),
                  ),
                ],
                const SizedBox(height: DevLinkTokens.spaceXl),
                for (final c in _items) ...[_card(theme, c), const SizedBox(height: DevLinkTokens.spaceLg)],
                if (_error != null) ...[
                  Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                  const SizedBox(height: DevLinkTokens.spaceMd),
                ],
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child:
                      _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, Map<String, dynamic> c) {
    final scheme = theme.colorScheme;
    final id = c['id'] as int;
    final decision = _draft.decisions[id];
    final notMet = c['claim'] == 'NotMet';
    return DLCard(
      borderColor: _errorCriterion == id ? scheme.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DLNumberChip(c['order'] as int),
            const SizedBox(width: DevLinkTokens.spaceMd),
            Expanded(child: Text(c['text'] ?? '', style: theme.textTheme.bodyLarge)),
            const SizedBox(width: DevLinkTokens.spaceMd),
            notMet
                ? const DLStatusChip(label: 'Marked not met', icon: Icons.close_rounded, kind: DLChipKind.warning)
                : const DLStatusChip(label: 'Marked met', icon: Icons.check_rounded, kind: DLChipKind.success),
          ]),
          const SizedBox(height: DevLinkTokens.spaceMd),
          Text('Evidence', style: theme.textTheme.labelLarge),
          const SizedBox(height: DevLinkTokens.spaceXs),
          SelectableText(c['evidence'] ?? '', style: theme.textTheme.bodyMedium),
          const SizedBox(height: DevLinkTokens.spaceMd),
          Wrap(spacing: DevLinkTokens.spaceSm, children: [
            ChoiceChip(
              label: const Text('Accept'),
              avatar: const Icon(Icons.check_rounded, size: 18),
              selected: decision == 'Accept',
              onSelected: (_) => setState(() => _draft.decisions[id] = 'Accept'),
            ),
            ChoiceChip(
              label: const Text('Needs revision'),
              avatar: const Icon(Icons.replay_rounded, size: 18),
              selected: decision == 'Revise',
              onSelected: _canRevise ? (_) => setState(() => _draft.decisions[id] = 'Revise') : null,
            ),
          ]),
          if (decision == 'Revise') ...[
            const SizedBox(height: DevLinkTokens.spaceMd),
            TextField(
              controller: _noteFor(id),
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'What needs to change in requirement ${c['order']}'),
            ),
          ],
          if (decision == 'Accept' && notMet)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _draft.waived.contains(id),
              onChanged: (v) => setState(() => v == true ? _draft.waived.add(id) : _draft.waived.remove(id)),
              title: const Text('Accept without it being met (waiver)'),
              subtitle: const Text('It counts as not met on the programmer\'s record.'),
            ),
        ],
      ),
    );
  }
}
