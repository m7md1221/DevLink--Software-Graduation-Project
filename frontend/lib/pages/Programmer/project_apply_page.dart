import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/project_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';

/// Structured application to a customer project: an answer per requirement, the offer, then a review.
class ProjectApplyPage extends StatefulWidget {
  final int projectId;

  /// The project as returned by GET /api/Projects/{id}.
  final Map<String, dynamic> project;

  const ProjectApplyPage({super.key, required this.projectId, required this.project});

  @override
  State<ProjectApplyPage> createState() => _ProjectApplyPageState();
}

class _ProjectApplyPageState extends State<ProjectApplyPage> {
  static const _steps = ['Requirements', 'Your offer', 'Review'];

  final _draft = ApplicationDraft();
  final _amount = TextEditingController();
  final _duration = TextEditingController();
  final _approach = TextEditingController();
  final _framework = TextEditingController();
  final Map<int, TextEditingController> _notes = {};
  final Map<String, String> _errors = {};
  int _step = 0;
  bool _submitting = false;
  String? _banner;

  List<Map<String, dynamic>> get _criteria =>
      ((widget.project['criteria'] as List?) ?? []).cast<Map<String, dynamic>>();

  String? get _requiredFramework => widget.project['framework'] as String?;

  @override
  void initState() {
    super.initState();
    final min = (widget.project['budgetMin'] as num?)?.toDouble();
    final max = (widget.project['budgetMax'] as num?)?.toDouble();
    if (min != null && max != null) _amount.text = ((min + max) / 2).round().toString();
    for (final c in _criteria) {
      _notes[c['id'] as int] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _duration, _approach, _framework, ..._notes.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    _draft
      ..amount = double.tryParse(_amount.text.trim())
      ..durationDays = int.tryParse(_duration.text.trim())
      ..approach = _approach.text
      ..framework = _framework.text;
    for (final e in _notes.entries) {
      _draft.notes[e.key] = e.value.text;
    }
  }

  Map<String, String> _validate(int step) {
    _sync();
    final errors = <String, String>{};
    if (step == 0) {
      for (final c in _criteria) {
        final id = c['id'] as int;
        final response = _draft.responses[id];
        final note = (_draft.notes[id] ?? '').trim();
        if (response == null) {
          errors['c$id'] = 'Choose an answer for requirement ${c['order']}.';
        } else if (response != CriterionResponse.willMeet && note.length < 5) {
          errors['c$id'] = 'Add a note of at least 5 characters.';
        }
      }
    }
    if (step == 1) {
      if (_draft.amount == null || _draft.amount! <= 0) errors['amount'] = 'Enter an amount above 0.';
      final d = _draft.durationDays;
      if (d == null || d < 1 || d > 365) errors['duration'] = 'Enter 1–365 days.';
      final a = _draft.approach.trim().length;
      if (a < 100 || a > 1500) errors['approach'] = 'Use 100–1500 characters ($a now).';
      if (_requiredFramework != null && _draft.framework!.trim().isEmpty) {
        errors['framework'] = 'This project requires $_requiredFramework.';
      }
    }
    return errors;
  }

  void _go(int step) {
    if (step > _step) {
      final errors = _validate(_step);
      if (errors.isNotEmpty) {
        setState(() => _errors
          ..clear()
          ..addAll(errors));
        return;
      }
    }
    _sync();
    setState(() {
      _errors.clear();
      _banner = null;
      _step = step;
    });
  }

  Future<void> _submit() async {
    _sync();
    setState(() {
      _submitting = true;
      _banner = null;
    });
    final result = await ProjectService.apply(widget.projectId, _draft);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent. Track it in My applications.')));
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _banner = result.message;
      if (RegExp(r'[Rr]equirement \d').hasMatch(result.message)) _step = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPhone = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Apply with your plan')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 24, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.project['title'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: DevLinkTokens.spaceXs),
                        Text('Step ${_step + 1} of ${_steps.length}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        Text(_steps[_step], style: theme.textTheme.headlineSmall),
                        const SizedBox(height: DevLinkTokens.spaceXl),
                        if (_banner != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(DevLinkTokens.spaceMd),
                              decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm)),
                              child: Text(_banner!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                            ),
                          ),
                          const SizedBox(height: DevLinkTokens.spaceLg),
                        ],
                        [_answersStep, _offerStep, _reviewStep][_step](theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 24, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      if (_step > 0) OutlinedButton(onPressed: _submitting ? null : () => _go(_step - 1), child: const Text('Back')),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submitting ? null : (_step == _steps.length - 1 ? _submit : () => _go(_step + 1)),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_step == _steps.length - 1 ? 'Send application' : 'Next'),
                      ),
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

  Widget _answersStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Answer every requirement. The customer compares applications on these answers.', style: theme.textTheme.bodyLarge),
        const SizedBox(height: DevLinkTokens.spaceLg),
        for (final c in _criteria) _criterionCard(theme, scheme, c),
      ],
    );
  }

  Widget _criterionCard(ThemeData theme, ColorScheme scheme, Map<String, dynamic> c) {
    final id = c['id'] as int;
    final selected = _draft.responses[id];
    final error = _errors['c$id'];
    return Container(
      margin: const EdgeInsets.only(bottom: DevLinkTokens.spaceMd),
      padding: const EdgeInsets.all(DevLinkTokens.spaceLg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: error != null ? scheme.error : scheme.outlineVariant, width: error != null ? 2 : 1),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DLNumberChip(c['order'] as int),
              const SizedBox(width: DevLinkTokens.spaceMd),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(c['text'] ?? '', style: theme.textTheme.bodyLarge))),
            ],
          ),
          const SizedBox(height: DevLinkTokens.spaceMd),
          Wrap(
            spacing: DevLinkTokens.spaceSm,
            runSpacing: DevLinkTokens.spaceSm,
            children: [
              for (final r in [CriterionResponse.willMeet, CriterionResponse.needsClarification, CriterionResponse.proposeChange])
                ChoiceChip(
                  label: Text(CriterionResponse.label(r)),
                  selected: selected == r,
                  onSelected: (_) => setState(() {
                    _draft.responses[id] = r;
                    _errors.remove('c$id');
                  }),
                ),
            ],
          ),
          if (selected != null && selected != CriterionResponse.willMeet) ...[
            const SizedBox(height: DevLinkTokens.spaceMd),
            TextField(
              controller: _notes[id],
              maxLength: 300,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => setState(() => _errors.remove('c$id')),
              decoration: InputDecoration(
                labelText: selected == CriterionResponse.needsClarification ? 'What do you need to know?' : 'What do you propose instead?',
                helperText: '5–300 characters',
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: DevLinkTokens.spaceSm),
            Text(error, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _offerStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    final min = (widget.project['budgetMin'] as num?)?.toDouble();
    final max = (widget.project['budgetMax'] as num?)?.toDouble();
    final amount = double.tryParse(_amount.text.trim());
    final outside = amount != null && min != null && max != null && (amount < min || amount > max);

    Widget field(String label, TextEditingController controller, String key,
            {String? helper, String? prefix, String? suffix, int maxLines = 1, int? maxLength, List<TextInputFormatter>? formatters, TextInputType? keyboard}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: DevLinkTokens.spaceSm),
              TextField(
                controller: controller,
                maxLines: maxLines,
                minLines: maxLines > 1 ? 5 : 1,
                maxLength: maxLength,
                keyboardType: keyboard,
                inputFormatters: formatters,
                onChanged: (_) => setState(() => _errors.remove(key)),
                decoration: InputDecoration(helperText: helper, errorText: _errors[key], prefixText: prefix, suffixText: suffix),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: field('Your amount', _amount, 'amount',
                  prefix: '\$ ',
                  helper: 'Budget ${formatBudget(min, max)}',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            ),
            const SizedBox(width: DevLinkTokens.spaceMd),
            Expanded(
              child: field('Duration', _duration, 'duration',
                  suffix: 'days', helper: '1–365 days', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
            ),
          ],
        ),
        if (outside)
          Padding(
            padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceLg),
            child: Text('Your amount is outside the customer\'s budget. You can still send it.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        if (_requiredFramework != null)
          field('Framework you will use', _framework, 'framework', helper: 'This project requires $_requiredFramework.'),
        field('Your approach', _approach, 'approach',
            helper: '100–1500 characters. How you will build it, and how you will check each requirement.', maxLines: 8, maxLength: 1500),
        const DLPaymentNotice(),
      ],
    );
  }

  Widget _reviewStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    final counts = {
      'willMeet': _draft.responses.values.where((r) => r == CriterionResponse.willMeet).length,
      'needsClarification': _draft.responses.values.where((r) => r == CriterionResponse.needsClarification).length,
      'proposeChange': _draft.responses.values.where((r) => r == CriterionResponse.proposeChange).length,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: DevLinkTokens.spaceSm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
          ),
          child: Column(
            children: [
              DLSummaryRow('Amount', formatBudget(_draft.amount, _draft.amount)),
              const DLDashedDivider(),
              DLSummaryRow('Duration', formatDeadline(_draft.durationDays)),
              const DLDashedDivider(),
              DLSummaryRow('Requirements', coverageLabel(counts)),
            ],
          ),
        ),
        const SizedBox(height: DevLinkTokens.spaceXl),
        Text('Your answers', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceSm),
        DLAnswerList(
          answers: [
            for (final c in _criteria)
              DLAnswer(
                order: c['order'] as int,
                text: c['text'] ?? '',
                response: _draft.responses[c['id']],
                note: _draft.notes[c['id']],
              ),
          ],
        ),
        const SizedBox(height: DevLinkTokens.spaceXl),
        Text('Your approach', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceSm),
        Text(_draft.approach.trim(), style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
