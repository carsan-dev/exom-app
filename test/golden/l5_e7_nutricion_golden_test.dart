// L5-E7 «Nutrición y detalle de comida» goldens
// (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8 and section 5.3): the plan
// of the day (breakfast done, lunch queued to sync) and the meal detail (lunch
// with options, badges and ingredients), in dark and light at text scale 1.0
// and 1.6 on the 390x844 surface of the L0 baseline, without animation.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e7_nutricion_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../features/diets/diets_redesign_fixture.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden nutricion_$suffix', (tester) async {
        await pumpDietsScene(tester, brightness: brightness, textScale: scale);
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/nutricion_$suffix.png'),
        );
      });
      testWidgets('golden detalle_comida_$suffix', (tester) async {
        await pumpMealSheetScene(
          tester,
          brightness: brightness,
          textScale: scale,
        );
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/detalle_comida_$suffix.png'),
        );
      });
    }
  }
}
