// L5-E6a «Sesión terminada» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// CC 8): the milestone «Sesión hecha» after a server-confirmed completion, in
// dark and light at text scale 1.0 and 1.6 (Android non-linear scaler) on
// 390x844, Spanish. No animation of its own (that is L5-E6b): this is its only
// state. The scene is the harness of training_milestone_test.dart.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e6a_hito_sesion_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/android_nonlinear_text_scaler.dart';
import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/pages/training_milestone_test.dart'
    show pumpMilestone;
import 'redesign_scenes.dart' show loadRedesignFonts;

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';

      testWidgets('golden hito_sesion_$suffix', (tester) async {
        await loadRedesignFonts();
        await initializeDateFormatting('es');
        await pumpMilestone(
          tester,
          brightness: brightness,
          textScaler: scale == 1.0
              ? TextScaler.noScaling
              : AndroidNonlinearTextScaler(scale),
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/hito_sesion_$suffix.png'),
        );
      });
    }
  }
}
