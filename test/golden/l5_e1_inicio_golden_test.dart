// L5-E1 «Inicio» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8):
// the new «Sin plan. / Todavía.» scene (L5-D27), a day the calendar shows
// without assignment, in dark and light at text scale 1.0 and 1.6 on the
// 390x844 surface of the L0 baseline. The session and rest-day scenes of
// Inicio (`inicio_*`, `inicio_descanso_*`) stay in
// redesign_baseline_golden_test.dart.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e1_inicio_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign_scenes.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          '${RedesignScene.inicioSinPlan.slug}_${brightness.name}_'
          '${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        final handle = await pumpRedesignScene(
          tester,
          RedesignScene.inicioSinPlan,
          theme: redesignTheme(brightness),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
        await handle.dispose(tester);
      });
    }
  }
}
