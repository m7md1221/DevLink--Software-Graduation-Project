import 'package:flutter/material.dart';

import '../../services/project_service.dart';
import '../../services/server_time.dart';
import '../../theme/devlink_tokens.dart';
import '../../widgets/dl/dl_widgets.dart';
import '../Common/application_details_page.dart';

/// The owner's applicants side by side. Sorting is the customer's choice; there is no ranking.
class CompareApplicantsPage extends StatefulWidget {
  final int projectId;
  final String projectTitle;
  final int currentUserId;
  final bool projectClosed;

  const CompareApplicantsPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.currentUserId,
    this.projectClosed = false,
  });

  @override
  State<CompareApplicantsPage> createState() => _CompareApplicantsPageState();
}

class _Column {
  final String label;
  final String sort;
  final bool numeric;
  final bool descendingFirst;

  const _Column(this.label, this.sort, {this.numeric = false, this.descendingFirst = false});
}

class _CompareApplicantsPageState extends State<CompareApplicantsPage> {
  static const _columns = [
    _Column('Applicant', 'submitted'),
    _Column('Submitted', 'submitted'),
    _Column('Requirements', 'coverage', descendingFirst: true),
    _Column('Amount', 'amount', numeric: true),
    _Column('Duration', 'duration', numeric: true),
    _Column('Rating', 'rating', numeric: true, descendingFirst: true),
    _Column('Verified', 'verified', descendingFirst: true),
  ];

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  int _sortColumn = 1;
  bool _ascending = true;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _closed = widget.projectClosed;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final column = _columns[_sortColumn];
    final result = await ProjectService.applicants(widget.projectId, sort: column.sort, dir: _ascending ? 'asc' : 'desc');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _rows = ((result.body['applicants'] as List?) ?? []).cast<Map<String, dynamic>>();
        _closed = _closed || _rows.any((r) => r['status'] == 'Accepted');
      } else {
        _error = "We couldn't load the applicants. Check your connection and try again.";
      }
    });
  }

  void _sortBy(int index) {
    final column = _columns[index];
    setState(() {
      if (_sortColumn == index) {
        _ascending = !_ascending;
      } else {
        _sortColumn = index;
        _ascending = !column.descendingFirst;
      }
    });
    _load();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationDetailsPage(
          projectId: widget.projectId,
          applicationId: row['applicationId'] as int,
          currentUserId: widget.currentUserId,
          projectClosed: _closed,
        ),
      ),
    );
    if (changed == true && mounted) {
      _closed = true;
      _load();
    }
  }

  static String _date(String? value) {
    final t = parseServerTime(value);
    if (t == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Compare applicants')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: width < 720 ? 16 : 32, vertical: DevLinkTokens.spaceXl),
          children: [
            Text(widget.projectTitle, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
            const SizedBox(height: DevLinkTokens.spaceSm),
            Text('${_rows.length} ${_rows.length == 1 ? 'applicant' : 'applicants'}', style: theme.textTheme.headlineSmall),
            const SizedBox(height: DevLinkTokens.spaceXs),
            Text('Sort by any column. DevLink does not rank applicants. Tap a row to read the full application.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: DevLinkTokens.spaceLg),
            if (_loading && _rows.isEmpty)
              const Padding(padding: EdgeInsets.all(DevLinkTokens.space2xl), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Column(children: [
                Text(_error!, style: theme.textTheme.bodyLarge),
                const SizedBox(height: DevLinkTokens.spaceMd),
                OutlinedButton(onPressed: _load, child: const Text('Try again')),
              ])
            else if (_rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(DevLinkTokens.spaceXl),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
                ),
                child: Text('No applications yet. Programmers who apply appear here with their answer to each requirement.',
                    style: theme.textTheme.bodyLarge),
              )
            else
              _table(theme),
          ],
        ),
      ),
    );
  }

  Widget _table(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      // Narrow screens scroll the table sideways inside its card, never the page.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortColumn,
          sortAscending: _ascending,
          headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          showCheckboxColumn: false,
          columns: [
            for (var i = 0; i < _columns.length; i++)
              DataColumn(label: Text(_columns[i].label), numeric: _columns[i].numeric, onSort: (_, __) => _sortBy(i)),
          ],
          rows: [
            for (final r in _rows)
              DataRow(
                onSelectChanged: (_) => _open(r),
                cells: [
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(r['programmerName'] ?? 'Programmer', style: theme.textTheme.labelLarge),
                    if (r['status'] == 'Accepted') ...[
                      const SizedBox(width: DevLinkTokens.spaceSm),
                      const DLStatusChip(label: 'Accepted', icon: Icons.check_rounded, kind: DLChipKind.success),
                    ],
                  ])),
                  DataCell(Text(_date(r['submittedAt'] as String?))),
                  DataCell(Text(coverageLabel(r['coverage'] as Map<String, dynamic>?))),
                  DataCell(Text(formatBudget((r['amount'] as num?)?.toDouble(), (r['amount'] as num?)?.toDouble()))),
                  DataCell(Text(formatDeadline(r['durationDays'] as int?))),
                  DataCell(Text(r['rating'] == null ? '—' : '${r['rating']}/5')),
                  DataCell(r['isVerified'] == true
                      ? const DLStatusChip(label: 'Verified', icon: Icons.verified_outlined, kind: DLChipKind.info)
                      : Text('—', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
