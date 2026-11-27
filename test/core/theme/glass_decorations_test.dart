// Contract change approved in decision D2 (redesign plan, lot L1): glass
// decorations become flat opaque panels (panel/raised fill + 1 px rule border,
// no gradient, no shadow, no translucency). The API stays the same.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectFlat(BoxDecoration decoration, Color fill, Color border) {
  expect(decoration.gradient, isNull);
  expect(decoration.boxShadow, anyOf(isNull, isEmpty));
  expect(decoration.color, fill);
  expect(decoration.color!.a, 1.0, reason: 'fill must be opaque');
  final box = decoration.border! as Border;
  expect(box.top.color, border);
  expect(box.top.width, 1);
}

void main() {
  tearDown(() {
    GlassDecoration.brightness = Brightness.dark;
  });

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
    final palette = theme.extension<ExomThemePalette>()!;

    group(brightness.name, () {
      setUp(() => GlassDecoration.brightness = brightness);

      test('card is a flat square panel with a rule border', () {
        final decoration = GlassDecoration.card();
        _expectFlat(decoration, palette.surface, palette.borderSoft);
        // Approved V4 cards are square (radius 0); callers that pass an
        // explicit radius keep it (see the next test).
        expect(decoration.borderRadius, BorderRadius.zero);
      });

      test('card keeps caller radius and border override', () {
        const custom = Color(0xFF123456);
        final decoration = GlassDecoration.card(
          borderRadius: 8,
          borderColor: custom,
        );
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect((decoration.border! as Border).top.color, custom);
      });

      test('elevated is a flat raised panel with a rule border', () {
        final decoration = GlassDecoration.elevated();
        _expectFlat(decoration, palette.surfaceElevated, palette.borderSoft);
      });

      test('accent card is a flat panel without accent tint', () {
        final decoration = GlassDecoration.accentCard(const Color(0xFFE8943A));
        _expectFlat(decoration, palette.surface, palette.borderSoft);
      });

      test('nav bar is opaque with a rule top border', () {
        final decoration = GlassDecoration.navBar();
        expect(decoration.color, palette.surface);
        expect(decoration.color!.a, 1.0);
        final border = decoration.border! as Border;
        expect(border.top.color, palette.borderSoft);
      });
    });
  }
}
