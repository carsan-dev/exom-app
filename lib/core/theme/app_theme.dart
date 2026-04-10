import 'package:flutter/material.dart';

@immutable
class ExomThemePalette extends ThemeExtension<ExomThemePalette> {
  const ExomThemePalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceVariant,
    required this.borderSoft,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.error,
    required this.shadow,
    required this.glassBackground,
    required this.glassBorder,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceVariant;
  final Color borderSoft;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color error;
  final Color shadow;
  final Color glassBackground;
  final Color glassBorder;
  final Color gradientStart;
  final Color gradientEnd;

  @override
  ExomThemePalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceVariant,
    Color? borderSoft,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? primary,
    Color? primarySoft,
    Color? onPrimary,
    Color? error,
    Color? shadow,
    Color? glassBackground,
    Color? glassBorder,
    Color? gradientStart,
    Color? gradientEnd,
  }) {
    return ExomThemePalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      borderSoft: borderSoft ?? this.borderSoft,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      error: error ?? this.error,
      shadow: shadow ?? this.shadow,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
    );
  }

  @override
  ExomThemePalette lerp(ThemeExtension<ExomThemePalette>? other, double t) {
    if (other is! ExomThemePalette) {
      return this;
    }

    return ExomThemePalette(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      surfaceVariant:
          Color.lerp(surfaceVariant, other.surfaceVariant, t) ?? surfaceVariant,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t) ?? borderSoft,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      textDisabled:
          Color.lerp(textDisabled, other.textDisabled, t) ?? textDisabled,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      error: Color.lerp(error, other.error, t) ?? error,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      glassBackground:
          Color.lerp(glassBackground, other.glassBackground, t) ??
          glassBackground,
      glassBorder:
          Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      gradientStart:
          Color.lerp(gradientStart, other.gradientStart, t) ?? gradientStart,
      gradientEnd:
          Color.lerp(gradientEnd, other.gradientEnd, t) ?? gradientEnd,
    );
  }
}

@immutable
class ExomSemanticPalette extends ThemeExtension<ExomSemanticPalette> {
  const ExomSemanticPalette({
    required this.success,
    required this.warning,
    required this.accent,
    required this.calorie,
    required this.sleep,
    required this.info,
  });

  final Color success;
  final Color warning;
  final Color accent;
  final Color calorie;
  final Color sleep;
  final Color info;

  @override
  ExomSemanticPalette copyWith({
    Color? success,
    Color? warning,
    Color? accent,
    Color? calorie,
    Color? sleep,
    Color? info,
  }) {
    return ExomSemanticPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
      calorie: calorie ?? this.calorie,
      sleep: sleep ?? this.sleep,
      info: info ?? this.info,
    );
  }

  @override
  ExomSemanticPalette lerp(
    ThemeExtension<ExomSemanticPalette>? other,
    double t,
  ) {
    if (other is! ExomSemanticPalette) {
      return this;
    }

    return ExomSemanticPalette(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      calorie: Color.lerp(calorie, other.calorie, t) ?? calorie,
      sleep: Color.lerp(sleep, other.sleep, t) ?? sleep,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

extension ExomThemeContext on BuildContext {
  ExomThemePalette get exomPalette =>
      Theme.of(this).extension<ExomThemePalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkPalette
          : AppTheme._lightPalette);

  ExomSemanticPalette get exomSemantic =>
      Theme.of(this).extension<ExomSemanticPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkSemanticPalette
          : AppTheme._lightSemanticPalette);
}

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
  static const surfaceGlass = Color(0x332B150A); // #2B150A 20%
  static const surfaceGlassLight = Color(0x33C5E384); // #C5E384 20%

  // ── Bordes (derivados de #C5E384) ─────────────────────────────────────────
  static const borderSoft = Color(0x1AC5E384); // 10%
  static const borderMedium = Color(0x29C5E384); // 16%
  static const borderStrong = Color(0x3DC5E384); // 24%
  static const focusRing = Color(0x52C5E384); // 32%
  static const divider = Color(0x1AC5E384); // 10%

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

  // ── Glass & Gradients ──────────────────────────────────────────────────────
  static const glassBackground = Color(0x1A2B150A);
  static const glassBackgroundElevated = Color(0x332B150A);
  static const glassBorderLight = Color(0x33C5E384);
  static const glassBorderTop = Color(0x26FFFFFF);
  static const gradientStart = Color(0xFF1A0D05);
  static const gradientEnd = Color(0xFF2E170B);
  static const navBarGlass = Color(0xCC200F07);
  static const headerGlass = Color(0xB326140B);

  // ── Alias legacy ──────────────────────────────────────────────────────────
  static const secondary = primary;
  static const accent = error;
  static const dietCard = dietCardStart;
  static const trainingCard = trainingCardStart;
}

