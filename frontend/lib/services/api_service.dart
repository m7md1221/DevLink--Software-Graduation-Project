import 'dart:convert';
import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_http.dart' as http;
import 'auth_http.dart' show AuthHttp;
import 'session_manager.dart';
import 'media_url.dart';

class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final int? expiresInMinutes;

  /// The API's `errorCode` (problem details), when it sent one.
  final String? errorCode;

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.expiresInMinutes,
    this.errorCode,
  });
}

/// Shown instead of signing in when the browser can't coordinate the session
/// between tabs (no Web Locks; T-MT-04).
const String unsupportedBrowserMessage =
    "This browser can't keep a DevLink session safe. Please use a current version of Chrome, Edge, Firefox or Safari.";

Map<String, dynamic>? _jsonMap(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

class ApiService {
  // ============================================================
  // BASE URL
  // ============================================================
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  // ============================================================
  // AUTH
  // ============================================================
  static Future<ApiResult> login({
    required String email,
    required String password,
    required String userType,
  }) async {
    if (!AuthHttp.instance.isRefreshSupported) {
      return ApiResult(success: false, message: unsupportedBrowserMessage, errorCode: 'UNSUPPORTED_BROWSER');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'userType': userType,
        }),
      );

      final body = _jsonMap(response.body) ?? {};

      if (response.statusCode == 200) {
        AuthHttp.instance.setSessionFromJson(body);
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Login successful',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Invalid email or password',
        errorCode: body['errorCode'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> googleLogin({
    required String idToken,
    required String userType,
    String mode = 'signup',
  }) async {
    if (!AuthHttp.instance.isRefreshSupported) {
      return ApiResult(success: false, message: unsupportedBrowserMessage, errorCode: 'UNSUPPORTED_BROWSER');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'userType': userType,
          'mode': mode,
        }),
      );

      final body = _jsonMap(response.body) ?? {};

      if (response.statusCode == 200) {
        AuthHttp.instance.setSessionFromJson(body);
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Login successful',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Google login failed',
        errorCode: body['errorCode'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> sendCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Code sent',
          expiresInMinutes: body['expiresInMinutes'] ?? 5,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to send code',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      final body = _jsonMap(response.body) ?? {};

      // `data['signupToken']` is the proof that signUp() must send.
      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Email verified',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Invalid or expired code',
        errorCode: body['errorCode'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> signUp({
    required String email,
    required String password,
    required String userType,
    required String? signupToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'userType': userType,
          'signupToken': signupToken,
        }),
      );

      final body = _jsonMap(response.body) ?? {};

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Account created',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Signup failed',
        errorCode: body['errorCode'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> sendResetCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/send-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Reset code sent',
          expiresInMinutes: body['expiresInMinutes'] ?? 5,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to send reset code',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/verify-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      final body = _jsonMap(response.body) ?? {};

      // `data['resetToken']` is the proof that resetPassword() must send.
      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Reset code verified',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Invalid or expired code',
        errorCode: body['errorCode'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> resetPassword({
    required String email,
    required String newPassword,
    required String? resetToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'newPassword': newPassword,
          'resetToken': resetToken,
        }),
      );

      final body = _jsonMap(response.body) ?? {};

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Password reset',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Reset failed',
        errorCode: body['errorCode'],
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // ============================================================
  // SESSION (M2.12)
  // ============================================================

  /// The signed-in user as the server sees them: role, status, suspension reason.
  static Future<ApiResult> me() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/Auth/me'));
      final body = _jsonMap(response.body) ?? {};
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'OK', data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Not signed in', errorCode: body['errorCode']);
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error: $e');
    }
  }

  /// Saves the non-secret user details after a sign-in or a restored session.
  /// The access token stays in memory (AuthHttp) and is never written here.
  static Future<void> saveSignedInUser(Map<String, dynamic> data, {String? fallbackUserType}) async {
    final userType = (data['userType'] ?? data['role'] ?? fallbackUserType ?? '') as String;
    final hasProfile = userType == 'Programmer'
        ? (data['hasProgrammerProfile'] ?? false) as bool
        : (data['hasProfile'] ?? false) as bool;
    await SessionManager.saveUser(
      userId: (data['userId'] ?? 0) as int,
      userType: userType,
      email: (data['email'] ?? '') as String,
      hasProfile: hasProfile,
    );
  }

  /// Ends this session on the server (and its refresh cookie), then locally.
  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/Auth/session/logout'),
        headers: {'Content-Type': 'application/json'},
        body: '{}',
      );
    } catch (_) {
      // Signed out locally either way.
    }
    MediaUrl.forgetOwnAvatar();
    AuthHttp.instance.clearSession();
    await SessionManager.clear();
  }

  /// Ends every session of this account, on every device.
  static Future<bool> logoutAll() async {
    var ok = false;
    try {
      final response = await http.post(Uri.parse('$baseUrl/api/Auth/logout-all'));
      ok = response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      ok = false;
    }
    MediaUrl.forgetOwnAvatar();
    AuthHttp.instance.clearSession();
    await SessionManager.clear();
    return ok;
  }

  // ============================================================
  // CUSTOMER PROFILE
  // ============================================================

  static Future<ApiResult> createCustomerProfile({
    required int userId,
    required String nickname,
    required String phoneNumber,
    required String country,
    required String city,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/CustomerProfile');
      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId.toString();
      request.fields['nickname'] = nickname;
      request.fields['phoneNumber'] = phoneNumber;
      request.fields['country'] = country;
      request.fields['city'] = city;

      if (!kIsWeb && imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            imageFile.path,
          ),
        );
      } else if (kIsWeb && imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profileImage',
            imageBytes,
            filename: imageName ?? 'profile.jpg',
          ),
        );
      }

      final streamed = await http.send(request);
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Profile created',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to create profile',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> getCustomerProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/CustomerProfile/$userId'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResult(
          success: true,
          message: 'OK',
          data: body,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResult(
        success: false,
        message: body['message'] ?? 'Profile not found',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> updateCustomerProfile({
    required int userId,
    String? nickname,
    String? phoneNumber,
    String? country,
    String? city,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/CustomerProfile/$userId');
      final request = http.MultipartRequest('PUT', uri);

      if (nickname != null) request.fields['nickname'] = nickname;
      if (phoneNumber != null) request.fields['phoneNumber'] = phoneNumber;
      if (country != null) request.fields['country'] = country;
      if (city != null) request.fields['city'] = city;

      if (!kIsWeb && imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            imageFile.path,
          ),
        );
      } else if (kIsWeb && imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profileImage',
            imageBytes,
            filename: imageName ?? 'profile.jpg',
          ),
        );
      }

      final streamed = await http.send(request);
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Profile updated',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Update failed',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static String getProfileImageUrl(int userId) {
    return '$baseUrl/api/CustomerProfile/$userId/image';
  }

  // ============================================================
  // PROGRAMMER PROFILE
  // ============================================================

  static Future<ApiResult> createProgrammerProfile({
    required int userId,
    required String nickname,
    required String phoneNumber,
    required String country,
    required String city,
    required String specialty,
    required String university,
    String? linkedInUrl,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageName,
    File? cvFile,
    Uint8List? cvBytes,
    String? cvName,
    File? certificateFile,
    Uint8List? certificateBytes,
    String? certificateName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/ProgrammerProfile');
      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId.toString();
      request.fields['nickname'] = nickname;
      request.fields['phoneNumber'] = phoneNumber;
      request.fields['country'] = country;
      request.fields['city'] = city;
      request.fields['specialty'] = specialty;
      request.fields['university'] = university;

      if (linkedInUrl != null && linkedInUrl.isNotEmpty) {
        request.fields['linkedInUrl'] = linkedInUrl;
      }

      if (!kIsWeb && imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            imageFile.path,
          ),
        );
      } else if (kIsWeb && imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profileImage',
            imageBytes,
            filename: imageName ?? 'profile.jpg',
          ),
        );
      }

      if (!kIsWeb && cvFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('cv', cvFile.path),
        );
      } else if (kIsWeb && cvBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'cv',
            cvBytes,
            filename: cvName ?? 'cv.pdf',
          ),
        );
      }

      if (!kIsWeb && certificateFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'certificate',
            certificateFile.path,
          ),
        );
      } else if (kIsWeb && certificateBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'certificate',
            certificateBytes,
            filename: certificateName ?? 'certificate.pdf',
          ),
        );
      }

      final streamed = await http.send(request);
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Profile created',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to create profile',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> getProgrammerProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ProgrammerProfile/$userId'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResult(
          success: true,
          message: 'OK',
          data: body,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResult(
        success: false,
        message: body['message'] ?? 'Profile not found',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> getAllProgrammers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ProgrammerProfile/all'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResult(
          success: true,
          message: 'OK',
          data: {'programmers': body},
        );
      }

      return ApiResult(
        success: false,
        message: 'Failed to load programmers',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static String getProgrammerImageUrl(int userId) {
    return '$baseUrl/api/ProgrammerProfile/$userId/image';
  }

  static String getProgrammerCvUrl(int userId) {
    return '$baseUrl/api/ProgrammerProfile/$userId/cv';
  }

  static String getProgrammerCertificateUrl(int userId) {
    return '$baseUrl/api/ProgrammerProfile/$userId/certificate';
  }

  // ============================================================
  // PROGRAMMER CV MANAGEMENT
  // ============================================================

  static Future<ApiResult> uploadProgrammerCV({
    required int userId,
    File? cvFile,
    Uint8List? cvBytes,
    String? cvName,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/ProgrammerProfile/$userId/cv',
      );
      final request = http.MultipartRequest('POST', uri);

      if (!kIsWeb && cvFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('cv', cvFile.path),
        );
      } else if (kIsWeb && cvBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'cv',
            cvBytes,
            filename: cvName ?? 'cv.pdf',
          ),
        );
      } else {
        return ApiResult(
          success: false,
          message: 'No CV file selected',
        );
      }

      final streamed = await http.send(request);
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'CV uploaded',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to upload CV',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> deleteProgrammerCV(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/ProgrammerProfile/$userId/cv'),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'CV deleted',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to delete CV',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // ============================================================
  // PROGRAMMER CERTIFICATE MANAGEMENT
  // ============================================================

  static Future<ApiResult> uploadProgrammerCertificate({
    required int userId,
    File? certFile,
    Uint8List? certBytes,
    String? certName,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/ProgrammerProfile/$userId/certificate',
      );
      final request = http.MultipartRequest('POST', uri);

      if (!kIsWeb && certFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'certificate',
            certFile.path,
          ),
        );
      } else if (kIsWeb && certBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'certificate',
            certBytes,
            filename: certName ?? 'certificate.pdf',
          ),
        );
      } else {
        return ApiResult(
          success: false,
          message: 'No certificate file selected',
        );
      }

      final streamed = await http.send(request);
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Certificate uploaded',
          data: body,
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to upload certificate',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> deleteProgrammerCertificate(
      int userId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '$baseUrl/api/ProgrammerProfile/$userId/certificate',
        ),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Certificate deleted',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to delete certificate',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // ============================================================
  // ADMIN — USERS
  // ============================================================

  static Future<ApiResult> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Admin/users'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResult(
          success: true,
          message: 'OK',
          data: {'users': body},
        );
      }

      return ApiResult(
        success: false,
        message: 'Failed to load users',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> createUser({
    required String email,
    required String password,
    required String userType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'userType': userType,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'User created',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to create user',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> updateUser({
    required int id,
    String? email,
    String? password,
    String? userType,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/Admin/users/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (email != null) 'email': email,
          if (password != null) 'password': password,
          if (userType != null) 'userType': userType,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'User updated',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to update user',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> deleteUser(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/Admin/users/$id'),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'User deleted',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to delete user',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> createAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'userType': 'Admin',
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Admin created successfully',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to create admin',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // ============================================================
  // ADMIN — VERIFICATION
  // ============================================================

  static Future<ApiResult> getProgrammersForVerification() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Admin/programmers'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResult(
          success: true,
          message: 'OK',
          data: {'programmers': body},
        );
      }

      return ApiResult(
        success: false,
        message: 'Failed to load programmers',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> verifyProgrammer(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Admin/programmers/$userId/verify'),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Verified',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to verify',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<ApiResult> unverifyProgrammer(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/Admin/programmers/$userId/unverify'),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Unverified',
        );
      }

      return ApiResult(
        success: false,
        message: body['message'] ?? 'Failed to unverify',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // ✅ GET /api/Admin/statistics
  static Future<ApiResult> getAdminStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Admin/statistics'), // ✅ شلنا ApiConfig. وحطينا baseUrl
      );

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'Success',
          data: jsonDecode(response.body),
        );
      }

      return ApiResult(
        success: false,
        message: 'Failed to load statistics',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }
}