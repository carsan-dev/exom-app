import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

void main() {
  registerTextComponentMatrix(
    'ExomKicker',
    () => const ExomKicker('Masa muscular', icon: Icons.fitness_center),
  );

  for (final brightness in Brightness.values) {
    testWidgets('paints upper case in secondary text, icon in text colour '
        '(${brightness.name})', (tester) async {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        const ExomKicker('Masa muscular', icon: Icons.fitness_center),
        brightness: brightness,
      );
      final text = tester.widget<Text>(find.text('MASA MUSCULAR'));
      expect(text.style?.color, palette.textSecondary);
      expect(text.style?.fontSize, ExomType.kicker.fontSize);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.letterSpacing, ExomType.kicker.letterSpacing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.fitness_center));
      expect(icon.color, palette.textPrimary);
      expect(icon.size, closeTo(13 * 1.3, 0.001));
    });
  }

  testWidgets('without icon there is no icon', (tester) async {
    await pumpComponent(tester, const ExomKicker('Hoy'));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('semantics keep the original case', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ExomKicker('Masa muscular', icon: Icons.fitness_center),
    );
    expect(find.bySemanticsLabel('Masa muscular'), findsOneWidget);
    expect(find.bySemanticsLabel('MASA MUSCULAR'), findsNothing);
    handle.dispose();
  });
}
