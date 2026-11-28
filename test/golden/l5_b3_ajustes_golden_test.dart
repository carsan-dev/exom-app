// L5-B3 «Ajustes» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8):
// the main scene (title, «Apariencia» with the three segmented controls and
// the start of «Cuenta») and the «¿Borrar la caché local?» sheet with the
// amber notice of an unfinished circuit, in dark and light at text scale 1.0
// and 1.6 on 390x844, without animation.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_b3_ajustes_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/settings/presentation/pages/settings_scene.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';

      testWidgets('golden ajustes_$suffix', (tester) async {
        await pumpSettingsScene(
          tester,
          brightness: brightness,
          textScaler: TextScaler.linear(scale),
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ajustes_$suffix.png'),
        );
      });

      testWidgets('golden ajustes_hoja_cache_$suffix', (tester) async {
        await pumpSettingsScene(
          tester,
          brightness: brightness,
          textScaler: TextScaler.linear(scale),
          storage: SceneStorage(activeCircuit: true),
        );
        final row = find.byKey(const Key('settings-clear-cache'));
        await revealInSettings(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ajustes_hoja_cache_$suffix.png'),
        );
      });
    }
  }
}
