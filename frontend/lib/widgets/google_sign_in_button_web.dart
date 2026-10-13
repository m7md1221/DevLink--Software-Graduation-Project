import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only; // ✅ الاستيراد الصحيح

Widget buildGoogleButton({
  required Function(String idToken) onIdToken,
  required Color accentColor,
}) {
  return _WebGoogleButton(onIdToken: onIdToken);
}

class _WebGoogleButton extends StatefulWidget {
  final Function(String idToken) onIdToken;
  const _WebGoogleButton({required this.onIdToken});

  @override
  State<_WebGoogleButton> createState() => _WebGoogleButtonState();
}

class _WebGoogleButtonState extends State<_WebGoogleButton> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // ✅ التهيئة قبل عرض الزر
    await GoogleSignIn.instance.initialize(
      clientId: '1079791617236-u5pvdnubo7ts41ge29vuethsed3tf8id.apps.googleusercontent.com',
    );

    if (!mounted) return;

    // ✅ الاستماع لحدث تسجيل الدخول (مع التحقق من النوع)
    GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final idToken = event.user.authentication.idToken;
        if (idToken != null) {
          widget.onIdToken(idToken);
        }
      }
    });

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox(
        width: double.infinity,
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ استخدام web_only.renderButton (مع الاسم المستعار)
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: web_only.renderButton(
        configuration: web_only.GSIButtonConfiguration(
          type: web_only.GSIButtonType.standard,
          theme: web_only.GSIButtonTheme.outline,
          size: web_only.GSIButtonSize.large,
          text: web_only.GSIButtonText.continueWith,
          shape: web_only.GSIButtonShape.rectangular,
          logoAlignment: web_only.GSIButtonLogoAlignment.left,
          minimumWidth: 300,
        ),
      ),
    );
  }
}