class AppTheme {
  AppTheme._();

  static const ExomThemePalette _darkPalette = ExomThemePalette(
    background: AppColors.background,
    surface: AppColors.card,
    surfaceElevated: AppColors.surfaceElevated,
    surfaceVariant: AppColors.surfaceVariant,
    borderSoft: AppColors.borderSoft,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    textDisabled: AppColors.textDisabled,
    primary: AppColors.primary,
    primarySoft: AppColors.primarySoft,
    onPrimary: AppColors.textOnPrimary,
    error: AppColors.error,
    shadow: Color(0x33000000),
    glassBackground: AppColors.glassBackground,
    glassBorder: AppColors.glassBorderLight,
    gradientStart: AppColors.gradientStart,
    gradientEnd: AppColors.gradientEnd,
  );

  static const ExomThemePalette _lightPalette = ExomThemePalette(
    background: Color(0xFFF7F1E6),
    surface: Color(0xFFFFFBF5),
    surfaceElevated: Color(0xFFF4EBDE),
    surfaceVariant: Color(0xFFF0E6D8),
    borderSoft: Color(0xFFD2C3AE),
    divider: Color(0xFFC7B7A1),
    textPrimary: Color(0xFF2B1A10),
    textSecondary: Color(0xFF5B4739),
    textMuted: Color(0xFF7B675A),
    textDisabled: Color(0xFF725F53),
    primary: Color(0xFF5A7125),
    primarySoft: Color(0xFFE2EACB),
    onPrimary: Color(0xFFFFFBF5),
    error: Color(0xFFA33F33),
    shadow: Color(0x18000000),
    glassBackground: Color(0x1AFFFFFF),
    glassBorder: Color(0x33D2C3AE),
    gradientStart: Color(0xFFF7F1E6),
    gradientEnd: Color(0xFFF0E6D8),
  );

  static const ExomSemanticPalette _darkSemanticPalette = ExomSemanticPalette(
    success: AppColors.success,
    warning: AppColors.warning,
    accent: AppColors.accent,
    calorie: AppColors.calorieAccent,
    sleep: AppColors.sleepAccent,
    info: AppColors.info,
  );

  static const ExomSemanticPalette _lightSemanticPalette = ExomSemanticPalette(
    success: Color(0xFF3D6931),
    warning: Color(0xFF745600),
    accent: Color(0xFFA33F33),
    calorie: Color(0xFF7A4A12),
    sleep: Color(0xFF5B478F),
    info: Color(0xFF2D6C89),
  );

  static ThemeData get dark {
    return _buildTheme(
      brightness: Brightness.dark,
      palette: _darkPalette,
      appBarBackground: AppColors.header,
      bottomNavBackground: AppColors.bottomNav,
      bottomNavIndicator: AppColors.tabActive,
    );
  }

  static ThemeData get light {
    return _buildTheme(
      brightness: Brightness.light,
      palette: _lightPalette,
      appBarBackground: _lightPalette.background,
      bottomNavBackground: _lightPalette.surface,
      bottomNavIndicator: _lightPalette.primarySoft,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ExomThemePalette palette,
    required Color appBarBackground,
    required Color bottomNavBackground,
    required Color bottomNavIndicator,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: palette.primary,
            secondary: palette.primary,
            surface: palette.surface,
            error: palette.error,
            onPrimary: palette.onPrimary,
            onSecondary: palette.onPrimary,
            onSurface: palette.textPrimary,
          )
        : ColorScheme.light(
            primary: palette.primary,
            secondary: palette.primary,
            surface: palette.surface,
            error: palette.error,
            onPrimary: palette.onPrimary,
            onSecondary: palette.onPrimary,
            onSurface: palette.textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.divider,
      shadowColor: palette.shadow,
      fontFamily: 'Inter',
      extensions: <ThemeExtension<dynamic>>[
        palette,
        isDark ? _darkSemanticPalette : _lightSemanticPalette,
      ],
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: palette.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: palette.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: palette.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: palette.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
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
          foregroundColor: palette.primary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: palette.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceVariant,
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
          borderSide: BorderSide(color: palette.borderSoft, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.error, width: 1),
        ),
        hintStyle: TextStyle(color: palette.textDisabled),
        labelStyle: TextStyle(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.borderSoft, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBackground,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bottomNavBackground,
        indicatorColor: bottomNavIndicator,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primary);
          }
          return IconThemeData(color: palette.textDisabled);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        tileColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

