import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyUserId = 'userId';
  static const String _keyUserType = 'userType';
  static const String _keyEmail = 'email';
  static const String _keyHasProfile = 'hasProfile';

  static int? _cachedUserId;
  static String? _cachedUserType;
  static String? _cachedEmail;
  static bool? _cachedHasProfile;

  // ============================================================
  // SAVE
  // ============================================================
  static Future<void> saveUser({
    required int userId,
    required String userType,
    required String email,
    required bool hasProfile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserType, userType);
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyHasProfile, hasProfile);

    _cachedUserId = userId;
    _cachedUserType = userType;
    _cachedEmail = email;
    _cachedHasProfile = hasProfile;
  }

  static Future<void> updateHasProfile(bool hasProfile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasProfile, hasProfile);
    _cachedHasProfile = hasProfile;
  }

  // ============================================================
  // GET
  // ============================================================
  static Future<int?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getInt(_keyUserId);
    return _cachedUserId;
  }

  static Future<String?> getUserType() async {
    if (_cachedUserType != null) return _cachedUserType;
    final prefs = await SharedPreferences.getInstance();
    _cachedUserType = prefs.getString(_keyUserType);
    return _cachedUserType;
  }

  static Future<String?> getEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    final prefs = await SharedPreferences.getInstance();
    _cachedEmail = prefs.getString(_keyEmail);
    return _cachedEmail;
  }

  static Future<bool> getHasProfile() async {
    if (_cachedHasProfile != null) return _cachedHasProfile!;
    final prefs = await SharedPreferences.getInstance();
    _cachedHasProfile = prefs.getBool(_keyHasProfile) ?? false;
    return _cachedHasProfile!;
  }

  // ============================================================
  // CHECK
  // ============================================================
  static Future<bool> isLoggedIn() async {
    final userId = await getUserId();
    return userId != null;
  }

  // ============================================================
  // CLEAR (Logout)
  // ============================================================
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserType);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyHasProfile);

    _cachedUserId = null;
    _cachedUserType = null;
    _cachedEmail = null;
    _cachedHasProfile = null;
  }
}