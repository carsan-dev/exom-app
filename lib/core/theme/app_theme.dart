import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Marca ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFC5E384);
  static const primaryHover = Color(0xFFD2EB99);
  static const primaryPressed = Color(0xFFA9C85D);
  static const primarySoft = Color(0xFFEAF4CC);
  static const primaryDark = Color(0xFFA9C85D); // alias de pressed

  // ── Fondos ────────────────────────────────────────────────────────────────
  static const background = Color(0xFF200F07);
  static const backgroundSecondary = Color(0xFF261209);
  static const backgroundTertiary = Color(0xFF2E170B);

  // ── Navegación ────────────────────────────────────────────────────────────
  static const header = Color(0xFF26140B);
  static const bottomNav = Color(0xFF241209);
  static const tabActive = Color(0x29C5E384); // #C5E384 16%

  // ── Superficies ───────────────────────────────────────────────────────────
  static const surface = Color(0xFF241209);
  static const surfaceElevated = Color(0xFF33190C);
  static const surfaceVariant = Color(0xFF33190C);
  static const card = Color(0xFF2B150A);

  // Glass surfaces
  static const surfaceGlass = Color(0x332B150A);    // #2B150A 20%
  static const surfaceGlassLight = Color(0x33C5E384); // #C5E384 20%

  // ── Bordes (derivados de #C5E384) ─────────────────────────────────────────
  static const borderSoft = Color(0x1AC5E384);   // 10%
  static const borderMedium = Color(0x29C5E384);  // 16%
  static const borderStrong = Color(0x3DC5E384);  // 24%
  static const focusRing = Color(0x52C5E384);     // 32%
  static const divider = Color(0x1AC5E384);       // 10%

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF7F9EF);
  static const textSecondary = Color(0xFFE1E8C9);
  static const textMuted = Color(0xFFB8BEA6);
  static const textDisabled = Color(0xFF8F947F);
  static const textOnPrimary = Color(0xFF231208);

  // ── Iconos ────────────────────────────────────────────────────────────────
  static const iconDefault = Color(0xFFE1E8C9);

  // ── Estados ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF8CCB68);
  static const warning = Color(0xFFE5BE58);
  static const error = Color(0xFFD76C5E);
  static const info = Color(0xFF7FB5D8);

  // ── Botones ───────────────────────────────────────────────────────────────
  static const buttonDisabled = Color(0xFF6D7558);
  static const buttonDanger = Color(0xFFD76C5E);
  static const buttonDangerHover = Color(0xFFE17B6E);
  static const buttonDangerPressed = Color(0xFFC95C4E);
  static const buttonDangerDisabled = Color(0xFF6A4742);

  // ── Feature-specific ──────────────────────────────────────────────────────
  static const dietCardStart = Color(0xFF1B4822);
  static const dietCardEnd = Color(0xFF2A6A35);
  static const trainingCardStart = Color(0xFF552015);
  static const trainingCardEnd = Color(0xFF7A2E1E);
  static const calorieAccent = Color(0xFFE8943A);
  static const sleepAccent = Color(0xFF9B7FCC);

  // ── Alias legacy ──────────────────────────────────────────────────────────
  static const secondary = primary;
  static const accent = error;
  static const dietCard = dietCardStart;
  static const trainingCard = trainingCardStart;
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
        backgroundColor: AppColors.header,
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
        backgroundColor: AppColors.bottomNav,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bottomNav,
        indicatorColor: AppColors.tabActive,
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
