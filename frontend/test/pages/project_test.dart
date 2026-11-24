import 'dart:convert';

import 'package:devlink/models/post_model.dart';
import 'package:devlink/pages/Customer/new_project_page.dart';
import 'package:devlink/pages/Customer/widgets/post_card.dart';
import 'package:devlink/services/auth_http.dart' show AuthHttp;
import 'package:devlink/services/http/refresh_lock_io.dart';
import 'package:devlink/services/project_service.dart';
import 'package:devlink/theme/app_theme.dart';
import 'package:devlink/widgets/dl/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PostModel _post({required bool isProject}) => PostModel(
      id: 7,
      userId: 2,
      authorName: 'Synthetic Customer',
      authorType: 'Customer',
      content: 'Clients call to book, and two people sometimes get the same slot.',
      createdAt: DateTime.utc(2026, 11, 24),
      imageCount: 0,
      likeCount: 0,
      commentCount: 0,
      applicationsCount: 0,
      isClosed: false,
      isLikedByMe: false,
      isMine: false,
      images: const [],
      isProject: isProject,
      title: isProject ? 'Booking site for a salon' : null,
      budgetMin: isProject ? 300 : null,
      budgetMax: isProject ? 500 : null,
      deadlineDays: isProject ? 18 : null,
      criteriaCount: isProject ? 3 : 0,
    );

// Readiness answers like the API: blocking until there are 3 criteria.
http.Response _readiness(http.Request request) {
  final criteria = (jsonDecode(request.body)['criteria'] as List).length;
  final blocking = criteria < 3
      ? [
          {'code': 'TOO_FEW_CRITERIA', 'field': 'criteria', 'message': 'Add at least 3 acceptance criteria.'}
        ]
      : [];
  return http.Response(
    jsonEncode({
      'readiness': {'ready': blocking.isEmpty, 'score': 100 - 10 * blocking.length, 'blocking': blocking, 'warnings': []},
      'errors': {},
    }),
    200,
  );
}

void main() {
  late AuthHttp previous;

  setUp(() {
    previous = AuthHttp.instance;
    AuthHttp.instance = AuthHttp(
      client: MockClient((request) async => request.url.path.endsWith('/api/Projects/readiness')
          ? _readiness(request)
          : http.Response('{"hasApplied":false}', 200)),
      lock: SingleProcessRefreshLock(),
      baseUrl: 'http://localhost:5133',
      clientHeader: 'web',
    );
  });

  tearDown(() => AuthHttp.instance = previous);

  Future<void> pumpCard(WidgetTester tester, PostModel p) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: PostCard(post: p, currentUserId: 3, currentUserType: 'Programmer', onChanged: () {})),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a project card shows its title and requirement count', (tester) async {
    await pumpCard(tester, _post(isProject: true));
    expect(find.text('Booking site for a salon'), findsOneWidget);
    expect(find.textContaining('3 requirements'), findsOneWidget);
    expect(find.textContaining('\$300–500'), findsOneWidget);
    expect(find.text('View project'), findsOneWidget);
  });

  testWidgets('a social post shows no requirement count', (tester) async {
    await pumpCard(tester, _post(isProject: false));
    expect(find.textContaining('requirement'), findsNothing);
    expect(find.text('View project'), findsNothing);
  });

  Future<void> fillWizard(WidgetTester tester, int criteria) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const NewProjectPage(userId: 3)));
    await tester.enterText(find.byType(TextField).first, 'Booking site for a salon');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Clients call to book, and two people sometimes get the same time slot.');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    for (var i = 0; i < criteria; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'Requirement number ${i + 1} can be checked.');
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '300');
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit for review'));

  testWidgets('the wizard blocks submission with 2 criteria', (tester) async {
    await fillWizard(tester, 2);
    expect(find.text('Add at least 3 acceptance criteria.'), findsOneWidget);
    expect(find.text('Not ready yet'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('the wizard allows submission with 3 criteria', (tester) async {
    await fillWizard(tester, 3);
    expect(find.text('Ready to submit'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('the readiness panel lists blocking issues and warnings separately', (tester) async {
    const readiness = Readiness(
      ready: false,
      score: 86,
      blocking: [ReadinessIssue('BUDGET_INVALID', 'budget', 'Enter a budget above 0.')],
      warnings: [ReadinessIssue('VAGUE_CRITERION', 'criteria[0]', 'Criterion 1 uses "nice".')],
    );
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: DLReadinessPanel(readiness: readiness))));
    expect(find.text('Fix before submitting'), findsOneWidget);
    expect(find.text('Worth improving'), findsOneWidget);
    expect(find.textContaining('86/100'), findsOneWidget);
  });
}
