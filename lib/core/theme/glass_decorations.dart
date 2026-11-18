import 'package:flutter/material.dart';
import 'app_theme.dart';

class GlassDecoration {
  GlassDecoration._();

  /// Active brightness — set from [MaterialApp.builder] so static factories
  /// pick light/dark tokens without needing a BuildContext.
  static Brightness brightness = Brightness.dark;

  static bool get _isDark => brightness == Brightness.dark;

  /// V4 brand (redesign L1): the former glass surfaces are flat and opaque.
  /// Every factory keeps its signature so callers compile unchanged.
  static BoxDecoration _flat({
    required Color fill,
    required double borderRadius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? _rule, width: 1),
    );
  }

  static Color get _rule =>
      _isDark ? AppColors.glassBorderLight : AppColors.glassBorderLightTheme;

  /// Standard card: opaque square panel (V4 cards have radius 0) with a 1 px
  /// rule border, no shadow. Callers that pass [borderRadius] keep it.
  static BoxDecoration card({double borderRadius = 0, Color? borderColor}) {
    return _flat(
      fill: _isDark
          ? AppColors.glassBackground
          : AppColors.glassBackgroundLightTheme,
      borderRadius: borderRadius,
      borderColor: borderColor,
    );
  }

  /// Elevated card: opaque raised panel with a 1 px rule border, no shadow.
  static BoxDecoration elevated({
    double borderRadius = 20,
    Color? borderColor,
  }) {
    return _flat(
      fill: _isDark
          ? AppColors.glassBackgroundElevated
          : AppColors.glassBackgroundElevatedLightTheme,
      borderRadius: borderRadius,
      borderColor: borderColor,
    );
  }

  /// Formerly an accent-tinted glass card. In the flat V4 system it is a plain
  /// panel; [accent] is kept for API compatibility and no longer tints it.
  static BoxDecoration accentCard(Color accent, {double borderRadius = 20}) {
    return card(borderRadius: borderRadius);
  }

  /// Navigation bar: opaque panel with a 1 px rule top border.
  static BoxDecoration navBar() {
    return BoxDecoration(
      color: _isDark ? AppColors.navBarGlass : AppColors.navBarGlassLightTheme,
      border: Border(top: BorderSide(color: _rule, width: 1)),
    );
  }
}

class ExomGradients {
  ExomGradients._();

  /// Scaffold background. Flat in the V4 system (both stops are the
  /// background token); kept as a gradient for API compatibility.
  static LinearGradient scaffoldBackground(ExomThemePalette palette) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [palette.gradientStart, palette.gradientEnd],
    );
  }

  /// Formerly a diagonal accent tint for cards. Flat in the V4 system: it
  /// paints nothing; [accent] is kept for API compatibility.
  static LinearGradient cardAccent(Color accent) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.transparent, Colors.transparent],
    );
  }

  /// Top-to-bottom fade for app bar overlay.
  static const LinearGradient headerFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33000000), Colors.transparent],
  );
}
