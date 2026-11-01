import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

class NotificationService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  static Future<List<NotificationModel>> getNotifications(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Notifications/$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((e) => NotificationModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> markAsRead(int id) async {
    try {
      await http.post(Uri.parse('$baseUrl/api/Notifications/$id/read'));
    } catch (e) {
      
    }
  }
}