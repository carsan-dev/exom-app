import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

void main() {
  registerTextComponentMatrix(
    'ExomIndexNumber',
    () => const ExomIndexNumber(3),
  );

  testWidgets('pads to two digits and keeps longer numbers', (tester) async {
    for (final entry in const {
      1: '01',
      2: '02',
      10: '10',
      100: '100',
    }.entries) {
      await pumpComponent(tester, ExomIndexNumber(entry.key));
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('paints in the data colour, Barlow 800 (${brightness.name})', (
      tester,
    ) async {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        const ExomIndexNumber(1),
        brightness: brightness,
      );
      final style = tester.widget<Text>(find.text('01')).style!;
      expect(style.color, palette.data);
      expect(style.fontFamily, AppTheme.displayFontFamily);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.fontSize, 20);
      expect(style.letterSpacing, 0);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  }

  testWidgets('semantics reads the number', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, const ExomIndexNumber(7));
    expect(find.bySemanticsLabel('07'), findsOneWidget);
    handle.dispose();
  });
}
