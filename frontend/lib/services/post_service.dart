import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';

class PostService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  static Future<List<PostModel>> getFeed({
    required int userId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/feed?userId=$userId&page=$page&pageSize=$pageSize',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['posts'] as List? ?? [];
        return list.map((e) => PostModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<PostModel>> getUserPosts({
    required int userId,
    required int currentUserId,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/user/$userId?currentUserId=$currentUserId',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['posts'] as List? ?? [];
        return list.map((e) => PostModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required int userId,
    String? content,
    List<XFile>? images,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts');
      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId.toString();

      if (content != null && content.trim().isNotEmpty) {
        request.fields['content'] = content.trim();
      }

      if (images != null && images.isNotEmpty) {
        for (final img in images) {
          if (kIsWeb) {
            final bytes = await img.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'Images',
                bytes,
                filename: img.name,
              ),
            );
          } else {
            request.files.add(
              await http.MultipartFile.fromPath(
                'Images',
                img.path,
                filename: img.name,
              ),
            );
          }
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Post created',
          'postId': data['postId'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create post',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deletePost({
    required int postId,
    required int userId,
    bool isAdmin = false,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/$postId?userId=$userId&isAdmin=$isAdmin',
      );
      final response = await http.delete(uri);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleLike({
    required int postId,
    required int userId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/like');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'isLiked': data['isLiked'] == true,
          'likeCount': data['likeCount'] ?? 0,
        };
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<CommentModel>> getComments(int postId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/comments');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['comments'] as List? ?? [];
        return list.map((e) => CommentModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addComment({
    required int postId,
    required int userId,
    required String content,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/comments');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'content': content}),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'commentId': data['commentId'],
          'message': data['message'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteComment({
    required int commentId,
    required int userId,
    bool isAdmin = false,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/comments/$commentId?userId=$userId&isAdmin=$isAdmin',
      );
      final response = await http.delete(uri);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<UserSearchResult>> searchUsers({
    required String query,
    String? userType,
  }) async {
    try {
      final typeParam = userType != null ? '&userType=$userType' : '';
      final uri = Uri.parse(
        '$baseUrl/api/Posts/search?q=${Uri.encodeComponent(query)}$typeParam',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['users'] as List? ?? [];
        return list.map((e) => UserSearchResult.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<UserPublicProfile?> getUserProfile(int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/profile/$userId');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return UserPublicProfile.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String getPostImageUrl(int imageId) {
    return '$baseUrl/api/Posts/image/$imageId';
  }

  static String getUserAvatarUrl(int userId) {
    return '$baseUrl/api/Posts/user/$userId/avatar';
  }

  static Future<Map<String, dynamic>> sendSupportMessage({
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
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> applyToPost({
    required int postId,
    required int programmerId,
    required String proposal,
    double? price,
    String? duration,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/apply');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'programmerId': programmerId,
          'proposal': proposal,
          'price': price,
          'duration': duration,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'applicationId': data['applicationId'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<PostApplicationModel>> getPostApplications({
    required int postId,
    required int requesterId,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/$postId/applications?requesterId=$requesterId',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['applications'] as List? ?? [];
        return list.map((e) => PostApplicationModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> acceptApplication({
    required int postId,
    required int applicationId,
    required int requesterId,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/$postId/applications/$applicationId/accept?requesterId=$requesterId',
      );
      final response = await http.post(uri);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<int> getApplicationsCount(int postId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/applications/count');
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

  static Future<bool> hasUserApplied({
    required int postId,
    required int userId,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/Posts/$postId/has-applied?userId=$userId',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hasApplied'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<PostModel>> getPendingPosts() async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/pending');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['posts'] as List? ?? [];
        return list.map((e) => PostModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> approvePost(int postId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/approve');
      final response = await http.post(uri);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> rejectPost({
    required int postId,
    required String reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/Posts/$postId/reject');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}