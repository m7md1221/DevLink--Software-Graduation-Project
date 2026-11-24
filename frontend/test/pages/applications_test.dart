import 'dart:convert';

import 'package:devlink/pages/Customer/compare_applicants_page.dart';
import 'package:devlink/pages/Programmer/project_apply_page.dart';
import 'package:devlink/services/auth_http.dart' show AuthHttp;
import 'package:devlink/services/http/refresh_lock_io.dart';
import 'package:devlink/services/project_service.dart';
import 'package:devlink/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _project = <String, dynamic>{
  'title': 'Booking site for a salon',
  'budgetMin': 300,
  'budgetMax': 500,
  'framework': null,
  'criteria': [
    {'id': 11, 'order': 1, 'text': 'A customer can book a slot from a phone.'},
    {'id': 12, 'order': 2, 'text': 'The salon gets a message for every booking.'},
  ],
};

Map<String, dynamic> _applicant(int id, String name, int willMeet, int clarify) => {
      'applicationId': id,
      'programmerId': id,
      'programmerName': name,
      'status': 'Pending',
      'submittedAt': '2026-11-24T16:00:00',
      'amount': 400,
      'durationDays': 14,
      'coverage': {'willMeet': willMeet, 'needsClarification': clarify, 'proposeChange': 0, 'total': 2},
      'rating': null,
      'isVerified': id == 1,
    };

void main() {
  late AuthHttp previous;
  final requested = <Uri>[];

  setUp(() {
    previous = AuthHttp.instance;
    requested.clear();
    AuthHttp.instance = AuthHttp(
      client: MockClient((request) async {
        requested.add(request.url);
        if (request.url.path.endsWith('/applicants')) {
          final rows = request.url.queryParameters['sort'] == 'coverage'
              ? [_applicant(2, 'Hala', 2, 0), _applicant(1, 'Yousef', 1, 1)]
              : [_applicant(1, 'Yousef', 1, 1), _applicant(2, 'Hala', 2, 0)];
          return http.Response(jsonEncode({'applicants': rows}), 200);
        }
        return http.Response('{}', 200);
      }),
      lock: SingleProcessRefreshLock(),
      baseUrl: 'http://localhost:5133',
      clientHeader: 'web',
    );
  });

  tearDown(() => AuthHttp.instance = previous);

  test('coverage reads like "5 will meet · 1 clarify"', () {
    expect(coverageLabel({'willMeet': 5, 'needsClarification': 1, 'proposeChange': 0}), '5 will meet · 1 clarify');
    expect(coverageLabel({'willMeet': 2, 'needsClarification': 0, 'proposeChange': 1}), '2 will meet · 1 change');
  });

  testWidgets('the apply form stays on the requirements until every one is answered', (tester) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: ProjectApplyPage(projectId: 5, project: _project)));

    await tester.tap(find.text('Will meet').first);
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Choose an answer for requirement 2.'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);

    // "Needs clarification" asks for a note before moving on.
    await tester.tap(find.text('Needs clarification').last);
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Add a note of at least 5 characters.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Which phones matter?');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Your approach'), findsOneWidget);
  });

  testWidgets('the comparison starts oldest first and sorts by coverage on request', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const CompareApplicantsPage(projectId: 5, projectTitle: 'Booking site', currentUserId: 9),
    ));
    await tester.pumpAndSettle();

    expect(requested.last.queryParameters['sort'], 'submitted');
    expect(requested.last.queryParameters['dir'], 'asc');
    expect(find.text('1 will meet · 1 clarify'), findsOneWidget);
    // The column header plus one chip: only the server-verified applicant gets it.
    expect(find.text('Verified'), findsNWidgets(2));

    await tester.tap(find.text('Requirements'));
    await tester.pumpAndSettle();
    expect(requested.last.queryParameters['sort'], 'coverage');
    expect(requested.last.queryParameters['dir'], 'desc');
    final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d == 'Hala' || d == 'Yousef').toList();
    expect(names, ['Hala', 'Yousef']);
  });
}
