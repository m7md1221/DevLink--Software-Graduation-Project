import 'dart:convert';

import '../api_config.dart';
import 'auth_http.dart' as http;

class ProjectDraft {
  String title;
  String problemStatement;
  String targetUsers;
  double? budgetMin;
  double? budgetMax;
  int? deadlineDays;
  List<String> criteria;

  ProjectDraft({
    this.title = '',
    this.problemStatement = '',
    this.targetUsers = '',
    this.budgetMin,
    this.budgetMax,
    this.deadlineDays,
    List<String>? criteria,
  }) : criteria = criteria ?? [''];

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'problemStatement': problemStatement.trim(),
        'targetUsers': targetUsers.trim(),
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'deadlineDays': deadlineDays,
        'criteria': criteria.map((c) => c.trim()).where((c) => c.isNotEmpty).toList(),
      };
}

class ReadinessIssue {
  final String code;
  final String field;
  final String message;

  const ReadinessIssue(this.code, this.field, this.message);

  factory ReadinessIssue.fromJson(Map<String, dynamic> json) =>
      ReadinessIssue(json['code'] ?? '', json['field'] ?? '', json['message'] ?? '');
}

class Readiness {
  final bool ready;
  final int score;
  final List<ReadinessIssue> blocking;
  final List<ReadinessIssue> warnings;

  const Readiness({required this.ready, required this.score, required this.blocking, required this.warnings});

  factory Readiness.fromJson(Map<String, dynamic> json) => Readiness(
        ready: json['ready'] == true,
        score: json['score'] ?? 0,
        blocking: (json['blocking'] as List? ?? []).map((e) => ReadinessIssue.fromJson(e)).toList(),
        warnings: (json['warnings'] as List? ?? []).map((e) => ReadinessIssue.fromJson(e)).toList(),
      );
}

class ProjectResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const ProjectResponse(this.statusCode, this.body);

  bool get ok => statusCode == 200;
  String get message => (body['message'] as String?) ?? "Something went wrong. Please try again.";
  Map<String, String> get fieldErrors =>
      (body['errors'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()));
  Readiness? get readiness => body['readiness'] is Map<String, dynamic> ? Readiness.fromJson(body['readiness']) : null;
}

class ProjectService {
  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}/api/Projects$path');

  static const _json = {'Content-Type': 'application/json'};

  static Future<ProjectResponse> _send(Future<dynamic> request) async {
    try {
      final response = await request;
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      return ProjectResponse(response.statusCode, decoded is Map<String, dynamic> ? decoded : <String, dynamic>{});
    } catch (_) {
      return const ProjectResponse(0, {'message': "We couldn't reach DevLink. Check your connection and try again."});
    }
  }

  static Future<ProjectResponse> checkReadiness(ProjectDraft draft) =>
      _send(http.post(_uri('/readiness'), headers: _json, body: jsonEncode(draft.toJson())));

  static Future<ProjectResponse> create(ProjectDraft draft) =>
      _send(http.post(_uri(''), headers: _json, body: jsonEncode(draft.toJson())));

  static Future<ProjectResponse> update(int id, ProjectDraft draft) =>
      _send(http.put(_uri('/$id'), headers: _json, body: jsonEncode(draft.toJson())));

  static Future<ProjectResponse> get(int id) => _send(http.get(_uri('/$id')));

  /// Applies to a customer project with one answer per criterion.
  static Future<ProjectResponse> apply(int projectId, ApplicationDraft draft) => _send(http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/Posts/$projectId/apply'),
        headers: _json,
        body: jsonEncode(draft.toJson()),
      ));

  static Future<ProjectResponse> applicants(int projectId, {String sort = 'submitted', String? dir}) =>
      _send(http.get(_uri('/$projectId/applicants?sort=$sort${dir == null ? '' : '&dir=$dir'}')));

  static Future<ProjectResponse> application(int projectId, int applicationId) =>
      _send(http.get(_uri('/$projectId/applications/$applicationId')));

  static Future<ProjectResponse> myApplications() => _send(http.get(_uri('/applications/mine')));
}

class CriterionResponse {
  static const willMeet = 'WillMeet';
  static const needsClarification = 'NeedsClarification';
  static const proposeChange = 'ProposeChange';

  static String label(String? response) => switch (response) {
        willMeet => 'Will meet',
        needsClarification => 'Needs clarification',
        proposeChange => 'Propose change',
        _ => 'No answer',
      };
}

class ApplicationDraft {
  String approach = '';
  double? amount;
  int? durationDays;
  String? framework;
  final Map<int, String> responses = {};
  final Map<int, String> notes = {};

  Map<String, dynamic> toJson() => {
        'proposal': approach.trim(),
        'price': amount,
        'durationDays': durationDays,
        if (framework != null && framework!.trim().isNotEmpty) 'framework': framework!.trim(),
        'responses': responses.entries
            .map((e) => {
                  'criterionId': e.key,
                  'response': e.value,
                  'note': (notes[e.key] ?? '').trim().isEmpty ? null : notes[e.key]!.trim(),
                })
            .toList(),
      };
}

/// "5 will meet · 1 clarify · 1 change" from a coverage object.
String coverageLabel(Map<String, dynamic>? coverage) {
  if (coverage == null) return '—';
  final parts = <String>[
    '${coverage['willMeet'] ?? 0} will meet',
    if ((coverage['needsClarification'] ?? 0) > 0) '${coverage['needsClarification']} clarify',
    if ((coverage['proposeChange'] ?? 0) > 0) '${coverage['proposeChange']} change',
  ];
  return parts.join(' · ');
}
