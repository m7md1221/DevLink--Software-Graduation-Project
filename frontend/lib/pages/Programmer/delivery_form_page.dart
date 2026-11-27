import 'package:flutter/material.dart';

import '../../services/engagement_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../../widgets/dl/engagement_widgets.dart';

/// The programmer's delivery: Met or Not met with evidence for every requirement not yet accepted.
class DeliveryFormPage extends StatefulWidget {
  final Map<String, dynamic> engagement;

  const DeliveryFormPage({super.key, required this.engagement});

  @override
  State<DeliveryFormPage> createState() => _DeliveryFormPageState();
}

class _DeliveryFormPageState extends State<DeliveryFormPage> {
  final _draft = DeliveryDraft();
  final _noteController = TextEditingController();
  final Map<int, TextEditingController> _evidence = {};
  String? _error;
  int? _errorCriterion;
  bool _sending = false;

  late final List<Map<String, dynamic>> _open =
      ((widget.engagement['criteria'] as List?) ?? []).cast<Map<String, dynamic>>().where((c) => c['status'] != CriterionStatus.accepted).toList();

  @override
  void dispose() {
    _noteController.dispose();
    for (final c in _evidence.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _evidenceFor(int id) => _evidence.putIfAbsent(id, TextEditingController.new);

  // Mirrors the server rules so the programmer sees the first problem before sending.
  (String, int?)? _check() {
    for (final c in _open) {
      final id = c['id'] as int;
      final order = c['order'] as int;
      if (_draft.claims[id] == null) return ('Answer requirement $order.', id);
      final evidence = _evidenceFor(id).text.trim();
      if (evidence.length < 5 || evidence.length > 500) {
        return ('Requirement $order: add evidence of 5–500 characters, such as a note or a link.', id);
      }
    }
    final note = _noteController.text.trim();
    if (note.length < 5 || note.length > 1000) return ('Add an overall note of 5–1000 characters.', null);
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
    for (final c in _open) {
      _draft.evidence[c['id'] as int] = _evidenceFor(c['id'] as int).text;
    }
    _draft.note = _noteController.text;
    setState(() {
      _sending = true;
      _error = null;
      _errorCriterion = null;
    });
    final result = await EngagementService.deliver(widget.engagement['id'] as int, _draft, _open.map((c) => c['id'] as int));
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
    final revisionsUsed = widget.engagement['revisionsUsed'] as int? ?? 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(revisionsUsed > 0 ? 'Revised delivery' : 'Submit delivery')),
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
                Text('Show how you met each requirement', style: theme.textTheme.headlineSmall),
                const SizedBox(height: DevLinkTokens.spaceXs),
                Text(
                    revisionsUsed > 0
                        ? 'Answer the requirements that still need work. Accepted ones stay accepted.'
                        : 'Answer every requirement. Add a note or a link the customer can check.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: DevLinkTokens.spaceXl),
                for (final c in _open) ...[_card(theme, c), const SizedBox(height: DevLinkTokens.spaceLg)],
                DLCard(
                  child: TextField(
                    controller: _noteController,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Overall note',
                      hintText: 'What you delivered, where to try it, and anything the customer should know.',
                    ),
                  ),
                ),
                const SizedBox(height: DevLinkTokens.spaceLg),
                if (_error != null) ...[
                  Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                  const SizedBox(height: DevLinkTokens.spaceMd),
                ],
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit delivery'),
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
    final claim = _draft.claims[id];
    return DLCard(
      borderColor: _errorCriterion == id ? scheme.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DLNumberChip(c['order'] as int),
            const SizedBox(width: DevLinkTokens.spaceMd),
            Expanded(child: Text(c['text'] ?? '', style: theme.textTheme.bodyLarge)),
          ]),
          if ((c['reviewNote'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: DevLinkTokens.spaceMd),
            Text("Customer's note: ${c['reviewNote']}", style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: DevLinkTokens.spaceMd),
          Wrap(spacing: DevLinkTokens.spaceSm, children: [
            ChoiceChip(
              label: const Text('Met'),
              avatar: const Icon(Icons.check_rounded, size: 18),
              selected: claim == 'Met',
              onSelected: (_) => setState(() => _draft.claims[id] = 'Met'),
            ),
            ChoiceChip(
              label: const Text('Not met'),
              avatar: const Icon(Icons.close_rounded, size: 18),
              selected: claim == 'NotMet',
              onSelected: (_) => setState(() => _draft.claims[id] = 'NotMet'),
            ),
          ]),
          const SizedBox(height: DevLinkTokens.spaceMd),
          TextField(
            controller: _evidenceFor(id),
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Evidence for requirement ${c['order']}',
              hintText: claim == 'NotMet' ? 'Explain what is missing and why.' : 'A link or a short note the customer can check.',
            ),
          ),
        ],
      ),
    );
  }
}
