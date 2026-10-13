import 'package:flutter_test/flutter_test.dart';
import 'package:devlink/main.dart';

void main() {
  testWidgets('DevLink app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const DevLinkApp());

    // نستنى الـ animations تخلص (الـ controller مدته 8 ثواني)
    await tester.pump(const Duration(seconds: 9));

    // الأزرار الثلاثة
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Programmer'), findsOneWidget);

    // عنوان الترحيب (مقسوم على Textين)
    expect(find.text('Welcome to '), findsOneWidget);
    expect(find.text('DevLink'), findsOneWidget);

    // زر Sign Up
    expect(find.text('Sign Up'), findsOneWidget);
  });
}