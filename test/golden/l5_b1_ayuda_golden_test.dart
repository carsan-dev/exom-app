// L5-B1 «Ayuda» goldens (docs/plans/rediseno-app-l5-contrato-v2.md, CC 8 and
// section 5.3): the main scene (headline, coach block, the numbered FAQ with
// «uso sin conexión» open and the support band) in dark and light at text scale
// 1.0 and 1.6 on the 390x844 surface of the L0 baseline.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts (loadRedesignFonts), so regenerate on the same
// OS with:
//   flutter test --update-goldens test/golden/l5_b1_ayuda_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/features/help/presentation/pages/help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'ayuda_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpComponent(
          tester,
          const HelpPage(),
          brightness: brightness,
          textScale: scale,
          disableAnimations: true,
          wrapInScaffold: false,
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
