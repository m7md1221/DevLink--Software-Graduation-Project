import 'package:flutter/material.dart';

import '../../services/project_service.dart';
import '../../theme/devlink_tokens.dart';

DevLinkColors _dl(BuildContext context) =>
    Theme.of(context).extension<DevLinkColors>() ??
    (Theme.of(context).brightness == Brightness.dark ? DevLinkColors.dark : DevLinkColors.light);

/// The number square used in front of every acceptance criterion.
class DLNumberChip extends StatelessWidget {
  final int number;

  const DLNumberChip(this.number, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusXs),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A dashed hairline between rows.
class DLDashedDivider extends StatelessWidget {
  const DLDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(builder: (context, constraints) {
      const dash = 4.0, gap = 3.0;
      final count = (constraints.maxWidth / (dash + gap)).floor().clamp(0, 400);
      return Row(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.only(right: gap),
            child: SizedBox(width: dash, height: 1, child: ColoredBox(color: color)),
          ),
        ),
      );
    });
  }
}

/// Read-only numbered list of acceptance criteria in one outlined card.
class DLCriteriaList extends StatelessWidget {
  final List<String> criteria;

  const DLCriteriaList({super.key, required this.criteria});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < criteria.length; i++) ...[
            if (i > 0) const DLDashedDivider(),
            Semantics(
              label: 'Requirement ${i + 1}: ${criteria[i]}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DLNumberChip(i + 1),
                    const SizedBox(width: DevLinkTokens.spaceMd),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(criteria[i], style: Theme.of(context).textTheme.bodyLarge),
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
}

enum DLChipKind { neutral, info, warning, success, danger }

/// Status chip: always icon, label and colour together.
class DLStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final DLChipKind kind;

  const DLStatusChip({super.key, required this.label, required this.icon, required this.kind});

  factory DLStatusChip.forPostStatus(String status) {
    switch (status) {
      case 'Approved':
        return const DLStatusChip(label: 'Open', icon: Icons.check_rounded, kind: DLChipKind.success);
      case 'Rejected':
        return const DLStatusChip(label: 'Changes requested', icon: Icons.error_outline_rounded, kind: DLChipKind.warning);
      case 'Closed':
        return const DLStatusChip(label: 'Closed', icon: Icons.lock_outline_rounded, kind: DLChipKind.neutral);
      default:
        return const DLStatusChip(label: 'Under review', icon: Icons.schedule_rounded, kind: DLChipKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dl = _dl(context);
    final (bg, fg) = switch (kind) {
      DLChipKind.neutral => (dl.neutralC, dl.onNeutralC),
      DLChipKind.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
      DLChipKind.warning => (dl.warningC, dl.onWarningC),
      DLChipKind.success => (dl.successC, dl.onSuccessC),
      DLChipKind.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// "DevLink does not process payments" notice, shown wherever money is discussed.
class DLPaymentNotice extends StatelessWidget {
  const DLPaymentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DevLinkTokens.spaceMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: DevLinkTokens.spaceSm),
          Expanded(
            child: Text(
              'DevLink does not process payments. You agree the amount and pay each other directly.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label and value row for summary cards.
class DLSummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const DLSummaryRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DevLinkTokens.spaceMd),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Readiness result: blocking issues first, then warnings. The score is shown as information only.
class DLReadinessPanel extends StatelessWidget {
  final Readiness? readiness;
  final bool loading;

  const DLReadinessPanel({super.key, required this.readiness, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dl = _dl(context);
    final r = readiness;

    Widget issue(ReadinessIssue i, IconData icon, Color color) => Padding(
          padding: const EdgeInsets.only(top: DevLinkTokens.spaceSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: DevLinkTokens.spaceSm),
              Expanded(child: Text(i.message, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DevLinkTokens.spaceLg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
        ),
        child: loading || r == null
            ? Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: DevLinkTokens.spaceMd),
                Text('Checking your project…', style: theme.textTheme.bodyMedium),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Readiness check', style: theme.textTheme.titleMedium)),
                      r.ready
                          ? const DLStatusChip(label: 'Ready to submit', icon: Icons.check_rounded, kind: DLChipKind.success)
                          : const DLStatusChip(label: 'Not ready yet', icon: Icons.error_outline_rounded, kind: DLChipKind.danger),
                    ],
                  ),
                  const SizedBox(height: DevLinkTokens.spaceXs),
                  Text('Clarity score ${r.score}/100. It helps you, and never approves or rejects a project.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  if (r.blocking.isNotEmpty) ...[
                    const SizedBox(height: DevLinkTokens.spaceMd),
                    Text('Fix before submitting', style: theme.textTheme.labelLarge),
                    for (final i in r.blocking) issue(i, Icons.cancel_outlined, scheme.error),
                  ],
                  if (r.warnings.isNotEmpty) ...[
                    const SizedBox(height: DevLinkTokens.spaceMd),
                    Text('Worth improving', style: theme.textTheme.labelLarge),
                    for (final i in r.warnings) issue(i, Icons.warning_amber_rounded, dl.warning),
                  ],
                  if (r.blocking.isEmpty && r.warnings.isEmpty) ...[
                    const SizedBox(height: DevLinkTokens.spaceSm),
                    Text('Everything a programmer needs is here.', style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
      ),
    );
  }
}

String formatBudget(double? min, double? max) {
  String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  if (min == null && max == null) return '—';
  if (min != null && max != null && min != max) return '\$${n(min)}–${n(max)}';
  return '\$${n((min ?? max)!)}';
}

String formatDeadline(int? days) => days == null ? '—' : (days == 1 ? '1 day' : '$days days');

String requirementsLabel(int count) => count == 1 ? '1 requirement' : '$count requirements';

class DLAnswer {
  final int order;
  final String text;
  final String? response;
  final String? note;

  const DLAnswer({required this.order, required this.text, this.response, this.note});
}

/// Numbered criteria with an applicant's answer and note under each.
class DLAnswerList extends StatelessWidget {
  final List<DLAnswer> answers;

  const DLAnswerList({super.key, required this.answers});

  static DLStatusChip chipFor(String? response) => switch (response) {
        'WillMeet' => const DLStatusChip(label: 'Will meet', icon: Icons.check_rounded, kind: DLChipKind.success),
        'NeedsClarification' => const DLStatusChip(label: 'Needs clarification', icon: Icons.help_outline_rounded, kind: DLChipKind.info),
        'ProposeChange' => const DLStatusChip(label: 'Propose change', icon: Icons.edit_outlined, kind: DLChipKind.warning),
        _ => const DLStatusChip(label: 'No answer', icon: Icons.remove_rounded, kind: DLChipKind.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < answers.length; i++) ...[
            if (i > 0) const DLDashedDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DLNumberChip(answers[i].order),
                  const SizedBox(width: DevLinkTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(answers[i].text, style: theme.textTheme.bodyLarge),
                        ),
                        const SizedBox(height: DevLinkTokens.spaceSm),
                        chipFor(answers[i].response),
                        if ((answers[i].note ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: DevLinkTokens.spaceSm),
                          Text(answers[i].note!.trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
