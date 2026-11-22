// M2.12-lite: the Blueprint theme follows docs/DESIGN_SYSTEM.md.
import 'dart:math' as math;

import 'package:devlink/theme/app_theme.dart';
import 'package:devlink/theme/devlink_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final entry in {'light': AppTheme.lightTheme, 'dark': AppTheme.darkTheme}.entries) {
    final theme = entry.value;
    final s = theme.colorScheme;
    final x = theme.extension<DevLinkColors>()!;

    group('${entry.key} theme', () {
      test('text pairs reach 4.5:1 (WCAG AA)', () {
        final pairs = <String, List<Color>>{
          'ink on bg': [s.onSurface, s.surface],
          'ink on surface': [s.onSurface, s.surfaceContainerLowest],
          'muted on bg': [s.onSurfaceVariant, s.surface],
          'muted on surface2': [s.onSurfaceVariant, s.surfaceContainerHigh],
          'onPrimary on primary': [s.onPrimary, s.primary],
          'primary on bg (links)': [s.primary, s.surface],
          'onPrimaryC on primaryC': [s.onPrimaryContainer, s.primaryContainer],
          'accent on bg': [s.tertiary, s.surface],
          'onAccentC on accentC': [s.onTertiaryContainer, s.tertiaryContainer],
          'danger on bg': [s.error, s.surface],
          'onDangerC on dangerC': [s.onErrorContainer, s.errorContainer],
          'onSuccessC on successC': [x.onSuccessC, x.successC],
          'onWarningC on warningC': [x.onWarningC, x.warningC],
          'onNeutralC on neutralC': [x.onNeutralC, x.neutralC],
        };
        pairs.forEach((name, p) => expect(contrast(p[0], p[1]), greaterThanOrEqualTo(4.5), reason: name));
      });

      test('control borders reach 3:1 against the surfaces they sit on', () {
        expect(contrast(s.outline, s.surface), greaterThanOrEqualTo(3));
        expect(contrast(s.outline, s.surfaceContainerLowest), greaterThanOrEqualTo(3));
        expect(contrast(s.outline, s.surfaceContainerHigh), greaterThanOrEqualTo(3));
      });

      test('no tint on raised surfaces, flat cards with a hairline', () {
        expect(s.surfaceTint, Colors.transparent);
        expect(theme.cardTheme.elevation, 0);
        final shape = theme.cardTheme.shape as RoundedRectangleBorder;
        expect(shape.side.color, s.outlineVariant);
      });

      test('bundled Plex fonts, letter-spacing 0 in every text style', () {
        final styles = [
          theme.textTheme.displayLarge, theme.textTheme.displayMedium, theme.textTheme.displaySmall,
          theme.textTheme.headlineLarge, theme.textTheme.headlineMedium, theme.textTheme.headlineSmall,
          theme.textTheme.titleLarge, theme.textTheme.titleMedium, theme.textTheme.titleSmall,
          theme.textTheme.bodyLarge, theme.textTheme.bodyMedium, theme.textTheme.bodySmall,
          theme.textTheme.labelLarge, theme.textTheme.labelMedium, theme.textTheme.labelSmall,
        ];
        for (final style in styles) {
          expect(style!.fontFamily, DevLinkTokens.fontLatin);
          expect(style.fontFamilyFallback, contains(DevLinkTokens.fontArabic));
          expect(style.letterSpacing, 0);
        }
      });
    });
  }

  test('the light scheme uses the documented token values', () {
    final s = AppTheme.lightTheme.colorScheme;
    expect(s.primary, const Color(0xFF0E5A83));
    expect(s.surface, const Color(0xFFF7F6F2));
    expect(s.onSurface, const Color(0xFF14273A));
    expect(s.outlineVariant, const Color(0xFFD9D6CC));
  });
}
