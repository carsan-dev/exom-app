// L5-E3d «Vídeo preparado» goldens: the last-set video sheet after choosing a
// clip, with its first frame in the 56 dp box and its duration on the set
// line («Serie 4 · 8 × 62,5 kg · 0:42»), in dark and light at text scale 1.0
// on 390x844 and at 1.6 (Android's nonlinear scaler) on 320x640. The frame is
// the fake preview of local_video_preview_fake.dart (a vertical 720x1280
// gradient), so the golden checks the box, the crop and the line, not a real
// decoder.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e3d_video_preparado_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/android_nonlinear_text_scaler.dart';
import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/widgets/local_video_preview_fake.dart'
    show FakePreviewFactory, pumpLastSetVideoSheet;

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'video_preparado_${brightness.name}_'
          '${scale == 1.0 ? '1_0x' : '1_6x'}';

      testWidgets('golden $name', (tester) async {
        await pumpLastSetVideoSheet(
          tester,
          factory: FakePreviewFactory(),
          brightness: brightness,
          textScaler: scale == 1.0
              ? TextScaler.noScaling
              : AndroidNonlinearTextScaler(scale),
          size: scale == 1.0 ? const Size(390, 844) : const Size(320, 640),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake-video-frame')), findsOneWidget);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
