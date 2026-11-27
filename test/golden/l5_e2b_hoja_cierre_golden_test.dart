// L5-E2b «Hoja de cierre (RPE y nota)» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// CC 8): the closing sheet «Terminar sesión» over the finished session detail,
// in dark and light at text scale 1.0 and 1.6 on 390x844, with no RPE chosen
// (the sketch `f-fin-hoja` state: «Terminar sesión» inactive) and, at 1.0,
// with an RPE chosen (the action turns lime). The session still has its
// exercise pending, so the sheet shows the warning that confirming marks it as
// completed (owner decision 2026-11-25). The scene is the harness of
// training_completion_sheet_test.dart (the `detalle_hecho` scene of
// redesign_scenes.dart cannot reach the sheet: it has no execution to select).
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e2b_hoja_cierre_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/pages/training_completion_sheet_test.dart'
    show pumpCompletionSheet;
import 'redesign_scenes.dart' show loadRedesignFonts;

Future<void> _openSheet(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
}) async {
  await loadRedesignFonts();
  await initializeDateFormatting('es');
  await pumpCompletionSheet(
    tester,
    brightness: brightness,
    textScaler: TextScaler.linear(scale),
    pending: true,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';

      testWidgets('golden hoja_cierre_$suffix', (tester) async {
        await _openSheet(tester, brightness: brightness, scale: scale);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/hoja_cierre_$suffix.png'),
        );
      });
    }

    testWidgets('golden hoja_cierre_rpe_${brightness.name}_1_0x', (
      tester,
    ) async {
      await _openSheet(tester, brightness: brightness, scale: 1.0);
      await tester.tap(find.byKey(const Key('completion-rpe-8')));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/hoja_cierre_rpe_${brightness.name}_1_0x.png'),
      );
    });
  }
}
