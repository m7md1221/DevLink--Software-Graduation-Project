import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/project_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../Common/project_details_page.dart';

/// Guided brief for customers: basics, problem and users, acceptance criteria, then budget and review.
class NewProjectPage extends StatefulWidget {
  final int userId;

  /// Set when editing a pending or rejected project.
  final int? projectId;
  final ProjectDraft? initial;

  const NewProjectPage({super.key, required this.userId, this.projectId, this.initial});

  @override
  State<NewProjectPage> createState() => _NewProjectPageState();
}

class _CriterionField {
  final Key key = UniqueKey();
  final TextEditingController controller;

  _CriterionField(String text) : controller = TextEditingController(text: text);
}

class _NewProjectPageState extends State<NewProjectPage> {
  static const _steps = ['Basics', 'Problem and users', 'Acceptance criteria', 'Budget and review'];
  static final _vague = RegExp(r'\b(nice|fast|modern|good|beautiful)\b', caseSensitive: false);

  int _step = 0;
  final _title = TextEditingController();
  final _problem = TextEditingController();
  final _users = TextEditingController();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  final _deadline = TextEditingController();
  final List<_CriterionField> _criteria = [];

  Map<String, String> _fieldErrors = {};
  String? _banner;
  Readiness? _readiness;
  bool _checking = false;
  bool _submitting = false;
  Timer? _debounce;

