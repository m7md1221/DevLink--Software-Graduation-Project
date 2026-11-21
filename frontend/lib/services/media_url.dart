import '../api_config.dart';
import 'api_service.dart';

/// Image URLs (M2.12, F14–F15; M2_AUTH_DESIGN §5.2). The API returns signed,
/// expiring paths (`/api/Posts/user/5/avatar?exp=…&sig=…`) in every response that
/// shows an image. The app only puts the API's address in front of them; it never
/// builds an image URL itself, because an unsigned one is refused.
class MediaUrl {
  MediaUrl._();

  /// The full URL for a path from an API response, or '' when there is none.
  /// '' makes `Image.network` show its errorBuilder, i.e. the existing placeholder.
  static String resolve(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  static Future<String?>? _own;
  static DateTime? _ownAt;

  /// The signed-in user's own avatar, from `Auth/me`. Kept for 5 minutes, well
  /// inside the signature's 10-minute window.
  static Future<String?> ownAvatar() {
    final at = _ownAt;
    if (_own == null || at == null || DateTime.now().difference(at) > const Duration(minutes: 5)) {
      _ownAt = DateTime.now();
      _own = ApiService.me().then((r) {
        final data = r.data;
        return r.success && data != null ? data['avatarUrl'] as String? : null;
      });
    }
    return _own!;
  }

  /// After sign-out, or after the user changes their picture.
  static void forgetOwnAvatar() {
    _own = null;
    _ownAt = null;
  }
}
