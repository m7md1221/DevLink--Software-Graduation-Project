import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:devlink/main.dart';
import 'package:devlink/services/auth_http.dart' show AuthHttp;
import 'package:devlink/services/http/refresh_lock_io.dart';

void main() {
  testWidgets('DevLink app loads', (WidgetTester tester) async {
    // No refresh cookie: start-up finds no session and shows the welcome page (M2.12).
    AuthHttp.instance = AuthHttp(
      client: MockClient((_) async => http.Response(
          '{"errorCode":"SESSION_EXPIRED","message":"Your session has expired."}', 401)),
      lock: SingleProcessRefreshLock(),
      baseUrl: 'http://localhost:5133',
      clientHeader: 'web',
    );

    await tester.pumpWidget(const DevLinkApp());

    // نستنى الـ animations تخلص (الـ controller مدته 8 ثواني)
    await tester.pump(const Duration(seconds: 9));

    // الأزرار الثلاثة
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Programmer'), findsOneWidget);

    // عنوان الترحيب (مقسوم على Textين)
    // The title is a RichText of TextSpans, which find.text only sees with findRichText (M2.12 fix).
    expect(find.textContaining('Welcome to', findRichText: true), findsOneWidget);
    expect(find.textContaining('DevLink', findRichText: true), findsWidgets);

    // زر Sign Up
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
