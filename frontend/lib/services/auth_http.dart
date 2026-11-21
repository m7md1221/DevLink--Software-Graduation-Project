/// Authenticated HTTP for the DevLink API (M2.12, F1–F3; M2_AUTH_DESIGN §3.5, §4.1, §7.4).
///
/// A drop-in replacement for `package:http`'s top-level functions: services import
/// this file `as http` and keep their calls. For requests to the DevLink API it
///
///  * adds `Authorization: Bearer <access token>`; the token lives in memory only,
///    never in SharedPreferences, localStorage or a readable cookie;
///  * adds `X-DevLink-Client: web`, so the API keeps the refresh token in its
///    HttpOnly cookie;
///  * refreshes the session once when a request gets 401, through one shared
///    refresh per tab (single-flight) and the browser-wide Web Lock across tabs,
///    then retries the request once; if that fails, the session ends;
///  * reports 403 `ACCOUNT_SUSPENDED`, so the app can show the suspended screen.
///    Any other 403 is left to the caller and the session is kept.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'http/api_client.dart';
import 'http/refresh_lock.dart';

export 'package:http/http.dart'
    show
        BaseRequest,
        ClientException,
        MultipartFile,
        MultipartRequest,
        Request,
        Response,
        StreamedResponse;

enum RefreshOutcome {
  /// A new access token is in memory.
  refreshed,

  /// The server ended the session (expired, revoked, or no cookie).
  ended,

  /// The server couldn't be reached or answered unexpectedly; the session is kept.
  unavailable,

  /// The browser has no Web Locks, so the app doesn't refresh (T-MT-04).
  unsupported,

  /// Another tab held the lock for too long (T-MT-05).
  lockTimeout,
}

class RefreshResult {
  final RefreshOutcome outcome;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? message;

  const RefreshResult(this.outcome, {this.data, this.errorCode, this.message});

  bool get ok => outcome == RefreshOutcome.refreshed;
}

class AuthHttp {
  AuthHttp({
    required http.Client client,
    required RefreshLock lock,
    required String baseUrl,
    String? clientHeader,
    DateTime Function()? clock,
    this.lockWait = const Duration(seconds: 15),
    this.refreshTimeout = const Duration(seconds: 10),
    this.refreshMargin = const Duration(seconds: 30),
  })  : _client = client,
        _lock = lock,
        _baseUrl = baseUrl,
        _clientHeader = clientHeader,
        _clock = clock ?? DateTime.now;

  /// The instance every service uses. Tests replace it.
  static AuthHttp instance = AuthHttp(
    client: createApiClient(),
    lock: createRefreshLock(),
    baseUrl: ApiConfig.baseUrl,
    clientHeader: apiClientHeader,
  );

  static const String sessionEndedMessage =
      'For your security, you were signed out. Please sign in again.';
  static const String lockTimeoutMessage =
      "We couldn't confirm your session. Please sign in again.";

  /// Routes that create, refresh or end a session, or need no session: a 401
  /// from them is an answer for the caller, not a reason to refresh.
  static const Set<String> _sessionRoutes = {
    '/api/Auth/login',
    '/api/Auth/google-login',
    '/api/Auth/session/refresh',
    '/api/Auth/session/logout',
    '/api/Auth/send-code',
    '/api/Auth/send-reset-code',
    '/api/Auth/verify-code',
    '/api/Auth/verify-reset-code',
    '/api/Auth/signup',
    '/api/Auth/reset-password',
  };

  final http.Client _client;
  final RefreshLock _lock;
  final String _baseUrl;
  final String? _clientHeader;
  final DateTime Function() _clock;
  final Duration lockWait;
  final Duration refreshTimeout;
  final Duration refreshMargin;

  String? _accessToken;
  DateTime? _expiresAt;
  Future<RefreshResult>? _refreshInFlight;
  bool _endReported = false;

  /// Called once when the session ends while the app is in use (not at start-up).
  void Function(String message)? onSessionEnded;

  /// Called when the API answers 403 `ACCOUNT_SUSPENDED`.
  void Function()? onSuspended;

  String? get accessToken => _accessToken;
  bool get hasSession => _accessToken != null;
  bool get isRefreshSupported => _lock.isSupported;
  String? get clientHeader => _clientHeader;

  /// Stores the access token from a login, Google sign-in, refresh, password
  /// change or Google link response.
  void setSessionFromJson(Map<String, dynamic> body) {
    final token = body['accessToken'];
    if (token is! String || token.isEmpty) {
      return;
    }
    _accessToken = token;
    _expiresAt = _parseUtc(body['accessTokenExpiresAt']);
    _endReported = false;
  }

  void clearSession() {
    _accessToken = null;
    _expiresAt = null;
  }

  // ------------------------------------------------------------------
  // package:http-compatible calls
  // ------------------------------------------------------------------

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _execute(url, () => _build('GET', url, headers, null, null));

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _execute(url, () => _build('POST', url, headers, body, encoding));

  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _execute(url, () => _build('PUT', url, headers, body, encoding));

  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _execute(url, () => _build('PATCH', url, headers, body, encoding));

  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _execute(url, () => _build('DELETE', url, headers, body, encoding));

  /// For `MultipartRequest`s. The body is buffered first, because a request can be
  /// sent only once and a 401 needs a second attempt.
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final headers = Map<String, String>.of(request.headers);

