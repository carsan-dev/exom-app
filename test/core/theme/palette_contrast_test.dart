// Redesign L1 (docs/plans/rediseno-exom-app.md): every text token of the V4
// palette must reach WCAG AA (4.5:1) on every background it is meant for, in
// both themes. The ratio is computed with the WCAG 2.x relative luminance
// formula so the test does not depend on the framework helper.
//
// Each pair prints a `CONTRAST` line; the evidence of lot L1 copies that table.
// The formula lives in wcag_contrast.dart, shared with the rendered-text check
// of test/a11y/redesign_baseline_guidelines_test.dart.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wcag_contrast.dart';

String _hex(Color color) => hexRgb(color);

typedef _Pair = (String fg, Color fgColor, String bg, Color bgColor);

List<_Pair> _pairsFor(ThemeData theme) {
  final p = theme.extension<ExomThemePalette>()!;
  final s = theme.extension<ExomSemanticPalette>()!;
  final backgrounds = <String, Color>{
    'background': p.background,
    'surface': p.surface,
    'surfaceElevated': p.surfaceElevated,
    'surfaceVariant': p.surfaceVariant,
  };
  final baseBackgrounds = <String, Color>{
    'background': p.background,
    'surface': p.surface,
  };
  final pairs = <_Pair>[];
  void on(String fg, Color fgColor, Map<String, Color> bgs) {
    for (final bg in bgs.entries) {
      pairs.add((fg, fgColor, bg.key, bg.value));
    }
  }

  on('textPrimary', p.textPrimary, backgrounds);
  on('textSecondary', p.textSecondary, backgrounds);
  on('textMuted', p.textMuted, backgrounds);
  on('textDisabled (tertiary)', p.textDisabled, backgrounds);
  // Accent as text/icon: lime in dark, #4F6B00 in light.
  on('colorScheme.primary (accent text)', theme.colorScheme.primary, backgrounds);
  pairs.add(('onPrimary', p.onPrimary, 'primary', p.primary));
  pairs.add(('textPrimary', p.textPrimary, 'primarySoft', p.primarySoft));
  pairs.add(('primary', p.primary, 'primarySoft', p.primarySoft));

  final button = theme.elevatedButtonTheme.style!;
  pairs.add((
    'primary button label',
    button.foregroundColor!.resolve({})!,
    'primary button fill',
    button.backgroundColor!.resolve({})!,
  ));
  pairs.add((
    'primary button label',
    button.foregroundColor!.resolve({})!,
    'primary button fill (pressed)',
    button.backgroundColor!.resolve({WidgetState.pressed})!,
  ));
  pairs.add((
    'primary button label',
    button.foregroundColor!.resolve({})!,
    'primary button fill (hovered)',
    button.backgroundColor!.resolve({WidgetState.hovered})!,
  ));
  pairs.add((
    'onError',
    theme.colorScheme.onError,
    'error',
    theme.colorScheme.error,
  ));

  on('error', p.error, backgrounds);
  on('warning', s.warning, backgrounds);
  on('success', s.success, backgrounds);
  on('info', s.info, backgrounds);
  on('accent (semantic)', s.accent, baseBackgrounds);
  on('calorie', s.calorie, backgrounds);
  on('sleep', s.sleep, backgrounds);
  return pairs;
}

void main() {
  test('WCAG formula sanity check', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 1e-9));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 1e-9));
  });

  // L5 T0.1 pairs (docs/plans/rediseno-app-l5-contrato-v2.md).
  test('light data colour (#4F6B00) reaches 4.5:1 on background, panel and '
      'elevated', () {
    final p = AppTheme.light.extension<ExomThemePalette>()!;
    expect(p.data, const Color(0xFF4F6B00));
    for (final bg in [p.background, p.surface, p.surfaceElevated]) {
      expect(contrastRatio(p.data, bg), greaterThanOrEqualTo(4.5));
    }
  });

  for (final entry in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
    test('${entry.key} onLimeFill on limeFill and onSelectionFill on '
        'selectionFill reach 4.5:1', () {
      final p = entry.value.extension<ExomThemePalette>()!;
      expect(contrastRatio(p.onLimeFill, p.limeFill), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(p.onSelectionFill, p.selectionFill),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  for (final entry in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
    test('${entry.key} palette text pairs reach 4.5:1', () {
      final failures = <String>[];
      var minRatio = double.infinity;
      var minPair = '';
      for (final (fg, fgColor, bg, bgColor) in _pairsFor(entry.value)) {
        final ratio = contrastRatio(fgColor, bgColor);
        final line =
            '${entry.key} | $fg ${_hex(fgColor)} | $bg ${_hex(bgColor)} | ${ratio.toStringAsFixed(2)}';
        // Table collected by the L1 evidence.
        // ignore: avoid_print
        print('CONTRAST $line');
        if (ratio < minRatio) {
          minRatio = ratio;
          minPair = line;
        }
        if (ratio < 4.5) failures.add(line);
      }
      // ignore: avoid_print
      print('CONTRAST-MIN $minPair');
      expect(failures, isEmpty, reason: 'pairs below 4.5:1');
    });
  }
}
