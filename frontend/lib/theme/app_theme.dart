import 'package:flutter/material.dart';

import 'devlink_tokens.dart';

/// Blueprint theme for the whole app (M2.12-lite, DESIGN_SYSTEM.md §2–§6).
/// Screens that use theme colours and Material components pick this up as is; the
/// colours some screens set by hand are replaced in the per-screen redesign.
class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = _build(DevLinkSchemes.light, DevLinkColors.light);
  static final ThemeData darkTheme = _build(DevLinkSchemes.dark, DevLinkColors.dark);

  static ThemeData _build(ColorScheme scheme, DevLinkColors extra) {
    final textTheme = _textTheme(scheme);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm));
    const buttonMinSize = Size(64, DevLinkTokens.minTouchTarget);
    final buttonLabel = textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600);

    OutlineInputBorder inputBorder(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: DevLinkTokens.fontLatin,
      fontFamilyFallback: const [DevLinkTokens.fontArabic],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      primaryColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      extensions: [extra],
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: scheme.onSurface),
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),

      // Cards are flat with a hairline, never a shadow (§4).
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonLabel,
          padding: const EdgeInsets.symmetric(horizontal: DevLinkTokens.spaceXl),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonLabel,
          padding: const EdgeInsets.symmetric(horizontal: DevLinkTokens.spaceXl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonLabel,
          padding: const EdgeInsets.symmetric(horizontal: DevLinkTokens.spaceXl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonLabel,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(DevLinkTokens.minTouchTarget)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: buttonShape,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: scheme.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        contentPadding: const EdgeInsets.symmetric(horizontal: DevLinkTokens.spaceLg, vertical: 14),
        border: inputBorder(scheme.outline, 1),
        enabledBorder: inputBorder(scheme.outline, 1),
        focusedBorder: inputBorder(scheme.primary, 2),
        errorBorder: inputBorder(scheme.error, 2),
        focusedErrorBorder: inputBorder(scheme.error, 2),
        disabledBorder: inputBorder(scheme.outlineVariant, 1),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusLg)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(DevLinkTokens.radiusLg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd)),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(DevLinkTokens.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusMd)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: buttonLabel,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DevLinkTokens.radiusXs)),
      ),
    );
  }

  /// Type scale (§3). Letter-spacing is 0 everywhere: spacing breaks the joins
  /// between Arabic letters, and both languages should match.
  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle style(double size, double lineHeight, FontWeight weight, Color color) => TextStyle(
          fontFamily: DevLinkTokens.fontLatin,
          fontFamilyFallback: const [DevLinkTokens.fontArabic],
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          letterSpacing: 0,
          color: color,
        );

    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    return TextTheme(
      displayLarge: style(52, 62, FontWeight.w600, ink),
      displayMedium: style(44, 53, FontWeight.w600, ink),
      displaySmall: style(32, 40, FontWeight.w600, ink),
      headlineLarge: style(28, 36, FontWeight.w600, ink),
      headlineMedium: style(26, 34, FontWeight.w600, ink),
      headlineSmall: style(24, 32, FontWeight.w600, ink),
      titleLarge: style(20, 28, FontWeight.w600, ink),
      titleMedium: style(18, 26, FontWeight.w600, ink),
      titleSmall: style(16, 24, FontWeight.w600, ink),
      bodyLarge: style(16, 24, FontWeight.w400, ink),
      bodyMedium: style(15, 22, FontWeight.w400, ink),
      bodySmall: style(13, 18, FontWeight.w400, muted),
      labelLarge: style(14, 20, FontWeight.w500, ink),
      labelMedium: style(13, 18, FontWeight.w500, ink),
      labelSmall: style(12, 16, FontWeight.w500, muted),
    );
  }
}
