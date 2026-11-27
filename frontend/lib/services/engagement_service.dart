import 'dart:convert';

import '../api_config.dart';
import 'auth_http.dart' as http;
import 'project_service.dart' show ProjectResponse;

class EngagementStatus {
  static const active = 'Active';
  static const delivered = 'Delivered';
  static const completed = 'Completed';
  static const cancelled = 'Cancelled';
}

class CriterionStatus {
  static const open = 'Open';
  static const inReview = 'InReview';
  static const needsRevision = 'NeedsRevision';
  static const accepted = 'Accepted';
}

/// One answer per requirement still open, plus an overall note.
class DeliveryDraft {
  String note = '';
  final Map<int, String> claims = {};
  final Map<int, String> evidence = {};

  Map<String, dynamic> toJson(Iterable<int> criterionIds) => {
        'note': note.trim(),
        'items': [
          for (final id in criterionIds)
            if (claims[id] != null) {'criterionId': id, 'claim': claims[id], 'evidence': (evidence[id] ?? '').trim()},
        ],
      };
}

/// The customer's decision on each requirement in a delivery.
class ReviewDraft {
  final Map<int, String> decisions = {};
  final Map<int, String> notes = {};
  final Set<int> waived = {};

  Map<String, dynamic> toJson(Iterable<int> criterionIds) => {
        'items': [
          for (final id in criterionIds)
            if (decisions[id] != null)
              {
                'criterionId': id,
                'decision': decisions[id],
                'note': (notes[id] ?? '').trim().isEmpty ? null : notes[id]!.trim(),
                'waive': waived.contains(id),
              },
        ],
      };
}

class EngagementService {
  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}/api/Engagements$path');

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

  static Future<ProjectResponse> mine() => _send(http.get(_uri('/mine')));

  static Future<ProjectResponse> get(int id) => _send(http.get(_uri('/$id')));

  static Future<ProjectResponse> deliver(int id, DeliveryDraft draft, Iterable<int> criterionIds) =>
      _send(http.post(_uri('/$id/deliveries'), headers: _json, body: jsonEncode(draft.toJson(criterionIds))));

  static Future<ProjectResponse> review(int id, ReviewDraft draft, Iterable<int> criterionIds) =>
      _send(http.post(_uri('/$id/review'), headers: _json, body: jsonEncode(draft.toJson(criterionIds))));

  static Future<ProjectResponse> requestCancellation(int id, String reason) =>
      _send(http.post(_uri('/$id/cancellation'), headers: _json, body: jsonEncode({'reason': reason.trim()})));

  static Future<ProjectResponse> answerCancellation(int id, {required bool agree}) =>
      _send(http.post(_uri('/$id/cancellation/${agree ? 'agree' : 'decline'}'), headers: _json, body: '{}'));

  static Future<ProjectResponse> adminCancel(int id, String reason) =>
      _send(http.post(_uri('/$id/admin-cancel'), headers: _json, body: jsonEncode({'reason': reason.trim()})));

  /// A programmer's completed engagements, from their public profile.
  static Future<List<Map<String, dynamic>>> completedFor(int programmerId) async {
    final result = await _send(http.get(Uri.parse('${ApiConfig.baseUrl}/api/ProgrammerProfile/$programmerId')));
    if (!result.ok) return [];
    return ((result.body['completedEngagements'] as List?) ?? []).cast<Map<String, dynamic>>();
  }
}

/// "3/6 accepted".
String acceptedLabel(int accepted, int total) => '$accepted/$total accepted';

/// "Criteria met 5/6".
String criteriaMetLabel(int met, int total) => 'Criteria met $met/$total';
