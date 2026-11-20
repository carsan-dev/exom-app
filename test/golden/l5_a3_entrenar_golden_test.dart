// L5-A3 «Entrenar: lista e historial» goldens
// (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8 and section 5.3): the main
// scene (one local session pending completion, today's training and the month
// history) in dark and light at text scale 1.0 and 1.6 on the 390x844 surface
// of the L0 baseline, with the «Continuar sesión» footer.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts (loadRedesignFonts), so regenerate on the same
// OS with:
//   flutter test --update-goldens test/golden/l5_a3_entrenar_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';
import '../features/trainings/presentation/pages/trainings_redesign_fixture.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'entrenar_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpTrainingsScene(
          tester,
          state: sceneLoaded(),
          storage: SceneStorage(scenePending()),
          brightness: brightness,
          textScale: scale,
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
