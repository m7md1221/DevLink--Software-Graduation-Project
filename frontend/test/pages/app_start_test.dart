// M2.12-lite (F5): start-up restores the session through the refresh cookie.
import 'dart:convert';

import 'package:devlink/pages/Common/account_suspended_page.dart';
import 'package:devlink/pages/Common/app_start_page.dart';
import 'package:devlink/pages/Common/welcome_page.dart';
import 'package:devlink/services/auth_http.dart' show AuthHttp;
import 'package:devlink/services/http/refresh_lock_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthHttp previous;

  setUp(() {
    previous = AuthHttp.instance;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => AuthHttp.instance = previous);

  void useServer(Future<http.Response> Function(http.Request) handler) {
    AuthHttp.instance = AuthHttp(
      client: MockClient(handler),
      lock: SingleProcessRefreshLock(),
      baseUrl: 'http://localhost:5133',
      clientHeader: 'web',
    );
  }

  testWidgets('a suspended account goes straight to the suspended screen with its reason', (tester) async {
    useServer((request) async {
      switch (request.url.path) {
        case '/api/Auth/session/refresh':
          return http.Response(jsonEncode({'userId': 9, 'role': 'Customer', 'status': 'Suspended', 'accessToken': 'at-1'}), 200);
        case '/api/Auth/me':
          return http.Response(
              jsonEncode({
                'userId': 9,
                'role': 'Customer',
                'email': 's@example.test',
                'status': 'Suspended',
                'suspendedReason': 'Spam reports',
                'hasProfile': true,
              }),
              200);
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: AppStartPage()));
    await tester.pumpAndSettle();

    expect(find.byType(AccountSuspendedPage), findsOneWidget);
    expect(find.text('Your account is suspended'), findsOneWidget);
    expect(find.text('Reason: Spam reports'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });

  testWidgets('no refresh cookie: the welcome page, with no other request', (tester) async {
    final paths = <String>[];
    useServer((request) async {
      paths.add(request.url.path);
      return http.Response(jsonEncode({'errorCode': 'SESSION_EXPIRED', 'message': 'Your session has expired.'}), 401);
    });

    await tester.pumpWidget(const MaterialApp(home: AppStartPage()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(paths, ['/api/Auth/session/refresh']);
  });
}
