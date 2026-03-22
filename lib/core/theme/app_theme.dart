import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFB5C934);
  static const primaryHover = Color(0xFF9AAE2A);
  static const primaryDark = Color(0xFF7E9220);
  static const primarySoft = Color(0x33B5C934);
  static const secondary = Color(0xFFD4A844);
  static const accent = Color(0xFFD4604A);

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const background = Color(0xFF1A1610);
  static const backgroundSecondary = Color(0xFF242018);
  static const backgroundTertiary = Color(0xFF302A20);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const surface = Color(0xFF1E1A14);
  static const surfaceElevated = Color(0xFF262220);
  static const surfaceVariant = Color(0xFF282420);
  static const card = Color(0xFF1E1A14);

  // Glass surfaces (for glassmorphism)
  static const surfaceGlass = Color(0xCC1E1A14);
  static const surfaceGlassLight = Color(0x99282420);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const borderSoft = Color(0xFF282420);
  static const borderMedium = Color(0xFF342E24);
  static const borderStrong = Color(0xFF403830);
  static const focusRing = Color(0xFFB5C934);
  static const divider = Color(0xFF302A22);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFADA498);
  static const textMuted = Color(0xFF807868);
  static const textDisabled = Color(0xFF5A5244);
  static const textOnPrimary = Color(0xFF1A1610);

  // ── Icons ──────────────────────────────────────────────────────────────────
  static const iconDefault = Color(0xFF807868);

  // ── States ─────────────────────────────────────────────────────────────────
  static const success = Color(0xFF7CB342);
  static const warning = Color(0xFFD4B840);
  static const error = Color(0xFFCC5A4A);
  static const info = Color(0xFF5A86B8);

  // ── Feature-specific ───────────────────────────────────────────────────────
  static const dietCard = Color(0xFF3A5028);
  static const trainingCard = Color(0xFF4A3828);
  static const calorieAccent = Color(0xFFE8943A);
  static const sleepAccent = Color(0xFF9B7FCC);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.card,
      dividerColor: AppColors.divider,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSoft, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.focusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSoft, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textDisabled);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}

/// Helper to create a glassmorphism-style decoration.
class GlassDecoration {
  GlassDecoration._();

  /// Standard glass card decoration.
  static BoxDecoration card({
    double borderRadius = 16,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.borderSoft,
      ),
    );
  }

  /// Light glass decoration (more transparent).
  static BoxDecoration light({
    double borderRadius = 16,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceGlassLight,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.borderSoft,
      ),
    );
  }
}
