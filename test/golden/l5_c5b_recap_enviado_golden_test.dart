// L5-C5b «Recap, Enviado» goldens: the screen after a confirmed send (owner
// decision 2026-11-25: no band and no numeral; kicker «Recap semanal», headline
// with the check to its right, full rule, week, confirmed state, trainer note
// and the pinned «Volver a recaps») in light and dark on 360x800, Spanish, in
// its final state (sweep and check finished).
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts (loadRedesignFonts), so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c5b_recap_enviado_golden_test.dart
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart'
    show kRecapCoachAvatar;
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/recap/presentation/pages/recap_sent_redesign_test.dart'
    show sendRecapFromForm;
import 'redesign_scenes.dart' show loadRedesignFonts;

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
  setUpAll(() async {
    await initializeDateFormatting('es');
    await loadRedesignFonts();
  });
  tearDown(() async => sl.reset());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('golden recap_enviado_$theme', (tester) async {
      await sendRecapFromForm(tester, dark: dark, width: 360, height: 800);
      await _showCoachPhoto(tester);
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/recap_enviado_$theme.png'),
      );
    });
  }
}
