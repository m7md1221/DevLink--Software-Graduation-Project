import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_http.dart' show AuthHttp;
import '../Customer/customer_home_page.dart';
import '../Programmer/programmer_dashboard_page.dart';
import '../Programmer/programmer_profile_setup_page.dart';
import '../admin/admin_dashboard_page.dart';
import 'account_suspended_page.dart';
import 'welcome_page.dart';

/// The home screen for a signed-in user, by the role the server reports.
Widget homeForSignedInUser({
  required String userType,
  required int userId,
  required bool hasProfile,
  required String email,
}) {
  switch (userType) {
    case 'Customer':
      return CustomerHomePage(userId: userId, authorName: email, authorType: 'Customer');
    case 'Programmer':
      return hasProfile ? ProgrammerDashboardPage(userId: userId) : ProgrammerProfileSetupPage(userId: userId);
    case 'Admin':
      return AdminDashboardPage(userId: userId);
    default:
      return const WelcomePage();
  }
}

/// Start-up (M2.12, F5): the access token is only in memory, so after a reload the
/// app asks the API for a new one with the HttpOnly refresh cookie. Signed in →
/// the role's home, or the suspended screen; otherwise the welcome page.
class AppStartPage extends StatefulWidget {
  const AppStartPage({super.key});

  @override
  State<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends State<AppStartPage> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    Widget next = const WelcomePage();

    final refreshed = await AuthHttp.instance.refresh();
    if (refreshed.ok) {
      final me = await ApiService.me();
      final data = me.data;
      if (me.success && data != null) {
        await ApiService.saveSignedInUser(data);
        final userType = (data['role'] ?? '') as String;
        next = data['status'] == 'Suspended'
            ? const AccountSuspendedPage()
            : homeForSignedInUser(
                userType: userType,
                userId: (data['userId'] ?? 0) as int,
                hasProfile: userType == 'Programmer'
                    ? (data['hasProgrammerProfile'] ?? false) as bool
                    : (data['hasProfile'] ?? false) as bool,
                email: (data['email'] ?? '') as String,
              );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
