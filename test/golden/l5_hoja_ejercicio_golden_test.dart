// L5-D47 «Hoja del ejercicio» goldens (docs/plans/rediseno-exom-app.md, tanda
// HOJA-EJERCICIO; sketch extension/g-hoja-ejercicio.html, variant «A · media
// arriba» with alternative F): the exercise sheet open at 70 % over the
// training detail, in progress («Continuar ejercicio», lime, pinned) and
// completed («Editar datos» and «Marcar como pendiente»), in dark and light at
// text scale 1.0 on 390x844. The exercise has a video and no thumbnail, so the
// media shows the neutral fill with the play square. The scene is the harness
// of training_detail_redesign_test.dart.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_hoja_ejercicio_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/pages/training_detail_redesign_test.dart'
    show ExerciseSheetScene, pumpExerciseSheet;
import 'redesign_scenes.dart' show loadRedesignFonts;

void main() {
  for (final scene in ExerciseSheetScene.values) {
    for (final brightness in Brightness.values) {
      final name =
          'hoja_ejercicio_'
          '${scene == ExerciseSheetScene.inProgress ? 'en_curso' : 'completado'}_'
          '${brightness.name}_1_0x';

      testWidgets('golden $name', (tester) async {
        await loadRedesignFonts();
        await initializeDateFormatting('es');
        await pumpExerciseSheet(tester, scene: scene, brightness: brightness);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
