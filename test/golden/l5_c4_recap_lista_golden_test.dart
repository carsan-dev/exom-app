// L5-C4 «Recap, lista» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// CC 8): the main scene (header, count of new trainer comments, one row per
// week and the pinned «Continuar borrador» action) in dark and light at text
// scale 1.0 and 1.6 on 390x844, plus the blocked state (recap already sent
// this week: reason in line, grey button) in both themes, without animation.
// The clock is fixed (Thursday 19 Nov 2026).
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c4_recap_lista_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/recap/presentation/pages/recap_list_redesign_test.dart'
    show pumpRecapList, recapListBlocked, recapListWithDraft;

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  tearDown(() async => sl.reset());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${theme}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden recap_lista_$suffix', (tester) async {
        await pumpRecapList(
          tester,
          recaps: recapListWithDraft(),
          dark: dark,
          textScaler: TextScaler.linear(scale),
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/recap_lista_$suffix.png'),
        );
      });
    }
    testWidgets('golden recap_lista_bloqueado_$theme', (tester) async {
      await pumpRecapList(tester, recaps: recapListBlocked(), dark: dark);
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/recap_lista_bloqueado_$theme.png'),
      );
    });
  }
}
