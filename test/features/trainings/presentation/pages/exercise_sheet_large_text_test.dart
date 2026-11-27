// L5-D63 (OBS-4): with the app fonts at text scale 1,6 on a 390x844 phone,
// the exercise sheet (with its media) opens showing the name and the level
// («Intermedio») above the pinned foot. The test font is larger than the app
// fonts, so this is measured with the bundled ones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;
import 'training_detail_redesign_test.dart'
    show ExerciseSheetScene, pumpExerciseSheet;

void main() {
  for (final scene in ExerciseSheetScene.values) {
    testWidgets('1.6 (${scene.name}): name and level above the foot', (
      tester,
    ) async {
      await loadRedesignFonts();
      await initializeDateFormatting('es');
      await pumpExerciseSheet(
        tester,
        scene: scene,
        brightness: Brightness.dark,
        textScaler: const AndroidNonlinearTextScaler(1.6),
      );
      final sheet = find.byType(BottomSheet);
      final level = find.descendant(
        of: sheet,
        matching: find.text('Intermedio'),
      );
      final footer = find.byKey(const Key('exercise-sheet-footer'));
      expect(level, findsOneWidget);
      expect(
        tester.getBottomLeft(level).dy,
        lessThanOrEqualTo(tester.getTopLeft(footer).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
