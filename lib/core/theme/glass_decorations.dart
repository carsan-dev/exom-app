import 'package:flutter/material.dart';
import 'app_theme.dart';

class GlassDecoration {
  GlassDecoration._();

  /// Active brightness — set from [MaterialApp.builder] so static factories
  /// pick light/dark glass tokens without needing a BuildContext.
  static Brightness brightness = Brightness.dark;

  static bool get _isDark => brightness == Brightness.dark;

  /// Standard glass card — simulated glass (no BackdropFilter).
  /// Semi-transparent fill + subtle gradient overlay + luminous border + soft shadow.
  static BoxDecoration card({double borderRadius = 20, Color? borderColor}) {
    if (_isDark) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x0DFFFFFF), // white 5%
            Colors.transparent,
          ],
        ),
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorderLight,
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      );
    }
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF), // top: pure white highlight
          Color(0xFFFFFBF5), // body: warm white
          Color(0xFFFDF7EE), // bottom: barely darker warm
        ],
        stops: [0.0, 0.25, 1.0],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? const Color(0x142B150A),
        width: 0.5,
      ),
      boxShadow: const [
        // Ambient (contact)
        BoxShadow(
          color: Color(0x0F2B150A),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        // Key light (warm soft drop)
        BoxShadow(
          color: Color(0x142B150A),
          blurRadius: 24,
          offset: Offset(0, 12),
          spreadRadius: -8,
        ),
      ],
    );
  }

  /// Elevated glass — higher opacity fill and stronger shadow.
  static BoxDecoration elevated({
    double borderRadius = 20,
    Color? borderColor,
  }) {
    if (_isDark) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x15FFFFFF), // white 8%
            Color(0x05FFFFFF), // white 2%
          ],
        ),
        color: AppColors.glassBackgroundElevated,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorderLight,
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 30,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      );
    }
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFCF7), Color(0xFFFEF8EF)],
        stops: [0.0, 0.22, 1.0],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? const Color(0x142B150A),
        width: 0.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x102B150A),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x162B150A),
          blurRadius: 32,
          offset: Offset(0, 16),
          spreadRadius: -10,
        ),
      ],
    );
  }

  /// Accent-tinted glass card — used for training/diet type-specific cards.
  static BoxDecoration accentCard(Color accent, {double borderRadius = 20}) {
    if (_isDark) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.12), AppColors.glassBackground],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.20), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
            accent.withValues(alpha: 0.10),
            const Color(0xFFFFFFFF),
          ),
          const Color(0xFFFFFBF5),
          const Color(0xFFFDF7EE),
        ],
        stops: const [0.0, 0.18, 1.0],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: const Color(0x142B150A), width: 0.5),
      boxShadow: [
        const BoxShadow(
          color: Color(0x0F2B150A),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        const BoxShadow(
          color: Color(0x142B150A),
          blurRadius: 24,
          offset: Offset(0, 12),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.14),
          blurRadius: 28,
          offset: const Offset(0, 14),
          spreadRadius: -12,
        ),
      ],
    );
  }

  /// Navigation bar glass decoration.
  static BoxDecoration navBar() {
    if (_isDark) {
      return const BoxDecoration(
        color: AppColors.navBarGlass,
        border: Border(
          top: BorderSide(color: AppColors.glassBorderLight, width: 0.5),
        ),
      );
    }
    return const BoxDecoration(
      color: AppColors.navBarGlassLightTheme,
      border: Border(top: BorderSide(color: Color(0x142B150A), width: 0.5)),
    );
  }
}

class ExomGradients {
  ExomGradients._();

  /// Vertical gradient for scaffold backgrounds.
  static LinearGradient scaffoldBackground(ExomThemePalette palette) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [palette.gradientStart, palette.gradientEnd],
    );
  }

  /// Diagonal gradient with accent tint for cards.
  static LinearGradient cardAccent(Color accent) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accent.withValues(alpha: 0.16), Colors.transparent],
    );
  }

  /// Top-to-bottom fade for app bar overlay.
  static const LinearGradient headerFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33000000), Colors.transparent],
  );
}
