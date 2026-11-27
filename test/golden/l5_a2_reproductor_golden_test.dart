// Redesign L5-A2 golden «Reproductor de vídeo» (docs/plans/
// rediseno-app-l5-contrato-v2.md, sections 3.0 CC 8 and 5.3), main scene with
// the controls visible, in dark and light at text scale 1.0 and 1.6 on the
// 390x844 baseline surface. The frame is static: a fake controller paints no
// video (a black stage), so the golden shows the chrome only.
//
// The player is pure black in both themes (sketch A3), so the dark and light
// goldens are expected to match. A second scene keeps the base page's full
// screen video in landscape (640x360), with the chrome over it (decision
// L5-A2 after review F1), and a third the overlay with a vertical 9:16 clip
// on the 390x844 phone (review F3), where the flat veil sits behind the
// chrome. Same platform rules as
// redesign_baseline_golden_test.dart (generated on Windows); regenerate with:
//   flutter test --update-goldens test/golden/l5_a2_reproductor_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';
import '../features/trainings/presentation/pages/exercise_video_player_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'reproductor_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpPlayer(tester, brightness: brightness, textScale: scale);
        await tester.pump(const Duration(milliseconds: 400));
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });

      final landscape =
          'reproductor_horizontal_${brightness.name}_'
          '${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $landscape', (tester) async {
        await pumpPlayer(
          tester,
          brightness: brightness,
          textScale: scale,
          width: 640,
          height: 360,
        );
        await tester.pump(const Duration(milliseconds: 400));
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$landscape.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });

      final vertical =
          'reproductor_vertical_9x16_${brightness.name}_'
          '${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $vertical', (tester) async {
        await pumpPlayer(
          tester,
          brightness: brightness,
          textScale: scale,
          videoSize: const Size(720, 1280),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$vertical.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
