// M2.12-lite: the auth client (M2_AUTH_DESIGN §3.5, §7.4, §10.2 T-MT-01…05).
//
// A fake API with strict refresh-token rotation stands in for the server. Each
// "tab" is its own AuthHttp (own memory, as in a browser tab); the tabs share the
// cookie jar, as tabs of one browser do, and optionally one lock (Web Locks).
import 'dart:async';
import 'dart:convert';

import 'package:devlink/services/api_service.dart';
import 'package:devlink/services/auth_http.dart';
import 'package:devlink/services/http/refresh_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String base = 'http://localhost:5133';
final Uri feed = Uri.parse('$base/api/Posts/feed?userId=1');

/// The browser's cookie jar, shared by every tab.
class CookieJar {
  String? refreshCookie;
}

/// Strict rotation: each refresh spends the cookie it receives; a spent cookie
/// presented again is reuse and ends the whole session family.
class FakeApi {
  FakeApi(this.jar, {this.refreshDelay = const Duration(milliseconds: 20)}) {
    jar.refreshCookie = _newCookie();
  }

  final CookieJar jar;
  final Duration refreshDelay;
  final Set<String> spent = {};
  final List<String> seenAuthorization = [];
  final List<String?> seenClientHeader = [];
  final List<String> uploads = [];

  int refreshCalls = 0;
  int rotations = 0;
  int _counter = 0;
  bool reuseDetected = false;
  bool revoked = false;
  String? currentCookie;
  String validAccessToken = 'never-issued';

  /// What the API answers for the feed when the token is valid; tests change it.
  http.Response Function()? feedOverride;

  String _newCookie() {
    _counter++;
    currentCookie = 'rt-$_counter';
    return currentCookie!;
  }

  /// A client for one tab: the browser attaches the jar's cookie when it sends.
  http.Client clientForTab() => MockClient((request) async {
        final path = request.url.path;
        seenClientHeader.add(request.headers['X-DevLink-Client']);

        if (path == '/api/Auth/session/refresh') {
          refreshCalls++;
          final presented = jar.refreshCookie; // read at send time
          await Future<void>.delayed(refreshDelay);

          if (revoked || presented == null) {
            return _problem(401, 'SESSION_REVOKED', 'For your security, you were signed out. Please sign in again.');
          }
          if (spent.contains(presented)) {
            reuseDetected = true;
            revoked = true;
            return _problem(401, 'SESSION_REVOKED', 'For your security, you were signed out. Please sign in again.');
          }
          if (presented != currentCookie) {
            return _problem(401, 'SESSION_EXPIRED', 'Your session has expired. Please sign in again.');
          }

          spent.add(presented);
          rotations++;
          jar.refreshCookie = _newCookie();
          validAccessToken = 'at-$rotations';
          return http.Response(
            jsonEncode({
              'userId': 1,
              'role': 'Customer',
              'status': 'Active',
              'accessToken': validAccessToken,
              'accessTokenExpiresAt': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
            }),
            200,
          );
        }

        final auth = request.headers['Authorization'];
        if (auth != null) seenAuthorization.add(auth);

        if (path == '/api/Posts/upload') {
          if (auth != 'Bearer $validAccessToken') {
            return _problem(401, 'TOKEN_EXPIRED', 'Your session has expired.');
          }
          uploads.add(utf8.decode(request.bodyBytes));
          return http.Response('{"ok":true}', 200);
        }

        if (auth != 'Bearer $validAccessToken') {
          return _problem(401, 'TOKEN_EXPIRED', 'Your session has expired.');
        }
        return feedOverride?.call() ?? http.Response('{"posts":[]}', 200);
      });

  static http.Response _problem(int status, String code, String message) =>
      http.Response(jsonEncode({'status': status, 'errorCode': code, 'message': message}), status);
}

/// Web Locks stand-in: one lock for every tab; holders take turns.
class SharedLock implements RefreshLock {
  Future<void> _tail = Future<void>.value();
  int grants = 0;

  @override
  bool get isSupported => true;

  @override
  Future<T> run<T>(Future<T> Function() action, {required Duration wait}) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return previous.then((_) async {
      grants++;
      try {
        return await action();
      } finally {
        released.complete();
      }
    });
  }
}

/// No coordination at all (what a browser without the lock would do if the app refreshed anyway).
class NoLock implements RefreshLock {
  @override
  bool get isSupported => true;

  @override
  Future<T> run<T>(Future<T> Function() action, {required Duration wait}) => action();
}

class UnsupportedLock implements RefreshLock {
  @override
  bool get isSupported => false;

  @override
  Future<T> run<T>(Future<T> Function() action, {required Duration wait}) =>
      Future<T>.error(const LockUnsupportedException());
}

/// Another tab holds the lock and never lets go.
class NeverGrantedLock implements RefreshLock {
  @override
  bool get isSupported => true;

  @override
  Future<T> run<T>(Future<T> Function() action, {required Duration wait}) async {
    await Future<void>.delayed(wait);
    throw const LockTimeoutException();
  }
}

