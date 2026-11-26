// L5-E8 «Lista de la compra» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// E8, CC 4 and CC 8; sketch e-migradas.html, frames f-compra and
// f-compra-lista): «Elige tus alternativas» (three meals with an alternative,
// main options chosen) and the list (ten products, two marked), in dark and
// light at text scale 1.0 and 1.6 on the 390x844 surface of the L0 baseline,
// without animation. Both scenes check tap targets and, in light, no lime ink.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e8_lista_compra_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../core/widgets/expect_no_lime_ink.dart';
import '../features/diets/shopping_list_scene.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden lista_compra_eleccion_$suffix', (tester) async {
        await pumpShoppingSetupScene(
          tester,
          brightness: brightness,
          textScale: scale,
        );
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        expectNoLimeInk(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/lista_compra_eleccion_$suffix.png'),
        );
      });
      testWidgets('golden lista_compra_$suffix', (tester) async {
        await pumpShoppingListScene(
          tester,
          brightness: brightness,
          textScale: scale,
        );
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        expectNoLimeInk(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/lista_compra_$suffix.png'),
        );
      });
    }
  }
}
