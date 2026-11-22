import 'package:flutter/material.dart';

import '../pages/Common/welcome_page.dart';
import '../services/api_service.dart';

enum _SignOutChoice { thisDevice, everywhere }

/// Sign out of this device, or of every device (logout-all), then return to the
/// welcome page. Used by every dashboard's sign-out button (M2.12, F10).
Future<void> showSignOutDialog(BuildContext context) async {
  final choice = await showDialog<_SignOutChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out'),
      content: const Text('Sign out of DevLink on this device, or on every device where you are signed in?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, _SignOutChoice.everywhere),
          child: const Text('All devices'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _SignOutChoice.thisDevice),
          child: const Text('This device'),
        ),
      ],
    ),
  );

  if (choice == null) return;

  if (choice == _SignOutChoice.everywhere) {
    await ApiService.logoutAll();
  } else {
    await ApiService.logout();
  }

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const WelcomePage()),
    (route) => false,
  );
}
