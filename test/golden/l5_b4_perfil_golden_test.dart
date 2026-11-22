// L5-B4 «Perfil» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8):
// the main scene (identity, headline, the weight in the featured block, the
// flat muscle mass and sleep blocks and the start of the index) and the muscle
// mass goal sheet, in dark and light at text scale 1.0 and 1.6 on 390x844,
// without animation.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_b4_perfil_golden_test.dart
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/profile/presentation/profile_scene.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';

      testWidgets('golden perfil_$suffix', (tester) async {
        await pumpProfileScene(
          tester,
          brightness: brightness,
          textScaler: TextScaler.linear(scale),
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/perfil_$suffix.png'),
        );
      });

      testWidgets('golden perfil_hoja_objetivo_$suffix', (tester) async {
        await pumpProfileScene(
          tester,
          brightness: brightness,
          textScaler: TextScaler.linear(scale),
        );
        final edit = find.byKey(const Key('profile-muscle-goal-edit'));
        await revealInProfile(tester, edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/perfil_hoja_objetivo_$suffix.png'),
        );
      });
    }
  }

  // Round 3 (O3): no weight history: the sketch's empty chart (grid and base)
  // under the kicker, then «Sin datos / todavía.».
  for (final brightness in Brightness.values) {
    testWidgets('golden perfil_sin_datos_${brightness.name}_1_0x', (
      tester,
    ) async {
      await pumpProfileScene(
        tester,
        brightness: brightness,
        profiles: SceneProfileRepository(
          loads: [
            const ProfileEntity(
              id: 'user-a',
              firstName: 'Ana',
              lastName: 'Ruiz',
              level: 'INTERMEDIATE',
              goal: 'GAIN_MUSCLE',
              heightCm: 168,
              streakDays: 12,
            ),
          ],
        ),
        metrics: SceneMetricsRepository(),
      );
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/perfil_sin_datos_${brightness.name}_1_0x.png',
        ),
      );
    });
  }
}
