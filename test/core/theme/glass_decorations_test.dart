import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    GlassDecoration.brightness = Brightness.dark;
  });

  test('light elevated card uses warm gradient and double shadow', () {
    GlassDecoration.brightness = Brightness.light;

    final decoration = GlassDecoration.elevated();
    final gradient = decoration.gradient! as LinearGradient;
    final border = decoration.border! as Border;

    expect(gradient.colors, const [
      Color(0xFFFFFFFF),
      Color(0xFFFFFCF7),
      Color(0xFFFEF8EF),
    ]);
    expect(gradient.stops, const [0.0, 0.22, 1.0]);
    expect(border.top.color, const Color(0x142B150A));
    expect(decoration.boxShadow, hasLength(2));
  });

  test('light accent card keeps a neutral border and accent shadow', () {
    const accent = Color(0xFFE8943A);
    GlassDecoration.brightness = Brightness.light;

    final decoration = GlassDecoration.accentCard(accent);
    final gradient = decoration.gradient! as LinearGradient;
    final border = decoration.border! as Border;
    final shadows = decoration.boxShadow!;

    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors.sublist(1), const [
      Color(0xFFFFFBF5),
      Color(0xFFFDF7EE),
    ]);
    expect(border.top.color, const Color(0x142B150A));
    expect(shadows, hasLength(3));
    expect(shadows.last.color, accent.withValues(alpha: 0.14));
  });
}
