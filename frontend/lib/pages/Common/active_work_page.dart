import 'package:flutter/material.dart';

import '../../services/engagement_service.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../../widgets/dl/engagement_widgets.dart';
import 'engagement_page.dart';

/// The caller's engagements for either role: open ones first.
class ActiveWorkPage extends StatefulWidget {
  const ActiveWorkPage({super.key});

  @override
  State<ActiveWorkPage> createState() => _ActiveWorkPageState();
}

class _ActiveWorkPageState extends State<ActiveWorkPage> {
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
      _loading = _rows.isEmpty;
      _error = null;
    });
    final result = await EngagementService.mine();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _rows = ((result.body['engagements'] as List?) ?? []).cast<Map<String, dynamic>>();
      } else {
        _error = "We couldn't load your work. Check your connection and try again.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(DevLinkTokens.space2xl), child: Center(child: CircularProgressIndicator()));
    } else if (_error != null) {
      body = Column(children: [
        Text(_error!, style: theme.textTheme.bodyLarge),
        const SizedBox(height: DevLinkTokens.spaceMd),
        OutlinedButton(onPressed: _load, child: const Text('Try again')),
      ]);
    } else if (_rows.isEmpty) {
      body = DLCard(
        child: Text('No work yet. When an application is accepted, the engagement appears here for both of you.', style: theme.textTheme.bodyLarge),
      );
    } else {
      body = Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
        ),
        child: Column(children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _row(theme, _rows[i]),
          ],
        ]),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Active work')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: width < 720 ? 16 : 32, vertical: DevLinkTokens.spaceXl),
          children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: body))],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, Map<String, dynamic> r) {
    final scheme = theme.colorScheme;
    final total = r['criteriaTotal'] as int? ?? 0;
    final role = r['role'] as String? ?? 'customer';
    final detail = r['status'] == EngagementStatus.completed && r['criteriaMet'] != null
        ? criteriaMetLabel(r['criteriaMet'] as int, total)
        : acceptedLabel(r['criteriaAccepted'] as int? ?? 0, total);

    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => EngagementPage(engagementId: r['id'] as int)));
        if (mounted) _load();
      },
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
                  Text('${role == 'customer' ? 'Programmer' : 'Customer'}: ${r['otherPartyName'] ?? ''} · $detail',
                      style: theme.textTheme.bodyMedium),
                  Text('Due ${formatWhen(r['deadlineAt'] as String?, withTime: false)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: DevLinkTokens.spaceMd),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              engagementStatusChip(r['status'] as String?, role: role, revisionsUsed: r['revisionsUsed'] as int? ?? 0),
              if (r['needsMyAction'] == true) ...[
                const SizedBox(height: DevLinkTokens.spaceXs),
                const DLStatusChip(label: 'Your turn', icon: Icons.priority_high_rounded, kind: DLChipKind.warning),
              ],
            ]),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
