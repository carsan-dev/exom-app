// Redesign L5-C1 golden (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8): the
// «Subidas pendientes» scene (one evidence sending, one failed, one failed
// sync action) in dark and light at text scale 1.0 and 1.6 on 390x844, without
// animation.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c1_subidas_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/feedback/presentation/pages/pending_uploads_scene.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'subidas_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpScene(tester, brightness: brightness, textScale: scale);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
