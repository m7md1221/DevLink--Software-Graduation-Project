import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInButton extends StatelessWidget {
  final Function(String idToken) onIdToken;
  final Color accentColor;

  const GoogleSignInButton({
    super.key,
    required this.onIdToken,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return _GoogleButton(
      onIdToken: onIdToken,
      accentColor: accentColor,
    );
  }
}

class _GoogleButton extends StatefulWidget {
  final Function(String idToken) onIdToken;
  final Color accentColor;

  const _GoogleButton({
    required this.onIdToken,
    required this.accentColor,
  });

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _isLoading = false;
  static bool _initialized = false;

  static const String _webClientId =
      '1079791617236-u5pvdnubo7ts41ge29vuethsed3tf8id.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final googleSignIn = GoogleSignIn.instance;

    if (kIsWeb) {
      await googleSignIn.initialize(clientId: _webClientId);
    } else {
      await googleSignIn.initialize(serverClientId: _webClientId);
    }

    _initialized = true;
  }

  Future<void> _handleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _ensureInitialized();

      final googleSignIn = GoogleSignIn.instance;
      final account = await googleSignIn.authenticate();
      final authentication = await account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null) {
        throw Exception('No ID token received');
      }

      widget.onIdToken(idToken);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          side: const BorderSide(
            color: Color(0xFFDADCE0),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF4285F4),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ شعار Google الرسمي من الأصول
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Image.asset(
                      'assets/images/google_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _FallbackGoogleLogo(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3C4043),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================
// Fallback — لو الصورة ما تحملت
// ============================================================
class _FallbackGoogleLogo extends StatelessWidget {
  const _FallbackGoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      alignment: Alignment.center,
      child: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'G',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4285F4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}