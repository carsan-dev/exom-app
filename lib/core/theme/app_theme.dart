import 'package:exom_app/core/theme/exom_page_transitions.dart';
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
    required this.data,
    required this.limeFill,
    required this.onLimeFill,
    this.limeFillOutline,
    required this.selectionFill,
    required this.onSelectionFill,
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

  /// Colour of data (figures, numbering, progress rules, "done" by the
  /// client; L5 D8/D13/D19). Same value as [primary] in each theme: lime in
  /// dark, `#4F6B00` in light.
  final Color data;

  /// Lime as a fill only (button, done calendar cells, "today" pill). Never
  /// ink in the light theme (D13).
  final Color limeFill;

  /// Ink on top of [limeFill].
  final Color onLimeFill;

  /// Outline of the lime fill: none in dark, `#101111` in light (drawn at
  /// `ExomRule.outline`).
  final Color? limeFillOutline;

  /// Selection fill in bone or charcoal, never lime.
  final Color selectionFill;

  /// Ink on top of [selectionFill].
  final Color onSelectionFill;

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
    Color? data,
    Color? limeFill,
    Color? onLimeFill,
    Color? limeFillOutline,
    Color? selectionFill,
    Color? onSelectionFill,
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
      data: data ?? this.data,
      limeFill: limeFill ?? this.limeFill,
      onLimeFill: onLimeFill ?? this.onLimeFill,
      limeFillOutline: limeFillOutline ?? this.limeFillOutline,
      selectionFill: selectionFill ?? this.selectionFill,
      onSelectionFill: onSelectionFill ?? this.onSelectionFill,
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
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      gradientStart:
          Color.lerp(gradientStart, other.gradientStart, t) ?? gradientStart,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t) ?? gradientEnd,
      data: Color.lerp(data, other.data, t) ?? data,
      limeFill: Color.lerp(limeFill, other.limeFill, t) ?? limeFill,
      onLimeFill: Color.lerp(onLimeFill, other.onLimeFill, t) ?? onLimeFill,
      limeFillOutline: Color.lerp(limeFillOutline, other.limeFillOutline, t),
      selectionFill:
          Color.lerp(selectionFill, other.selectionFill, t) ?? selectionFill,
      onSelectionFill:
          Color.lerp(onSelectionFill, other.onSelectionFill, t) ??
          onSelectionFill,
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

  Color get trainingAccent => exomSemantic.calorie;

  Color get dietAccent => exomPalette.primary;
}

/// Brand tokens of the dark theme (V4 brand, decision D2 of the redesign).
///
/// The palette is flat: the former glass/gradient tokens keep their names so
/// existing callers compile, but they now hold opaque panel/rule values.
class AppColors {
  AppColors._();

  // ── Marca ─────────────────────────────────────────────────────────────────
  /// Lima V4. En tema claro solo como relleno (nunca texto ni icono).
  static const primary = Color(0xFFBAF23A);
  static const primaryHover = Color(0xFFC8F562);
  static const primaryPressed = Color(0xFFA4DA2A);
  static const primarySoft = Color(0xFF232B14);

  // ── Fondos ────────────────────────────────────────────────────────────────
  static const background = Color(0xFF101111);

  // ── Navegación ────────────────────────────────────────────────────────────
  static const header = Color(0xFF101111);

  // ── Superficies ───────────────────────────────────────────────────────────
  static const surface = Color(0xFF191B19);
  static const surfaceElevated = Color(0xFF222522);
  static const surfaceVariant = Color(0xFF222522);
  static const card = Color(0xFF191B19);

  // ── Bordes (filete V4) ────────────────────────────────────────────────────
  static const borderSoft = Color(0xFF363B32);
  static const divider = Color(0xFF363B32);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF2F1E9);
  static const textSecondary = Color(0xFFB7BCB3);
  static const textMuted = Color(0xFFB7BCB3);
  // Terciario: 7,00:1 sobre fondo, 5,73:1 sobre raised.
  static const textDisabled = Color(0xFF9A9F96);
  static const textOnPrimary = Color(0xFF101111);

  // ── Estados ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF8CCB68);
  static const warning = Color(0xFFE5BE58);
  static const error = Color(0xFFFF8A73);
  static const info = Color(0xFF7FB5D8);

  // ── Feature-specific ──────────────────────────────────────────────────────
  static const calorieAccent = Color(0xFFE8943A);
  static const sleepAccent = Color(0xFF9B7FCC);

  // ── Antiguo cristal y degradados (tema OSCURO): ahora opacos ─────────────
  static const glassBackground = surface;
  static const glassBackgroundElevated = surfaceElevated;
  static const glassBorderLight = borderSoft;
  static const gradientStart = background;
  static const gradientEnd = background;
  static const navBarGlass = surface;

  // ── Antiguo cristal (tema CLARO): ahora opaco ────────────────────────────
  static const glassBackgroundLightTheme = Color(0xFFFBFAF4);
  static const glassBackgroundElevatedLightTheme = Color(0xFFE8E7DD);
  static const glassBorderLightTheme = Color(0xFFCFCEC2);
  static const navBarGlassLightTheme = Color(0xFFFBFAF4);

  // ── Alias legacy ──────────────────────────────────────────────────────────
  static const accent = error;
}

