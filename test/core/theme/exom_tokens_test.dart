// L5 T0.1 (docs/plans/rediseno-app-l5-contrato-v2.md, "T0.1 Tokens"): shape
// tokens, rule widths and display/body type styles. Only additions: the old
// ExomRadius scale keeps its values until L6.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ExomRadius adds square and control without touching the old scale', () {
    expect(ExomRadius.square, 0);
    expect(ExomRadius.control, 4);
    expect(ExomRadius.xs, 6);
    expect(ExomRadius.sm, 10);
    expect(ExomRadius.md, 14);
    expect(ExomRadius.lg, 18);
    expect(ExomRadius.xl, 24);
    expect(ExomRadius.xxl, 28);
  });

  test('ExomRule widths', () {
    expect(ExomRule.hairline, 1);
    expect(ExomRule.data, 2);
    expect(ExomRule.bar, 4);
    expect(ExomRule.outline, 1.5);
    expect(ExomRule.replyEdge, 2);
  });

  group('ExomType', () {
    final display = <String, (TextStyle, double)>{
      'screenTitle': (ExomType.screenTitle, 44),
      'headline2Section': (ExomType.headline2Section, 28),
      'headline2Screen': (ExomType.headline2Screen, 44),
      'section': (ExomType.section, 22),
      'hero64': (ExomType.hero64, 64),
      'hero96': (ExomType.hero96, 96),
      'hero120': (ExomType.hero120, 120),
      'hero140': (ExomType.hero140, 140),
    };

    for (final entry in display.entries) {
      test('${entry.key} is BarlowCondensed 800 at ${entry.value.$2}', () {
        final style = entry.value.$1;
        expect(style.fontFamily, AppTheme.displayFontFamily);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.fontSize, entry.value.$2);
        expect(style.color, isNull);
      });
    }

    test('screenTitle has height .95', () {
      expect(ExomType.screenTitle.height, 0.95);
    });

    test('hero styles have height .78 and letter spacing -0.035 * size', () {
      for (final (style, size) in [
        (ExomType.hero64, 64.0),
        (ExomType.hero96, 96.0),
        (ExomType.hero120, 120.0),
        (ExomType.hero140, 140.0),
      ]) {
        expect(style.height, 0.78);
        expect(style.letterSpacing, closeTo(-0.035 * size, 1e-9));
      }
    });

    test('headline2Section and headline2Screen have height .95', () {
      expect(ExomType.headline2Section.height, 0.95);
      expect(ExomType.headline2Screen.height, 0.95);
    });

    test('section has height 1 and letter spacing -0.22', () {
      expect(ExomType.section.height, 1);
      expect(ExomType.section.letterSpacing, -0.22);
    });

    test('kicker has height 1.3 and letter spacing 1.04', () {
      expect(ExomType.kicker.height, 1.3);
      expect(ExomType.kicker.letterSpacing, closeTo(1.04, 1e-9));
    });

    test('kicker is DM Sans 13 / w600 with letter spacing', () {
      final style = ExomType.kicker;
      expect(style.fontFamily, AppTheme.bodyFontFamily);
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, isNotNull);
      expect(style.letterSpacing, greaterThan(0));
      expect(style.color, isNull);
    });
  });
}
