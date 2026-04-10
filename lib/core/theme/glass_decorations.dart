import 'package:flutter/material.dart';
import 'app_theme.dart';

class GlassDecoration {
  GlassDecoration._();

  /// Standard glass card — simulated glass (no BackdropFilter).
  /// Semi-transparent fill + subtle gradient overlay + luminous border + soft shadow.
  static BoxDecoration card({
    double borderRadius = 20,
    Color? borderColor,
  }) {
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

  /// Elevated glass — higher opacity fill and stronger shadow.
  static BoxDecoration elevated({
    double borderRadius = 20,
    Color? borderColor,
  }) {
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

  /// Accent-tinted glass card — used for training/diet type-specific cards.
  static BoxDecoration accentCard(
    Color accent, {
    double borderRadius = 20,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.12),
          AppColors.glassBackground,
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: accent.withValues(alpha: 0.20),
        width: 0.5,
      ),
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

  /// Navigation bar glass decoration.
  static BoxDecoration navBar() {
    return const BoxDecoration(
      color: AppColors.navBarGlass,
      border: Border(
        top: BorderSide(
          color: AppColors.glassBorderLight,
          width: 0.5,
        ),
      ),
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
      colors: [
        accent.withValues(alpha: 0.16),
        Colors.transparent,
      ],
    );
  }

  /// Top-to-bottom fade for app bar overlay.
  static const LinearGradient headerFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33000000),
      Colors.transparent,
    ],
  );
}
