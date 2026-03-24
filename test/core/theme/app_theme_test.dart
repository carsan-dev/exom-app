import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme exposes a light palette', () {
    final theme = AppTheme.light;
    final palette = theme.extension<ExomThemePalette>();

    expect(theme.brightness, Brightness.light);
    expect(palette, isNotNull);
    expect(palette!.background, const Color(0xFFF7F1E6));
    expect(theme.colorScheme.primary, palette.primary);
  });

  test('dark theme keeps the current dark palette', () {
    final theme = AppTheme.dark;
    final palette = theme.extension<ExomThemePalette>();

    expect(theme.brightness, Brightness.dark);
    expect(palette, isNotNull);
    expect(palette!.background, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}
