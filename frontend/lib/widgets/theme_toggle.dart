import 'package:flutter/material.dart';
import '../theme/theme_manager.dart';

class ThemeToggle extends StatelessWidget {
  final ThemeManager themeManager;
  final bool compact;

  const ThemeToggle({
    super.key,
    required this.themeManager,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeManager.isDark;

    if (compact) {
      // نسخة صغيرة (44x44) — للأزرار في الـ TopBar
      return Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => themeManager.toggleTheme(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                color: isDark
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF6366F1),
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    // نسخة كبيرة مع text
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => themeManager.toggleTheme(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: isDark
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF6366F1),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                isDark ? 'Light Mode' : 'Dark Mode',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}