AuthHttp tab(FakeApi api, RefreshLock lock, {String expiredToken = 'at-0'}) {
  final client = AuthHttp(
    client: api.clientForTab(),
    lock: lock,
    baseUrl: base,
    clientHeader: 'web',
    lockWait: const Duration(milliseconds: 50),
  );
  // Both tabs hold an access token the server no longer accepts.
  client.setSessionFromJson({
    'accessToken': expiredToken,
    'accessTokenExpiresAt': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
  });
  return client;
}

void main() {
  group('cross-tab refresh (T-MT)', () {
    test('T-MT-01: two tabs, one lock: two rotations in turn, no reuse, both requests succeed', () async {
      final api = FakeApi(CookieJar());
      final lock = SharedLock();
      final tabA = tab(api, lock);
      final tabB = tab(api, lock);

      final results = await Future.wait([tabA.get(feed), tabB.get(feed)]);

      expect(results.map((r) => r.statusCode), everyElement(200));
      expect(api.reuseDetected, isFalse);
      expect(api.rotations, 2);
      expect(api.refreshCalls, 2);
      expect(lock.grants, 2);
    });

    test('T-MT-02: the same two tabs without the lock send one cookie twice and the server sees reuse', () async {
      final api = FakeApi(CookieJar());
      final tabA = tab(api, NoLock());
      final tabB = tab(api, NoLock());
      var ended = 0;
      tabA.onSessionEnded = (_) => ended++;
      tabB.onSessionEnded = (_) => ended++;

      await Future.wait([tabA.get(feed), tabB.get(feed)]);

      expect(api.reuseDetected, isTrue);
      expect(ended, greaterThanOrEqualTo(1));
    });

    test('T-MT-03: 20 parallel 401s in one tab give exactly one refresh, then every request succeeds', () async {
      final api = FakeApi(CookieJar());
      final client = tab(api, SharedLock());

      final results = await Future.wait(List.generate(20, (_) => client.get(feed)));

      expect(api.refreshCalls, 1);
      expect(results.map((r) => r.statusCode), everyElement(200));
    });

    test('T-MT-04: without Web Locks the app sends no session call and signing in is refused', () async {
      final api = FakeApi(CookieJar());
      final client = tab(api, UnsupportedLock());
      String? endedWith;
      client.onSessionEnded = (m) => endedWith = m;

      final refresh = await client.refresh();
      expect(refresh.outcome, RefreshOutcome.unsupported);

      final response = await client.get(feed);
      expect(response.statusCode, 401);
      expect(api.refreshCalls, 0);
      expect(endedWith, isNotNull);
      expect(client.hasSession, isFalse);

      final previous = AuthHttp.instance;
      AuthHttp.instance = client;
      addTearDown(() => AuthHttp.instance = previous);
      final login = await ApiService.login(email: 'a@example.test', password: 'x', userType: 'Customer');
      expect(login.success, isFalse);
      expect(login.errorCode, 'UNSUPPORTED_BROWSER');
      expect(api.seenClientHeader, hasLength(1)); // only the feed call above; no login request
    });

    test('T-MT-05: the lock is not granted in time: signed out, no refresh sent', () async {
      final api = FakeApi(CookieJar());
      final client = tab(api, NeverGrantedLock());
      String? endedWith;
      client.onSessionEnded = (m) => endedWith = m;

      final response = await client.get(feed);

      expect(response.statusCode, 401);
      expect(api.refreshCalls, 0);
      expect(endedWith, AuthHttp.lockTimeoutMessage);
      expect(client.hasSession, isFalse);
    });
  });

  group('responses that end or restrict the session', () {
    test('403 ACCOUNT_SUSPENDED is reported and the session is kept', () async {
      final api = FakeApi(CookieJar());
      final client = tab(api, SharedLock(), expiredToken: 'at-0');
      api.validAccessToken = 'at-0';
      api.feedOverride = () => FakeApi._problem(403, 'ACCOUNT_SUSPENDED', 'Your account is suspended.');
      var suspended = 0;
      client.onSuspended = () => suspended++;

      final response = await client.get(feed);

      expect(response.statusCode, 403);
      expect(suspended, 1);
      expect(client.hasSession, isTrue);
      expect(api.refreshCalls, 0);
    });

    test('another 403 is left to the caller: no suspended screen, no refresh, session kept', () async {
      final api = FakeApi(CookieJar());
      final client = tab(api, SharedLock());
      api.validAccessToken = 'at-0';
      api.feedOverride = () => FakeApi._problem(403, 'FORBIDDEN', "You can't do that.");
      var suspended = 0;
      var ended = 0;
      client.onSuspended = () => suspended++;
      client.onSessionEnded = (_) => ended++;

      final response = await client.get(feed);

      expect(response.statusCode, 403);
      expect(suspended, 0);
      expect(ended, 0);
      expect(client.hasSession, isTrue);
      expect(api.refreshCalls, 0);
    });

    test('a revoked session: the one refresh fails and the session ends with the server message', () async {
      final api = FakeApi(CookieJar())..revoked = true;
      final client = tab(api, SharedLock());
      final messages = <String>[];
      client.onSessionEnded = messages.add;

      await Future.wait([client.get(feed), client.get(feed), client.get(feed)]);

      expect(api.refreshCalls, 1);
      expect(messages, ['For your security, you were signed out. Please sign in again.']);
      expect(client.hasSession, isFalse);
    });

    test('a refresh the server cannot answer keeps the session (no sign-out on a network problem)', () async {
      final client = AuthHttp(
        client: MockClient((request) async {
          if (request.url.path == '/api/Auth/session/refresh') {
            throw http.ClientException('offline');
          }
          return FakeApi._problem(401, 'TOKEN_EXPIRED', 'Your session has expired.');
        }),
        lock: SharedLock(),
        baseUrl: base,
        clientHeader: 'web',
      )..setSessionFromJson({'accessToken': 'at-0'});
      var ended = 0;
      client.onSessionEnded = (_) => ended++;

      final response = await client.get(feed);

      expect(response.statusCode, 401);
      expect(ended, 0);
      expect(client.hasSession, isTrue);
    });
  });

  group('requests', () {
    test('API requests carry the Bearer token and X-DevLink-Client; other hosts get neither', () async {
      final seen = <Uri, Map<String, String>>{};
      final client = AuthHttp(
        client: MockClient((request) async {
          seen[request.url] = request.headers;
          return http.Response('{}', 200);
        }),
        lock: SharedLock(),
        baseUrl: base,
        clientHeader: 'web',
      )..setSessionFromJson({'accessToken': 'at-7'});

      final other = Uri.parse('https://example.test/x');
      await client.get(feed);
      await client.get(other);

      expect(seen[feed]!['Authorization'], 'Bearer at-7');
      expect(seen[feed]!['X-DevLink-Client'], 'web');
      expect(seen[other]!.containsKey('Authorization'), isFalse);
      expect(seen[other]!.containsKey('X-DevLink-Client'), isFalse);
    });

    test('a 401 from login is an answer, not a reason to refresh', () async {
      final api = FakeApi(CookieJar());
      final client = AuthHttp(
        client: MockClient((request) async => FakeApi._problem(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect.')),
        lock: SharedLock(),
        baseUrl: base,
        clientHeader: 'web',
      );
      var ended = 0;
      client.onSessionEnded = (_) => ended++;

      final response = await client.post(Uri.parse('$base/api/Auth/login'), body: '{}');

      expect(response.statusCode, 401);
      expect(ended, 0);
      expect(api.refreshCalls, 0);
    });

    test('a multipart upload is sent again after the refresh, with the same body', () async {
      final api = FakeApi(CookieJar());
      final client = tab(api, SharedLock());

      final request = MultipartRequest('POST', Uri.parse('$base/api/Posts/upload'))..fields['content'] = 'hello-upload';
      final streamed = await client.send(request);
      final response = await Response.fromStream(streamed);

      expect(response.statusCode, 200);
      expect(api.refreshCalls, 1);
      expect(api.uploads.single, contains('hello-upload'));
    });

    test('a token about to expire is refreshed before the request', () async {
      final api = FakeApi(CookieJar());
      final client = AuthHttp(client: api.clientForTab(), lock: SharedLock(), baseUrl: base, clientHeader: 'web')
        ..setSessionFromJson({
          'accessToken': 'at-0',
          'accessTokenExpiresAt': DateTime.now().toUtc().add(const Duration(seconds: 5)).toIso8601String(),
        });

      final response = await client.get(feed);

      expect(response.statusCode, 200);
      expect(api.refreshCalls, 1);
      expect(api.seenAuthorization, ['Bearer at-1']); // never sent the old token
    });
  });

  test('no token is ever written to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    const secret = 'secret-access-token-123';
    final previous = AuthHttp.instance;
    AuthHttp.instance = AuthHttp(
      client: MockClient((request) async {
        if (request.url.path == '/api/Auth/login') {
          return http.Response(
            jsonEncode({
              'userId': 5,
              'userType': 'Customer',
              'email': 'c@example.test',
              'hasProfile': true,
              'accessToken': secret,
              'accessTokenExpiresAt': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
              'status': 'Active',
            }),
            200,
          );
        }
        if (request.url.path == '/api/Auth/session/refresh') {
          return http.Response(jsonEncode({'userId': 5, 'role': 'Customer', 'accessToken': '$secret-2'}), 200);
        }
        return http.Response('{}', 200);
      }),
      lock: SharedLock(),
      baseUrl: base,
      clientHeader: 'web',
    );
    addTearDown(() => AuthHttp.instance = previous);

    final login = await ApiService.login(email: 'c@example.test', password: 'pw', userType: 'Customer');
    expect(login.success, isTrue);
    await ApiService.saveSignedInUser(login.data!);
    await AuthHttp.instance.refresh();
    expect(AuthHttp.instance.accessToken, '$secret-2');

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getKeys().map((k) => '${prefs.get(k)}').join('|');
    expect(stored, isNot(contains(secret)));
    expect(prefs.getKeys(), isNot(contains('accessToken')));
    expect(prefs.getInt('userId'), 5);
  });
}