  bool get _editing => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      _title.text = d.title;
      _problem.text = d.problemStatement;
      _users.text = d.targetUsers;
      _budgetMin.text = _number(d.budgetMin);
      _budgetMax.text = _number(d.budgetMax);
      _deadline.text = d.deadlineDays?.toString() ?? '';
    }
    for (final c in (d?.criteria.isNotEmpty == true ? d!.criteria : ['', '', ''])) {
      _criteria.add(_CriterionField(c));
    }
  }

  static String _number(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_title, _problem, _users, _budgetMin, _budgetMax, _deadline]) {
      c.dispose();
    }
    for (final c in _criteria) {
      c.controller.dispose();
    }
    super.dispose();
  }

  ProjectDraft get _draft => ProjectDraft(
        title: _title.text,
        problemStatement: _problem.text,
        targetUsers: _users.text,
        budgetMin: double.tryParse(_budgetMin.text.trim()),
        budgetMax: double.tryParse(_budgetMax.text.trim()),
        deadlineDays: int.tryParse(_deadline.text.trim()),
        criteria: _criteria.map((c) => c.controller.text).toList(),
      );

  // Field limits that the server refuses with 400; readiness rules are left to the server.
  Map<String, String> _validateStep(int step) {
    final errors = <String, String>{};
    if (step == 2) {
      final filled = _criteria.where((c) => c.controller.text.trim().isNotEmpty).toList();
      if (filled.isEmpty) errors['criteria'] = 'Add at least one acceptance criterion.';
      for (var i = 0; i < _criteria.length; i++) {
        final t = _criteria[i].controller.text.trim();
        if (t.isNotEmpty && t.length < 10) errors['criteria[$i]'] = 'Use at least 10 characters.';
      }
    }
    if (step == 3) {
      final min = _budgetMin.text.trim(), max = _budgetMax.text.trim(), days = _deadline.text.trim();
      if (min.isNotEmpty && double.tryParse(min) == null) errors['budgetMin'] = 'Enter a number.';
      if (max.isNotEmpty && double.tryParse(max) == null) errors['budgetMax'] = 'Enter a number.';
      final d = int.tryParse(days);
      if (days.isNotEmpty && (d == null || d < 1 || d > 365)) errors['deadlineDays'] = 'Enter 1–365 days.';
    }
    return errors;
  }

  void _go(int step) {
    if (step > _step) {
      final errors = _validateStep(_step);
      if (errors.isNotEmpty) {
        setState(() => _fieldErrors = errors);
        return;
      }
    }
    setState(() {
      _fieldErrors = {};
      _banner = null;
      _step = step;
    });
    if (step == 3) _checkReadiness();
  }

  void _scheduleCheck() {
    if (_step != 3) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _checkReadiness);
  }

  Future<void> _checkReadiness() async {
    setState(() => _checking = true);
    final result = await ProjectService.checkReadiness(_draft);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _readiness = result.readiness;
      if (!result.ok) _banner = result.message;
    });
  }

  Future<void> _submit() async {
    final errors = _validateStep(3);
    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      return;
    }
    setState(() {
      _submitting = true;
      _banner = null;
    });
    final result = _editing ? await ProjectService.update(widget.projectId!, _draft) : await ProjectService.create(_draft);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      final id = _editing ? widget.projectId! : result.body['id'] as int;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Changes saved. Your project is back in review.' : 'Project submitted. We review projects within 2 working days.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: id, currentUserId: widget.userId, currentUserType: 'Customer')),
      );
      return;
    }
    setState(() {
      _readiness = result.readiness ?? _readiness;
      _fieldErrors = result.fieldErrors;
      _banner = result.statusCode == 422 ? 'Fix the items in the readiness check before submitting.' : result.message;
      final first = _fieldErrors.keys.firstOrNull;
      if (first != null) {
        _step = first.startsWith('title')
            ? 0
            : first.startsWith('problem') || first.startsWith('target')
                ? 1
                : first.startsWith('criteria')
                    ? 2
                    : 3;
      }
    });
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPhone = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(_editing ? 'Edit project' : 'New project')),
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
                        _stepHeader(theme),
                        const SizedBox(height: DevLinkTokens.spaceXl),
                        if (_banner != null) ...[_bannerBox(theme), const SizedBox(height: DevLinkTokens.spaceLg)],
                        [_basics, _problemStep, _criteriaStep, _reviewStep][_step](theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _bottomBar(theme, isPhone),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step ${_step + 1} of ${_steps.length}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: DevLinkTokens.spaceXs),
        Text(_steps[_step], style: theme.textTheme.headlineSmall),
        const SizedBox(height: DevLinkTokens.spaceMd),
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(width: DevLinkTokens.spaceXs),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _step ? scheme.primary : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(DevLinkTokens.radiusXs),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _bannerBox(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DevLinkTokens.spaceMd),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm)),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: DevLinkTokens.spaceSm),
            Expanded(child: Text(_banner!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer))),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required ThemeData theme,
    required String label,
    required TextEditingController controller,
    String? helper,
    String? errorKey,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? prefix,
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: DevLinkTokens.spaceSm),
          TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines > 1 ? 3 : 1,
            maxLength: maxLength,
            keyboardType: keyboard,
            inputFormatters: formatters,
            onChanged: (_) {
              if (errorKey != null && _fieldErrors.containsKey(errorKey)) setState(() => _fieldErrors.remove(errorKey));
              _scheduleCheck();
            },
            decoration: InputDecoration(
              helperText: helper,
              errorText: errorKey == null ? null : _fieldErrors[errorKey],
              prefixText: prefix,
              suffixText: suffix,
            ),
          ),
        ],
      ),
    );
  }

  Widget _basics(ThemeData theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Give your project a short, specific title.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: DevLinkTokens.spaceLg),
          _field(
            theme: theme,
            label: 'Project title',
            controller: _title,
            helper: '10–120 characters. Example: "Appointment booking site for a salon in Nablus"',
            errorKey: 'title',
            maxLength: 120,
          ),
        ],
      );

  Widget _problemStep(ThemeData theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            theme: theme,
            label: 'What problem should this solve?',
            controller: _problem,
            helper: 'At least 50 characters. Describe what happens today and why it is a problem.',
            errorKey: 'problemStatement',
            maxLines: 6,
            maxLength: 2000,
          ),
          _field(
            theme: theme,
            label: 'Who will use it? (optional)',
            controller: _users,
            helper: 'For example: "Salon customers on their phones, and the owner on a laptop."',
            errorKey: 'targetUsers',
            maxLines: 3,
            maxLength: 1000,
          ),
        ],
      );

  Widget _criteriaStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dl = theme.extension<DevLinkColors>() ?? DevLinkColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('List what the finished work must do. Programmers answer each one, and delivery is checked against the same list.',
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: DevLinkTokens.spaceSm),
        Text('Write something you could check yourself: "When I …, then …". 10–300 characters each, up to 20.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (_fieldErrors['criteria'] != null) ...[
          const SizedBox(height: DevLinkTokens.spaceSm),
          Text(_fieldErrors['criteria']!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: DevLinkTokens.spaceLg),
        for (var i = 0; i < _criteria.length; i++)
          Padding(
            key: _criteria[i].key,
            padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 12), child: DLNumberChip(i + 1)),
                const SizedBox(width: DevLinkTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _criteria[i].controller,
                        maxLength: 300,
                        maxLines: 3,
                        minLines: 1,
                        onChanged: (_) => setState(() => _fieldErrors.remove('criteria[$i]')),
                        decoration: InputDecoration(
                          labelText: 'Requirement ${i + 1}',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          hintText: i == 0 ? 'A customer can book a 30-minute slot from a phone.' : null,
                          errorText: _fieldErrors['criteria[$i]'],
                          counterText: '',
                        ),
                      ),
                      if (_vague.hasMatch(_criteria[i].controller.text))
                        Padding(
                          padding: const EdgeInsets.only(top: DevLinkTokens.spaceXs),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: dl.warning),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('This may be hard to verify. Describe what you will check.',
                                    style: theme.textTheme.bodySmall?.copyWith(color: dl.warning)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Move requirement ${i + 1} up',
                  onPressed: i == 0 ? null : () => setState(() => _criteria.insert(i - 1, _criteria.removeAt(i))),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Move requirement ${i + 1} down',
                  onPressed: i == _criteria.length - 1 ? null : () => setState(() => _criteria.insert(i + 1, _criteria.removeAt(i))),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'Remove requirement ${i + 1}',
                  onPressed: _criteria.length == 1
                      ? null
                      : () => setState(() {
                            _criteria.removeAt(i).controller.dispose();
                            _fieldErrors.removeWhere((k, _) => k.startsWith('criteria['));
                          }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: _criteria.length >= 20 ? null : () => setState(() => _criteria.add(_CriterionField(''))),
          icon: const Icon(Icons.add_rounded),
          label: Text(_criteria.length >= 20 ? 'Up to 20 requirements' : 'Add requirement'),
        ),
      ],
    );
  }

  Widget _reviewStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    final draft = _draft;
    final criteria = draft.criteria.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: DevLinkTokens.spaceXs),
              Text(body.trim().isEmpty ? '—' : body.trim(), style: theme.textTheme.bodyLarge),
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
              child: _field(theme: theme, label: 'Budget from', controller: _budgetMin, errorKey: 'budgetMin',
                  keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: digits, prefix: '\$ '),
            ),
            const SizedBox(width: DevLinkTokens.spaceMd),
            Expanded(
              child: _field(theme: theme, label: 'Budget up to', controller: _budgetMax, errorKey: 'budgetMax',
                  keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: digits, prefix: '\$ '),
            ),
          ],
        ),
        _field(
          theme: theme,
          label: 'Deadline',
          controller: _deadline,
          helper: 'Days from the start of the work, 1–365.',
          errorKey: 'deadlineDays',
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: 'days',
        ),
        const DLPaymentNotice(),
        const SizedBox(height: DevLinkTokens.spaceXl),
        DLReadinessPanel(readiness: _readiness, loading: _checking && _readiness == null),
        const SizedBox(height: DevLinkTokens.spaceXl),
        Text('Review', style: theme.textTheme.headlineSmall),
        const SizedBox(height: DevLinkTokens.spaceMd),
        section('Title', draft.title),
        section('The problem', draft.problemStatement),
        section('Who will use it', draft.targetUsers),
        Text('Acceptance criteria', style: theme.textTheme.titleMedium),
        const SizedBox(height: DevLinkTokens.spaceSm),
        criteria.isEmpty
            ? Text('No requirements yet.', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant))
            : DLCriteriaList(criteria: criteria),
        const SizedBox(height: DevLinkTokens.spaceLg),
        Text('${formatBudget(draft.budgetMin, draft.budgetMax)} · ${formatDeadline(draft.deadlineDays)}',
            style: theme.textTheme.titleMedium),
      ],
    );
  }

  Widget _bottomBar(ThemeData theme, bool isPhone) {
    final scheme = theme.colorScheme;
    final last = _step == _steps.length - 1;
    final blocked = last && (_readiness == null || !_readiness!.ready);
    return Container(
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
              if (blocked && !_checking)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: DevLinkTokens.spaceMd),
                    child: Text('Fix the items above to submit.',
                        textAlign: TextAlign.end, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ),
              FilledButton(
                onPressed: _submitting || (last && (blocked || _checking)) ? null : (last ? _submit : () => _go(_step + 1)),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(last ? (_editing ? 'Save and resubmit' : 'Submit for review') : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
