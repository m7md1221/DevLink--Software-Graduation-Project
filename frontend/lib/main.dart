import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'pages/Common/account_suspended_page.dart';
import 'pages/Common/app_start_page.dart';
import 'pages/Common/welcome_page.dart';
import 'services/auth_http.dart' show AuthHttp;
import 'services/session_manager.dart';

final ThemeManager themeManager = ThemeManager();

/// Lets the auth layer leave any screen when the session ends or the account is
/// suspended (M2.12, F5).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

bool _showingSuspended = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeManager.loadTheme();
  _wireSessionEvents();
  runApp(const DevLinkApp());
}

void _wireSessionEvents() {
  AuthHttp.instance.onSessionEnded = (message) async {
    await SessionManager.clear();
    _showingSuspended = false;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  };

  AuthHttp.instance.onSuspended = () {
    if (_showingSuspended) return;
    _showingSuspended = true;
    navigatorKey.currentState
        ?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AccountSuspendedPage()),
          (route) => false,
        )
        .whenComplete(() => _showingSuspended = false);
  };
}

// كلاس بيمنع السكرول بار من إنه يظهر نهائياً
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // هنا بنمنع الشريط
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // نمنع تأثير الـ Glow كمان
  }
}

class DevLinkApp extends StatefulWidget {
  const DevLinkApp({super.key});

  @override
  State<DevLinkApp> createState() => _DevLinkAppState();
}

class _DevLinkAppState extends State<DevLinkApp> {
  @override
  void initState() {
    super.initState();
    themeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: MaterialApp(
        title: 'DevLink',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeManager.themeMode,
        home: const AppStartPage(),
      ),
    );
  }
}
