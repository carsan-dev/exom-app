// L5-C5b «Aviso de domingo» goldens: the in-app Sunday recap reminder (same
// component as the quick-tour prompt, with the «No volver a mostrar» row) in
// light and dark on 360x800, Spanish.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c5b_aviso_domingo_golden_test.dart
import 'package:exom_app/core/widgets/recap_sunday_prompt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';
    testWidgets('golden aviso_domingo_$theme', (tester) async {
      await pumpComponent(
        tester,
        RecapSundayPromptDialog(
          onFill: () {},
          onSkip: () {},
          dontShowAgain: false,
          onDontShowAgainChanged: (_) {},
        ),
        brightness: brightness,
        width: 360,
        height: 800,
        disableAnimations: true,
      );
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/aviso_domingo_$theme.png'),
      );
    });
  }
}
