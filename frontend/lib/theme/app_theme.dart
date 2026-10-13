import 'package:flutter/material.dart';

class AppTheme {
  // ============================================================
  // LIGHT THEME
  // ============================================================
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    primaryColor: const Color(0xFF3B82F6),

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF10B981),
      surface: Colors.white,
      background: Color(0xFFF1F5F9),
      error: Color(0xFFEF4444),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
          width: 1.4,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF3B82F6),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 2,
        ),
      ),
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF0F172A)),
      bodyMedium: TextStyle(color: Color(0xFF334155)),
      bodySmall: TextStyle(color: Color(0xFF64748B)),
      titleLarge: TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
      ),
    ),

    iconTheme: const IconThemeData(
      color: Color(0xFF334155),
    ),

    dividerColor: const Color(0xFFE2E8F0),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // ============================================================
  // DARK THEME
  // ============================================================
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    primaryColor: const Color(0xFF3B82F6),

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF10B981),
      surface: Color(0xFF1E293B),
      background: Color(0xFF0F172A),
      error: Color(0xFFEF4444),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E293B),
      foregroundColor: Color(0xFFF1F5F9),
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF334155),
          width: 1.4,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF3B82F6),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 2,
        ),
      ),
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFF1F5F9)),
      bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
      bodySmall: TextStyle(color: Color(0xFF94A3B8)),
      titleLarge: TextStyle(
        color: Color(0xFFF1F5F9),
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        color: Color(0xFFF1F5F9),
        fontWeight: FontWeight.w800,
      ),
    ),

    iconTheme: const IconThemeData(
      color: Color(0xFFCBD5E1),
    ),

    dividerColor: const Color(0xFF334155),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}