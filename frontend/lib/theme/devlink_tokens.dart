import 'package:flutter/material.dart';

/// Mukhatat / Blueprint design tokens (docs/DESIGN_SYSTEM.md §2–§4).
/// Screens should use Theme.of(context).colorScheme and DevLinkColors, never hex values.
class DevLinkTokens {
  DevLinkTokens._();

  // Families (§3). English UI: Plex Sans first, Plex Arabic as fallback, so Arabic
  // names in English screens still render in Plex.
  static const String fontLatin = 'IBMPlexSans';
  static const String fontArabic = 'IBMPlexSansArabic';

  // Radius (§4).
  static const double radiusXs = 4;
  static const double radiusSm = 6; // buttons, inputs, chips, notices
  static const double radiusMd = 8; // cards
  static const double radiusLg = 12; // dialogs, sheets

  // Spacing (§4).
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 48;

  static const double minTouchTarget = 48;
}

/// Colours with a Material role (§2), built explicitly: ColorScheme.fromSeed could
/// shift the tested values.
class DevLinkSchemes {
  DevLinkSchemes._();

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0E5A83),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCECF5),
    onPrimaryContainer: Color(0xFF0A3E5B),
    secondary: Color(0xFF4F5D6B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE9E7E0),
    onSecondaryContainer: Color(0xFF3C4955),
    tertiary: Color(0xFFA0500A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFAEBD9),
    onTertiaryContainer: Color(0xFF6E3706),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBE4E2),
    onErrorContainer: Color(0xFF7E1A15),
    surface: Color(0xFFF7F6F2), // bg
    onSurface: Color(0xFF14273A), // ink
    onSurfaceVariant: Color(0xFF4F5D6B), // muted
    surfaceContainerLowest: Color(0xFFFFFFFF), // surface
    surfaceContainerLow: Color(0xFFFBFAF7),
    surfaceContainer: Color(0xFFF3F2EC),
    surfaceContainerHigh: Color(0xFFEFEDE6), // surface2
    surfaceContainerHighest: Color(0xFFE9E7E0),
    outline: Color(0xFF7D8388), // control
    outlineVariant: Color(0xFFD9D6CC), // line
    inverseSurface: Color(0xFF14273A),
    onInverseSurface: Color(0xFFF7F6F2),
    inversePrimary: Color(0xFF7CC4EA),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7CC4EA),
    onPrimary: Color(0xFF06283C),
    primaryContainer: Color(0xFF123F59),
    onPrimaryContainer: Color(0xFFCFE8F6),
    secondary: Color(0xFFA9B8C4),
    onSecondary: Color(0xFF0F1B26),
    secondaryContainer: Color(0xFF263A4B),
    onSecondaryContainer: Color(0xFFCBD6DE),
    tertiary: Color(0xFFE6AC63),
    onTertiary: Color(0xFF3A2405),
    tertiaryContainer: Color(0xFF43300F),
    onTertiaryContainer: Color(0xFFF6DDBA),
    error: Color(0xFFF2A19B),
    onError: Color(0xFF4A0F0B),
    errorContainer: Color(0xFF4A1D1A),
    onErrorContainer: Color(0xFFFAD7D3),
    surface: Color(0xFF0F1B26),
    onSurface: Color(0xFFEAF0F4),
    onSurfaceVariant: Color(0xFFA9B8C4),
    surfaceContainerLowest: Color(0xFF162533),
    surfaceContainerLow: Color(0xFF182938),
    surfaceContainer: Color(0xFF1B2C3B),
    surfaceContainerHigh: Color(0xFF1E3040),
    surfaceContainerHighest: Color(0xFF263A4B),
    outline: Color(0xFF6F8497),
    outlineVariant: Color(0xFF2C4052),
    inverseSurface: Color(0xFFEAF0F4),
    onInverseSurface: Color(0xFF0F1B26),
    inversePrimary: Color(0xFF0E5A83),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );
}

/// Colours with no Material role (§2): success, warning and neutral chips.
@immutable
class DevLinkColors extends ThemeExtension<DevLinkColors> {
  const DevLinkColors({
    required this.success,
    required this.successC,
    required this.onSuccessC,
    required this.warning,
    required this.warningC,
    required this.onWarningC,
    required this.neutralC,
    required this.onNeutralC,
  });

  final Color success;
  final Color successC;
  final Color onSuccessC;
  final Color warning;
  final Color warningC;
  final Color onWarningC;
  final Color neutralC;
  final Color onNeutralC;

  static const DevLinkColors light = DevLinkColors(
    success: Color(0xFF1A6B45),
    successC: Color(0xFFDDF0E6),
    onSuccessC: Color(0xFF114A30),
    warning: Color(0xFF855000),
    warningC: Color(0xFFFBEBCC),
    onWarningC: Color(0xFF5C3700),
    neutralC: Color(0xFFE9E7E0),
    onNeutralC: Color(0xFF3C4955),
  );

  static const DevLinkColors dark = DevLinkColors(
    success: Color(0xFF6FCF9D),
    successC: Color(0xFF123D2A),
    onSuccessC: Color(0xFFC4EFD8),
    warning: Color(0xFFE9B45C),
    warningC: Color(0xFF43300C),
    onWarningC: Color(0xFFF7E0B5),
    neutralC: Color(0xFF263A4B),
    onNeutralC: Color(0xFFCBD6DE),
  );

  @override
  DevLinkColors copyWith({
    Color? success,
    Color? successC,
    Color? onSuccessC,
    Color? warning,
    Color? warningC,
    Color? onWarningC,
    Color? neutralC,
    Color? onNeutralC,
  }) {
    return DevLinkColors(
      success: success ?? this.success,
      successC: successC ?? this.successC,
      onSuccessC: onSuccessC ?? this.onSuccessC,
      warning: warning ?? this.warning,
      warningC: warningC ?? this.warningC,
      onWarningC: onWarningC ?? this.onWarningC,
      neutralC: neutralC ?? this.neutralC,
      onNeutralC: onNeutralC ?? this.onNeutralC,
    );
  }

  @override
  DevLinkColors lerp(ThemeExtension<DevLinkColors>? other, double t) {
    if (other is! DevLinkColors) return this;
    return DevLinkColors(
      success: Color.lerp(success, other.success, t)!,
      successC: Color.lerp(successC, other.successC, t)!,
      onSuccessC: Color.lerp(onSuccessC, other.onSuccessC, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningC: Color.lerp(warningC, other.warningC, t)!,
      onWarningC: Color.lerp(onWarningC, other.onWarningC, t)!,
      neutralC: Color.lerp(neutralC, other.neutralC, t)!,
      onNeutralC: Color.lerp(onNeutralC, other.onNeutralC, t)!,
    );
  }
}
