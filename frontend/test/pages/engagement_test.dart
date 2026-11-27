import 'dart:convert';

import 'package:devlink/pages/Common/engagement_page.dart';
import 'package:devlink/pages/Customer/review_delivery_page.dart';
import 'package:devlink/pages/Programmer/delivery_form_page.dart';
import 'package:devlink/services/auth_http.dart' show AuthHttp;
import 'package:devlink/services/http/refresh_lock_io.dart';
import 'package:devlink/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _engagement({
  String status = 'Active',
  String role = 'programmer',
  int revisionsUsed = 0,
  List<Map<String, dynamic>>? criteria,
  Map<String, bool>? actions,
}) =>
    {
      'id': 7,
      'projectId': 5,
      'projectTitle': 'Booking site for a salon',
      'status': status,
      'role': role,
      'customerName': 'Salon Owner',
      'programmerName': 'Yousef',
      'agreedAmount': 400,
      'deadlineAt': '2026-12-10T10:00:00',
      'createdAt': '2026-11-27T10:00:00',
      'revisionsUsed': revisionsUsed,
      'maxRevisions': 2,
      'criteriaTotal': 2,
      'criteriaAccepted': (criteria ?? []).where((c) => c['status'] == 'Accepted').length,
      'criteriaMet': null,
      'cancellation': null,
      'criteria': criteria ??
          [
            {'id': 11, 'order': 1, 'text': 'A customer can book a slot from a phone.', 'status': 'Open'},
            {'id': 12, 'order': 2, 'text': 'The salon gets a message for every booking.', 'status': 'Open'},
          ],
      'deliveries': [
        {'round': 1, 'note': 'Ready on staging.'}
      ],
      'timeline': [
        {'type': 'Started', 'message': 'Application accepted and work started.', 'actorName': 'Salon Owner', 'createdAt': '2026-11-27T10:00:00'}
      ],
      'actions': actions ?? {'canDeliver': true, 'canRequestCancellation': true},
    };

void main() {
  late AuthHttp previous;
  final sent = <Map<String, dynamic>>[];
  Map<String, dynamic> served = _engagement();

  setUp(() {
    previous = AuthHttp.instance;
    sent.clear();
    AuthHttp.instance = AuthHttp(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'message': 'Your delivery was submitted.'}), 200);
        }
        return http.Response(jsonEncode(served), 200);
      }),
      lock: SingleProcessRefreshLock(),
      baseUrl: 'http://localhost:5133',
      clientHeader: 'web',
    );
  });

  tearDown(() => AuthHttp.instance = previous);

  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the engagement page shows progress, the checklist and the role actions', (tester) async {
    wide(tester);
    served = _engagement(criteria: [
      {'id': 11, 'order': 1, 'text': 'A customer can book a slot from a phone.', 'status': 'Accepted'},
      {'id': 12, 'order': 2, 'text': 'The salon gets a message for every booking.', 'status': 'NeedsRevision', 'reviewNote': 'No message arrived.'},
    ], revisionsUsed: 1);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const EngagementPage(engagementId: 7)));
    await tester.pumpAndSettle();

    expect(find.text('1/2 accepted'), findsOneWidget);
    expect(find.text('Needs revision'), findsOneWidget);
    expect(find.text('Customer: No message arrived.'), findsOneWidget);
    expect(find.text('Submit revised delivery'), findsOneWidget);
    expect(find.text('Review delivery'), findsNothing);
    expect(find.text('Request cancellation'), findsOneWidget);
  });

  testWidgets('a delivery is blocked until every requirement has an answer and evidence', (tester) async {
    wide(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DeliveryFormPage(engagement: _engagement())));

    await tester.tap(find.text('Met').first);
    await tester.enterText(find.byType(TextField).at(0), 'https://staging.example.test/book');
    await tester.enterText(find.byType(TextField).last, 'Deployed to staging.');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit delivery'));
    await tester.pump();
    expect(find.text('Answer requirement 2.'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.tap(find.text('Not met').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit delivery'));
    await tester.pump();
    expect(find.text('Requirement 2: add evidence of 5–500 characters, such as a note or a link.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'The SMS provider needs the salon account.');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit delivery'));
    await tester.pumpAndSettle();
    expect(sent.single['items'], [
      {'criterionId': 11, 'claim': 'Met', 'evidence': 'https://staging.example.test/book'},
      {'criterionId': 12, 'claim': 'NotMet', 'evidence': 'The SMS provider needs the salon account.'},
    ]);
  });

  testWidgets('the review needs a waiver for a not-met requirement and a note for a revision', (tester) async {
    wide(tester);
    final e = _engagement(role: 'customer', status: 'Delivered', actions: {
      'canReview': true,
      'canRequestRevision': true
    }, criteria: [
      {
        'id': 11,
        'order': 1,
        'text': 'A customer can book a slot from a phone.',
        'status': 'InReview',
        'claim': 'Met',
        'evidence': 'https://x.example.test'
      },
      {
        'id': 12,
        'order': 2,
        'text': 'The salon gets a message for every booking.',
        'status': 'InReview',
        'claim': 'NotMet',
        'evidence': 'Needs the account.'
      },
    ]);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: ReviewDeliveryPage(engagement: e)));

    await tester.tap(find.text('Accept').at(0));
    await tester.tap(find.text('Accept').at(1));
    await tester.pump();
    await tester.tap(find.text('Send review'));
    await tester.pump();
    expect(find.text('Requirement 2 was marked not met. Confirm the waiver to accept it.'), findsOneWidget);

    await tester.tap(find.text('Needs revision').last);
    await tester.pump();
    await tester.tap(find.text('Send review'));
    await tester.pump();
    expect(find.text('Requirement 2: explain what needs revision in 5–500 characters.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Please connect a test SMS account.');
    await tester.tap(find.text('Send review'));
    await tester.pumpAndSettle();
    expect(
        (sent.single['items'] as List).last, {'criterionId': 12, 'decision': 'Revise', 'note': 'Please connect a test SMS account.', 'waive': false});
  });

  testWidgets('with no revision rounds left the revision choice is disabled', (tester) async {
    wide(tester);
    final e = _engagement(role: 'customer', status: 'Delivered', revisionsUsed: 2, actions: {
      'canReview': true,
      'canRequestRevision': false
    }, criteria: [
      {
        'id': 11,
        'order': 1,
        'text': 'A customer can book a slot from a phone.',
        'status': 'InReview',
        'claim': 'Met',
        'evidence': 'https://x.example.test'
      },
    ]);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: ReviewDeliveryPage(engagement: e)));

    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Needs revision'));
    expect(chip.onSelected, isNull);
    expect(find.textContaining('No revision rounds are left.'), findsOneWidget);
  });
}
