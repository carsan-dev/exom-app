// L5-C5b figure contrast: the plates of the body map are graphical objects, so
// WCAG 1.4.11 asks 3:1 between the selectable plate and the page, and between
// the selected plate and the idle one. The ratios are computed from the tones
// the painter really uses, in both themes.
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';

double _channel(double value) => value <= 0.03928
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('plate tones keep the 1.4.11 contrast (${brightness.name})', (
      tester,
    ) async {
      late BuildContext captured;
      await pumpComponent(
        tester,
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
        brightness: brightness,
      );
      final tones = RecapAnatomySelector.debugPlateTones(captured);
      final background = captured.exomPalette.background;
      expect(tones.gap, background, reason: 'gaps stay the page background');

      final idle = _ratio(tones.idle, background);
      final neutral = _ratio(tones.neutral, background);
      final selected = _ratio(tones.selected, tones.idle);
      final neutralToIdle = _ratio(tones.neutral, tones.idle);
      expect(idle, greaterThanOrEqualTo(3.0), reason: 'idle vs background');
      expect(
        neutral,
        greaterThanOrEqualTo(2.0),
        reason: 'neutral vs background',
      );
      expect(neutral, lessThan(idle), reason: 'neutral sits closer to bg');
      expect(
        neutralToIdle,
        greaterThanOrEqualTo(1.4),
        reason: 'neutral is distinct from idle',
      );
      expect(selected, greaterThanOrEqualTo(3.0), reason: 'lime vs idle');
    });
  }
}
