import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../Customer/contact_support_page.dart';
import '../Customer/customer_support_messages_page.dart';
import 'welcome_page.dart';

/// Shown when the account is suspended (M2_AUTH_DESIGN §7.4, F11). The API then
/// allows only the suspension notice, support and sign-out, so this screen offers
/// exactly those.
class AccountSuspendedPage extends StatefulWidget {
  const AccountSuspendedPage({super.key});

  @override
  State<AccountSuspendedPage> createState() => _AccountSuspendedPageState();
}

class _AccountSuspendedPageState extends State<AccountSuspendedPage> {
  bool _loading = true;
  String? _reason;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await ApiService.me();
    final storedId = await SessionManager.getUserId();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _reason = me.data?['suspendedReason'] as String?;
      _userId = (me.data?['userId'] as int?) ?? storedId;
    });
  }

  Future<void> _signOut() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final userId = _userId;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.block_rounded, size: 48, color: scheme.error),
                            const SizedBox(height: 16),
                            Text(
                              'Your account is suspended',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'While it is suspended you can contact support or sign out. '
                              'Everything else in DevLink is unavailable.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (_reason != null && _reason!.trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Reason: ${_reason!.trim()}',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (userId != null) ...[
                              FilledButton.icon(
                                onPressed: () => _open(ContactSupportPage(userId: userId)),
                                icon: const Icon(Icons.support_agent_rounded),
                                label: const Text('Contact support'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _open(CustomerSupportMessagesPage(userId: userId)),
                                icon: const Icon(Icons.forum_outlined),
                                label: const Text('My support conversations'),
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Sign out'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
