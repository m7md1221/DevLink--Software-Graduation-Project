import 'package:flutter/material.dart';

import '../../services/engagement_service.dart';
import '../../services/server_time.dart';
import '../../theme/devlink_tokens.dart';
import 'dl_widgets.dart';

DLStatusChip engagementStatusChip(String? status, {String role = 'customer', int revisionsUsed = 0}) {
  switch (status) {
    case EngagementStatus.delivered:
      return DLStatusChip(label: role == 'customer' ? 'Ready for review' : 'Delivered', icon: Icons.inbox_outlined, kind: DLChipKind.info);
    case EngagementStatus.completed:
      return const DLStatusChip(label: 'Completed', icon: Icons.check_circle_outline_rounded, kind: DLChipKind.success);
    case EngagementStatus.cancelled:
      return const DLStatusChip(label: 'Cancelled', icon: Icons.block_rounded, kind: DLChipKind.neutral);
    default:
      return revisionsUsed > 0
          ? const DLStatusChip(label: 'Revision requested', icon: Icons.replay_rounded, kind: DLChipKind.warning)
          : const DLStatusChip(label: 'In progress', icon: Icons.schedule_rounded, kind: DLChipKind.info);
  }
}

DLStatusChip criterionStatusChip(String? status, {bool waived = false}) {
  switch (status) {
    case CriterionStatus.accepted:
      return waived
          ? const DLStatusChip(label: 'Accepted (waived)', icon: Icons.check_rounded, kind: DLChipKind.warning)
          : const DLStatusChip(label: 'Accepted', icon: Icons.check_rounded, kind: DLChipKind.success);
    case CriterionStatus.inReview:
      return const DLStatusChip(label: 'In review', icon: Icons.visibility_outlined, kind: DLChipKind.info);
    case CriterionStatus.needsRevision:
      return const DLStatusChip(label: 'Needs revision', icon: Icons.replay_rounded, kind: DLChipKind.warning);
    default:
      return const DLStatusChip(label: 'Not delivered', icon: Icons.radio_button_unchecked_rounded, kind: DLChipKind.neutral);
  }
}

/// "24/11/2026 16:05" in the viewer's local time.
String formatWhen(String? value, {bool withTime = true}) {
  final t = parseServerTime(value);
  if (t == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(t.day)}/${two(t.month)}/${t.year}';
  return withTime ? '$date ${two(t.hour)}:${two(t.minute)}' : date;
}

/// The "3/6 accepted" bar.
class DLAcceptedProgress extends StatelessWidget {
  final int accepted;
  final int total;

  const DLAcceptedProgress({super.key, required this.accepted, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : accepted / total;
    return Semantics(
      label: '${acceptedLabel(accepted, total)} requirements',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Requirements', style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: DevLinkTokens.spaceSm),
            Text(acceptedLabel(accepted, total), style: theme.textTheme.labelLarge),
          ]),
          const SizedBox(height: DevLinkTokens.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }
}

class DLTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const DLTimeline({super.key, required this.events});

  static IconData _icon(String? type) => switch (type) {
        'Started' => Icons.flag_outlined,
        'Delivered' => Icons.upload_rounded,
        'RevisionRequested' => Icons.replay_rounded,
        'Completed' => Icons.check_circle_outline_rounded,
        'CancellationRequested' => Icons.help_outline_rounded,
        'CancellationDeclined' => Icons.undo_rounded,
        'Cancelled' => Icons.block_rounded,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(children: [
                    Icon(_icon(events[i]['type'] as String?), size: 20, color: scheme.primary),
                    if (i < events.length - 1)
                      Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: scheme.outlineVariant)),
                  ]),
                ),
                const SizedBox(width: DevLinkTokens.spaceSm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: DevLinkTokens.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i]['message'] ?? '', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text('${events[i]['actorName'] ?? ''} · ${formatWhen(events[i]['createdAt'] as String?)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A bordered card used by the delivery and review forms.
class DLCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const DLCard({super.key, required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material, not a coloured box, so list tiles and chips inside keep their ink.
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor ?? scheme.outlineVariant),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
