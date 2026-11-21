// M2.12-lite: KI-60 (no verified badge on post cards) and KI-56 (no apply on programmer-owned posts).
import 'package:devlink/models/post_model.dart';
import 'package:devlink/pages/Customer/widgets/post_card.dart';
import 'package:devlink/services/auth_http.dart' show AuthHttp;
import 'package:devlink/services/http/refresh_lock_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PostModel post({required String authorType, bool isMine = false}) => PostModel(
      id: 1,
      userId: 2,
      authorName: 'Synthetic Author',
      authorType: authorType,
      content: 'A small website for a bakery',
      createdAt: DateTime.utc(2026, 11, 21),
      imageCount: 0,
      likeCount: 0,
      commentCount: 0,
      applicationsCount: 0,
      isClosed: false,
      isLikedByMe: false,
      isMine: isMine,
      images: const [],
    );

Future<void> pumpCard(WidgetTester tester, PostModel p, {String viewer = 'Customer'}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PostCard(post: p, currentUserId: 3, currentUserType: viewer, onChanged: () {}),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  late AuthHttp previous;

  setUp(() {
    previous = AuthHttp.instance;
    // has-applied: the programmer hasn't applied yet.
    AuthHttp.instance = AuthHttp(
      client: MockClient((_) async => http.Response('{"hasApplied":false}', 200)),
      lock: SingleProcessRefreshLock(),
      baseUrl: 'http://localhost:5133',
      clientHeader: 'web',
    );
  });

  tearDown(() => AuthHttp.instance = previous);

  testWidgets('KI-60: a programmer author gets no verified badge', (tester) async {
    await pumpCard(tester, post(authorType: 'Programmer'));
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('KI-60: a customer author gets no verified badge', (tester) async {
    await pumpCard(tester, post(authorType: 'Customer'));
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });
}
