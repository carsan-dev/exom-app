// L5-F4 «Hoja de técnica» goldens (docs/plans/rediseno-app-l5-contrato-v2.md;
// sketch f-resto.html, frames f4-video and f4-texto): the technique sheet with
// and without video, in dark and light, at text scale 1.0 on 390x844 and at
// 1.6 on 320x640 (the compact phone of f4-texto). No thumbnail: the preview
// shows its raised surface with the square play button. The scene is the
// harness of exercise_technique_sheet_test.dart.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_f4_hoja_tecnica_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/widgets/exercise_technique_sheet_test.dart'
    show pumpTechniqueSheet;

void main() {
  for (final hasVideo in const [true, false]) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        final name =
            'hoja_tecnica_${hasVideo ? 'video' : 'texto'}_'
            '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';

        testWidgets('golden $name', (tester) async {
          await pumpTechniqueSheet(
            tester,
            hasVideo: hasVideo,
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            size: scale == 1.0 ? const Size(390, 844) : const Size(320, 640),
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
}
