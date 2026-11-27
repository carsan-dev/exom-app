// L5-C5b «Muñeco del recap» goldens: the body map of the recovery step in
// treatment A «Placas» (docs/bocetos/rediseno-exom-app/extension/
// c5b-muneco.html), Frontal and Posterior with the mockup's sample selection,
// in dark and light on 360 dp, Spanish, without animation.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c5b_recap_muneco_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

/// The mockup's PRESET selection.
const _selection = <String>{
  'shoulder_left_front',
  'quadriceps_right',
  'lower_back',
  'hamstrings_left',
};

void main() {
  for (final brightness in Brightness.values) {
    for (final back in [false, true]) {
      final name =
          'recap_muneco_${brightness.name}_${back ? 'posterior' : 'frontal'}';
      testWidgets('golden $name', (tester) async {
        await pumpComponent(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RecapAnatomySelector(
                selectedZoneIds: _selection,
                onZoneSelected: (_) {},
              ),
            ),
          ),
          brightness: brightness,
          width: 360,
          height: 480,
          disableAnimations: true,
        );
        if (back) {
          await tester.tap(find.text('Posterior'));
          await tester.pumpAndSettle();
        }
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
