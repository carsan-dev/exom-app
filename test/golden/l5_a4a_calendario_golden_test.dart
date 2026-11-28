// L5-A4a «Calendario» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8
// and section 5.3): the main scene (Entrenamiento tab, a past month with done,
// not done and rest days, a challenge flag and the selected day's block) in
// dark and light at text scale 1.0 and 1.6 on the 390x844 surface of the L0
// baseline.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts (loadRedesignFonts), so regenerate on the same
// OS with:
//   flutter test --update-goldens test/golden/l5_a4a_calendario_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart';
import '../features/calendar/calendar_redesign_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'calendario_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpCalendarScene(
          tester,
          state: sceneLoaded(),
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
