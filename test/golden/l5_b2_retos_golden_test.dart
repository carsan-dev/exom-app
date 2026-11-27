// L5-B2 «Retos» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8 and
// section 5.3): the main scene (title, the streak milestone, the main goal with
// its 50-mark rule, the numbered weekly challenges and the achievement tiles)
// and the «all achievements» sheet, in dark and light at text scale 1.0 and
// 1.6 on the 390x844 surface of the L0 baseline; plus a 40-day streak (L5-D40,
// the 4-week cap) in dark and light at 1.0.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts (loadRedesignFonts), so regenerate on the same
// OS with:
//   flutter test --update-goldens test/golden/l5_b2_retos_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/challenges/challenges_test_support.dart';

void main() {
  for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${mode.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden retos_$suffix', (tester) async {
        await pumpChallengesPage(
          tester,
          FakeChallengesRepository(),
          height: 844,
          mode: mode,
          textScaler: TextScaler.linear(scale),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/retos_$suffix.png'),
        );
      });

      if (scale == 1.0) {
        // L5-D40: a 40-day streak fills the 4 weeks of the grid and sums up
        // the rest with «+14 días anteriores».
        testWidgets('golden retos_racha_40_$suffix', (tester) async {
          await pumpChallengesPage(
            tester,
            FakeChallengesRepository(streakDays: 40),
            height: 844,
            mode: mode,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/retos_racha_40_$suffix.png'),
          );
        });
      }

      testWidgets('golden retos_logros_$suffix', (tester) async {
        await pumpChallengesPage(
          tester,
          FakeChallengesRepository(),
          height: 844,
          mode: mode,
          textScaler: TextScaler.linear(scale),
        );
        await openAchievementsBoard(tester, 'Ver todos');
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/retos_logros_$suffix.png'),
        );
      });
    }
  }
}
