import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/support_message_model.dart';

class SupportService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  static Future<Map<String, dynamic>> sendMessage({
    int? userId,
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Support');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'email': email,
          'subject': subject,
          'message': message,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'ticketId': data['ticketId'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<SupportMessageModel>> getAllMessages({
    String? status,
  }) async {
    try {
      final statusParam =
          status != null && status != 'All' ? '?status=$status' : '';
      final uri = Uri.parse('$baseUrl/api/Support/all$statusParam');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['messages'] as List? ?? [];
        return list.map((e) => SupportMessageModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> replyToMessage({
    required int messageId,
    required String reply,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Support/$messageId/reply');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reply': reply}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<void> markAsRead(int messageId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Support/$messageId/read');
      await http.post(uri);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> deleteMessage(int messageId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Support/$messageId');

      final response = await http.delete(uri);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<SupportMessageModel>> getMyMessages(int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Support/my/$userId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['messages'] as List? ?? [];
        return list.map((e) => SupportMessageModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<int> getUnreadRepliesCount(int userId) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Support/my/$userId/unread-count',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> markReplyAsRead(int messageId) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Support/$messageId/mark-reply-read',
      );
      await http.post(uri);
    } catch (_) {}
  }
}