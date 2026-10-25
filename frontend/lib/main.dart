import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'pages/Common/welcome_page.dart';

final ThemeManager themeManager = ThemeManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeManager.loadTheme();
  runApp(const DevLinkApp());
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeManager.themeMode,
        home: const WelcomePage(),
      ),
    );
  }
}