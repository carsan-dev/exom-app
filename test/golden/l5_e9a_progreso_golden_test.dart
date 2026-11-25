// L5-E9a «Progreso» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8
// and section 5.3): the screen at the top (headline, weight at 96 and chart)
// and scrolled to the end (measurement columns and the photos entry), in dark
// and light at text scale 1.0 and 1.6 on the 390x844 surface of the L0
// baseline, without animation.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e9a_progreso_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../features/metrics/metrics_progress_redesign_fixture.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden progreso_$suffix', (tester) async {
        await pumpProgressScene(
          tester,
          brightness: brightness,
          textScale: scale,
        );
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/progreso_$suffix.png'),
        );
      });
      testWidgets('golden progreso_medidas_$suffix', (tester) async {
        await pumpProgressScene(
          tester,
          brightness: brightness,
          textScale: scale,
        );
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -4000),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/progreso_medidas_$suffix.png'),
        );
      });
    }
  }
}
