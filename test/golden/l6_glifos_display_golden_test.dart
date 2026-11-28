// L6-D1c: Barlow Condensed (display face) paints the Spanish glyphs and
// accents Á É Í Ó Ú Ñ á é í ó ú ñ and the numerals 0-9, with the real
// ExomType styles of the theme (screen title, section, hero numeral).
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l6_glifos_display_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/core/theme/exom_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign_scenes.dart';

const _text = 'ÁÉÍÓÚÑ áéíóúñ Ú 0123456789';

void main() {
  for (final brightness in Brightness.values) {
    final name = 'l6_glifos_display_${brightness.name}_1_0x';
    testWidgets('golden $name', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadRedesignFonts();
      final theme = redesignTheme(brightness);
      final color = theme.colorScheme.onSurface;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final style in [
                    ExomType.screenTitle,
                    ExomType.headline2Section,
                    ExomType.section,
                    ExomType.hero64,
                  ]) ...[
                    Text(_text, style: style.copyWith(color: color)),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}
