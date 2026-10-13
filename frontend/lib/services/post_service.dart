import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';

class PostService {
  // ============================================================
  // BASE URL — نفس login_page
  // ============================================================
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  // ============================================================
  // GET FEED
  // ============================================================
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
      print('getFeed error: $e');
      return [];
    }
  }

  // ============================================================
  // GET USER POSTS
  // ============================================================
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
      print('getUserPosts error: $e');
      return [];
    }
  }

  // ============================================================
  // CREATE POST
  // ============================================================
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
      print('createPost error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================================
  // DELETE POST
  // ============================================================
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

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ============================================================
  // TOGGLE LIKE
  // ============================================================
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

  // ============================================================
  // GET COMMENTS
  // ============================================================
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

  // ============================================================
  // ADD COMMENT
  // ============================================================
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
        body: jsonEncode({
          'userId': userId,
          'content': content,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'commentId': data['commentId'],
          'message': data['message'],
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

  // ============================================================
  // DELETE COMMENT
  // ============================================================
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

  // ============================================================
  // SEARCH USERS
  // ============================================================
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

  // ============================================================
  // GET PUBLIC PROFILE
  // ============================================================
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

  // ============================================================
  // HELPERS — URL builders
  // ============================================================
  static String getPostImageUrl(int imageId) {
    return '$baseUrl/api/Posts/image/$imageId';
  }

  static String getUserAvatarUrl(int userId) {
    return '$baseUrl/api/Posts/user/$userId/avatar';
  }

  // ============================================================
  // CONTACT SUPPORT
  // ============================================================
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

      return {
        'success': false,
        'message': data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}