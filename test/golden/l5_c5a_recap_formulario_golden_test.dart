// L5-C5a «Recap, formulario por pasos» goldens (docs/plans/
// rediseno-app-l5-contrato-v2.md, CC 8): the main scene (step 1, «Entreno»:
// step header with its rule, the trainer's line, the rating chips, the numeric
// field and the pinned action) in dark and light at text scale 1.0 and 1.6 on
// 390x844, without animation. The clock is fixed (Thursday 19 Nov 2026).
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c5a_recap_formulario_golden_test.dart
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart'
    show kRecapCoachAvatar;
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/recap/presentation/pages/recap_form_redesign_test.dart'
    show pumpRecapForm;

/// Decodes the trainer photo of the coach blocks (real I/O, outside the fake
/// clock) so the golden shows it and not an empty square.
Future<void> _showCoachPhoto(WidgetTester tester) async {
  final coach = find.byType(ExomCoachBlock);
  if (coach.evaluate().isEmpty) return;
  await tester.runAsync(
    () => precacheImage(kRecapCoachAvatar, tester.element(coach.first)),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  tearDown(() async => sl.reset());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${theme}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden recap_formulario_$suffix', (tester) async {
        await pumpRecapForm(
          tester,
          step: 1,
          dark: dark,
          textScaler: TextScaler.linear(scale),
        );
        await _showCoachPhoto(tester);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/recap_formulario_$suffix.png'),
        );
      });
    }
  }
}
