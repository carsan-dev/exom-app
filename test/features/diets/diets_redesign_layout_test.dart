// L5-E7 · CC 3 and CC 4 for «Nutrición» and «Detalle de comida»: no overflow
// at 320 dp (1.3x, 1.6x) and 360 dp (1.6x) in es and en, all the content
// reachable by scrolling at 2.0x, and tap targets >= 48 dp in both themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../../core/widgets/expect_no_lime_ink.dart';
import 'diets_redesign_fixture.dart';

const _surfaces = [(320.0, 1.3), (320.0, 1.6), (360.0, 1.6)];
const _locales = [Locale('es'), Locale('en')];

void main() {
  group('Nutrición layout', () {
    for (final (width, scale) in _surfaces) {
      for (final locale in _locales) {
        testWidgets(
          'no overflow at ${width}dp x$scale, ${locale.languageCode}',
          (tester) async {
            await pumpDietsScene(
              tester,
              width: width,
              height: 640,
              textScale: scale,
              locale: locale,
            );
            expectNoOverflow(tester);
            await tester.scrollUntilVisible(
              find.byKey(const Key('diet-shopping-list-row')),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            expectNoOverflow(tester);
          },
        );
        testWidgets('empty day at ${width}dp x$scale, ${locale.languageCode}', (
          tester,
        ) async {
          await pumpDietsScene(
            tester,
            noPlan: true,
            width: width,
            height: 640,
            textScale: scale,
            locale: locale,
          );
          expectNoOverflow(tester);
        });
      }
    }

    testWidgets('at 2.0x everything is reachable by scrolling', (tester) async {
      await pumpDietsScene(tester, width: 320, height: 640, textScale: 2.0);
      for (final key in const [
        Key('meal-row-m-dinner'),
        Key('diet-shopping-list-row'),
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(key),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expectNoOverflow(tester);
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('tap targets and ink, ${brightness.name}', (tester) async {
        await pumpDietsScene(tester, brightness: brightness);
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
      });
    }
  });

  group('Detalle de comida layout', () {
    for (final (width, scale) in _surfaces) {
      for (final locale in _locales) {
        testWidgets(
          'no overflow at ${width}dp x$scale, ${locale.languageCode}',
          (tester) async {
            await pumpMealSheetScene(
              tester,
              width: width,
              height: 640,
              textScale: scale,
              locale: locale,
            );
            expectNoOverflow(tester);
          },
        );
      }
    }

    testWidgets('at 2.0x the ingredients are reachable by scrolling', (
      tester,
    ) async {
      await pumpMealSheetScene(tester, width: 320, height: 640, textScale: 2.0);
      await tester.scrollUntilVisible(
        find.text('Aceite de oliva'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expectNoOverflow(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('tap targets and ink, ${brightness.name}', (tester) async {
        await pumpMealSheetScene(tester, brightness: brightness);
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
      });
    }
  });
}