    final response = await _execute(request.url, () {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(_withAuthHeaders(request.url, headers))
        ..bodyBytes = bytes;
      return copy;
    });

    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: response.request,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }

  // ------------------------------------------------------------------
  // Refresh
  // ------------------------------------------------------------------

  /// Refreshes the session. Every caller in this tab shares one refresh; across
  /// tabs the Web Lock makes them take turns, so a rotated cookie is never sent twice.
  Future<RefreshResult> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final started = _refreshUnderLock();
    _refreshInFlight = started;
    started.whenComplete(() {
      if (identical(_refreshInFlight, started)) {
        _refreshInFlight = null;
      }
    });
    return started;
  }

  Future<RefreshResult> _refreshUnderLock() async {
    if (!_lock.isSupported) {
      return const RefreshResult(RefreshOutcome.unsupported);
    }

    try {
      return await _lock.run(_callRefresh, wait: lockWait);
    } on LockTimeoutException {
      clearSession();
      return const RefreshResult(RefreshOutcome.lockTimeout, message: lockTimeoutMessage);
    } on LockUnsupportedException {
      return const RefreshResult(RefreshOutcome.unsupported);
    }
  }

  Future<RefreshResult> _callRefresh() async {
    final url = Uri.parse('$_baseUrl/api/Auth/session/refresh');
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = '{}';
    final clientHeader = _clientHeader;
    if (clientHeader != null) {
      request.headers['X-DevLink-Client'] = clientHeader;
    }

    try {
      final response = await _sendOnce(request).timeout(refreshTimeout);
      final body = _jsonOf(response);

      if (response.statusCode == 200 && body != null && body['accessToken'] is String) {
        setSessionFromJson(body);
        return RefreshResult(RefreshOutcome.refreshed, data: body);
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        clearSession();
        return RefreshResult(
          RefreshOutcome.ended,
          errorCode: body?['errorCode'] as String?,
          message: body?['message'] as String?,
        );
      }

      return const RefreshResult(RefreshOutcome.unavailable);
    } on TimeoutException {
      return const RefreshResult(RefreshOutcome.unavailable);
    } on http.ClientException {
      return const RefreshResult(RefreshOutcome.unavailable);
    }
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<http.Response> _execute(Uri url, http.BaseRequest Function() build) async {
    final isApi = _isApi(url);
    final isSessionRoute = isApi && _sessionRoutes.contains(url.path);

    if (!isApi || isSessionRoute) {
      return _sendOnce(build());
    }

    // Refresh shortly before expiry, so most requests never see a 401.
    if (_accessToken != null && _expiresSoon()) {
      await refresh();
    }

    final sentWith = _accessToken;
    var response = await _sendOnce(build());

    if (response.statusCode == 401 && sentWith != null) {
      // Another request may already have refreshed while this one was in flight.
      final alreadyRefreshed = _accessToken != null && _accessToken != sentWith;
      final result = alreadyRefreshed ? const RefreshResult(RefreshOutcome.refreshed) : await refresh();

      if (result.ok) {
        response = await _sendOnce(build());
        if (response.statusCode == 401) {
          _endSession(_jsonOf(response)?['message'] as String? ?? sessionEndedMessage);
        }
      } else if (result.outcome != RefreshOutcome.unavailable) {
        _endSession(result.message ?? sessionEndedMessage);
      }
    }

    if (response.statusCode == 403 && _jsonOf(response)?['errorCode'] == 'ACCOUNT_SUSPENDED') {
      onSuspended?.call();
    }

    return response;
  }

  void _endSession(String message) {
    clearSession();
    if (_endReported) {
      return;
    }
    _endReported = true;
    onSessionEnded?.call(message);
  }

  http.Request _build(String method, Uri url, Map<String, String>? headers, Object? body, Encoding? encoding) {
    final request = http.Request(method, url);
    if (encoding != null) {
      request.encoding = encoding;
    }
    request.headers.addAll(_withAuthHeaders(url, headers));

    // Same body rules as package:http.
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = body.cast<int>();
      } else if (body is Map) {
        request.bodyFields = body.cast<String, String>();
      } else {
        throw ArgumentError('Invalid request body "$body".');
      }
    }
    return request;
  }

  Map<String, String> _withAuthHeaders(Uri url, Map<String, String>? headers) {
    final result = <String, String>{...?headers};
    if (!_isApi(url)) {
      return result;
    }
    final clientHeader = _clientHeader;
    if (clientHeader != null) {
      result['X-DevLink-Client'] = clientHeader;
    }
    final token = _accessToken;
    if (token != null && !result.keys.any((k) => k.toLowerCase() == 'authorization')) {
      result['Authorization'] = 'Bearer $token';
    }
    return result;
  }

  Future<http.Response> _sendOnce(http.BaseRequest request) async =>
      http.Response.fromStream(await _client.send(request));

  bool _isApi(Uri url) => url.toString().startsWith(_baseUrl);

  bool _expiresSoon() {
    final expiresAt = _expiresAt;
    return expiresAt != null && !_clock().toUtc().isBefore(expiresAt.subtract(refreshMargin));
  }

  static Map<String, dynamic>? _jsonOf(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// The API sends UTC times; a value without a zone is read as UTC, not local time.
  static DateTime? _parseUtc(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(value);
    return DateTime.tryParse(hasZone ? value : '${value}Z')?.toUtc();
  }
}

// ----------------------------------------------------------------------
// Top-level functions with package:http's signatures
// ----------------------------------------------------------------------

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    AuthHttp.instance.get(url, headers: headers);

Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    AuthHttp.instance.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    AuthHttp.instance.put(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    AuthHttp.instance.patch(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    AuthHttp.instance.delete(url, headers: headers, body: body, encoding: encoding);

/// Replaces `request.send()` for multipart uploads.
Future<http.StreamedResponse> send(http.BaseRequest request) => AuthHttp.instance.send(request);