class AppTheme {
  AppTheme._();

  /// Interface face (V4 brand): DM Sans on every platform, iOS included
  /// (approved in D2). Only the 400 and 600 files are bundled; other weights
  /// resolve to the nearest available file.
  static const String bodyFontFamily = 'DMSans';

  /// Display face for titles and numerals: Barlow Condensed 800.
  static const String displayFontFamily = 'BarlowCondensed';

  /// Default family of the theme. Kept as a nullable getter for API
  /// compatibility with callers of the previous platform-dependent value.
  static String? get fontFamily => bodyFontFamily;

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
    data: AppColors.primary,
    limeFill: Color(0xFFBAF23A),
    onLimeFill: Color(0xFF101111),
    selectionFill: AppColors.textPrimary,
    onSelectionFill: AppColors.background,
  );

  static const ExomThemePalette _lightPalette = ExomThemePalette(
    background: Color(0xFFF2F1E9),
    surface: Color(0xFFFBFAF4),
    surfaceElevated: Color(0xFFE8E7DD),
    surfaceVariant: Color(0xFFE8E7DD),
    borderSoft: Color(0xFFCFCEC2),
    divider: Color(0xFFCFCEC2),
    textPrimary: Color(0xFF101111),
    textSecondary: Color(0xFF55594F),
    textMuted: Color(0xFF55594F),
    // Terciario: 5,11:1 sobre hueso, 4,66:1 sobre raised.
    textDisabled: Color(0xFF63675D),
    // Acento como texto/icono en claro (5,39:1 sobre hueso). La lima nunca
    // es texto en claro: solo relleno del botón primario.
    primary: Color(0xFF4F6B00),
    primarySoft: Color(0xFFE3EDC2),
    onPrimary: Color(0xFFF2F1E9),
    error: Color(0xFFA3321F),
    shadow: Color(0x18000000),
    glassBackground: AppColors.glassBackgroundLightTheme,
    glassBorder: AppColors.glassBorderLightTheme,
    gradientStart: Color(0xFFF2F1E9),
    gradientEnd: Color(0xFFF2F1E9),
    data: Color(0xFF4F6B00),
    limeFill: Color(0xFFBAF23A),
    onLimeFill: Color(0xFF101111),
    limeFillOutline: Color(0xFF101111),
    selectionFill: Color(0xFF101111),
    onSelectionFill: Color(0xFFF2F1E9),
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
    warning: Color(0xFF7A5200),
    accent: Color(0xFFA3321F),
    calorie: Color(0xFF7A4A12),
    sleep: Color(0xFF5B478F),
    info: Color(0xFF2D6C89),
  );

  static ThemeData get dark {
    return _buildTheme(
      brightness: Brightness.dark,
      palette: _darkPalette,
      appBarBackground: AppColors.header,
    );
  }

  static ThemeData get light {
    return _buildTheme(
      brightness: Brightness.light,
      palette: _lightPalette,
      appBarBackground: _lightPalette.background,
    );
  }

  static TextStyle _display(double size, Color color) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.02 * size,
    color: color,
  );

  static TextStyle _body({
    required double size,
    required FontWeight weight,
    required double height,
    required double letterSpacing,
    required Color color,
  }) => TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  static const TextStyle _buttonLabel = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.19,
    letterSpacing: -0.32,
  );

  static final OutlinedBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4),
  );

  /// Primary filled button: lime fill and charcoal label in both themes; in the
  /// light theme it also carries a 1.5 px charcoal border.
  static ButtonStyle _primaryButtonStyle(bool isDark) {
    final foreground = WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return isDark ? AppColors.textDisabled : _lightPalette.textSecondary;
      }
      return AppColors.textOnPrimary;
    });
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark ? AppColors.borderSoft : _lightPalette.borderSoft;
        }
        if (states.contains(WidgetState.pressed)) {
          return AppColors.primaryPressed;
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primaryHover;
        }
        return AppColors.primary;
      }),
      foregroundColor: foreground,
      iconColor: foreground,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
      minimumSize: WidgetStateProperty.all(const Size(0, 56)),
      shape: WidgetStateProperty.all(_buttonShape),
      side: isDark
          ? null
          : WidgetStateProperty.all(
              const BorderSide(color: AppColors.textOnPrimary, width: 1.5),
            ),
      textStyle: WidgetStateProperty.all(_buttonLabel),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ExomThemePalette palette,
    required Color appBarBackground,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.primary,
      onSecondary: palette.onPrimary,
      secondaryContainer: palette.primarySoft,
      onSecondaryContainer: palette.textPrimary,
      error: palette.error,
      onError: isDark ? AppColors.textOnPrimary : palette.background,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surfaceElevated,
      surfaceContainerHighest: palette.surfaceElevated,
      outline: palette.borderSoft,
      outlineVariant: palette.divider,
      surfaceTint: Colors.transparent,
    );
    final textButtonColor = isDark
        ? palette.textPrimary
        : _lightPalette.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.divider,
      shadowColor: palette.shadow,
      fontFamily: fontFamily,
      // M1 (L5 T0.5): EXOM push on Android; iOS and macOS keep Cupertino and
      // its back swipe (risk R3); the rest keep Flutter's default.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ExomPushPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[
        palette,
        isDark ? _darkSemanticPalette : _lightSemanticPalette,
      ],
      // V4 typography: Barlow Condensed 800 for display and large headlines
      // (tight 1.0 line height, -0.02em tracking); DM Sans for the rest
      // (600 titles/labels, 400 body). Slot sizes are kept from the previous
      // scale except that no slot is below the plan's 13 minimum.
      textTheme: TextTheme(
        displayLarge: _display(32, palette.textPrimary),
        displayMedium: _display(28, palette.textPrimary),
        displaySmall: _display(24, palette.textPrimary),
        headlineLarge: _display(24, palette.textPrimary),
        headlineMedium: _display(20, palette.textPrimary),
        headlineSmall: _body(
          size: 18,
          weight: FontWeight.w600,
          height: 1.24,
          letterSpacing: -0.37,
          color: palette.textPrimary,
        ),
        titleLarge: _body(
          size: 16,
          weight: FontWeight.w600,
          height: 1.30,
          letterSpacing: -0.32,
          color: palette.textPrimary,
        ),
        titleMedium: _body(
          size: 14,
          weight: FontWeight.w600,
          height: 1.29,
          letterSpacing: -0.22,
          color: palette.textPrimary,
        ),
        titleSmall: _body(
          size: 13,
          weight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.12,
          color: palette.textPrimary,
        ),
        bodyLarge: _body(
          size: 16,
          weight: FontWeight.w400,
          height: 1.47,
          letterSpacing: -0.32,
          color: palette.textPrimary,
        ),
        // bodyMedium is the inherited DefaultTextStyle: screens that only set
        // fontSize/weight take this tracking.
        // DV-L1-1 resuelta por D11 (Flexible + elipsis en _Badge).
        bodyMedium: _body(
          size: 14,
          weight: FontWeight.w400,
          height: 1.43,
          letterSpacing: -0.22,
          color: palette.textSecondary,
        ),
        bodySmall: _body(
          size: 13,
          weight: FontWeight.w400,
          height: 1.33,
          letterSpacing: -0.12,
          color: palette.textSecondary,
        ),
        labelLarge: _body(
          size: 14,
          weight: FontWeight.w600,
          height: 1.29,
          letterSpacing: -0.22,
          color: palette.textPrimary,
        ),
        labelMedium: _body(
          size: 13,
          weight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.12,
          color: palette.textPrimary,
        ),
        labelSmall: _body(
          size: 13,
          weight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.08,
          color: palette.textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _body(
          size: 20,
          weight: FontWeight.w600,
          height: 1.19,
          letterSpacing: -0.4,
          color: palette.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(isDark),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(isDark),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(0, 56),
          side: BorderSide(color: palette.textPrimary, width: 1.5),
          shape: _buttonShape,
          textStyle: _buttonLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textButtonColor,
          shape: _buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.borderSoft),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.textPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textDisabled),
        labelStyle: TextStyle(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: palette.borderSoft),
        ),
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
        // Default actions fell back to inversePrimary (1.10:1 / 1.22:1).
        actionTextColor: palette.primary,
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        // L5 D12: sheets have square corners.
        shape: const RoundedRectangleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
