// L5-C3 «Recap, detalle» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// CC 8): the main scene (header, headline, trainer comment with «Nuevo» and the
// first numbered sections) in dark and light at text scale 1.0 and 1.6 on
// 390x844, without animation.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_c3_recap_detalle_golden_test.dart
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/recap/presentation/pages/recap_detail_redesign_test.dart'
    show pumpDetail, recapDetailFilled;

void main() {
  tearDown(() async => sl.reset());

  for (final dark in [true, false]) {
    for (final scale in const [1.0, 1.6]) {
      final suffix =
          '${dark ? 'dark' : 'light'}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden recap_detalle_$suffix', (tester) async {
        await pumpDetail(
          tester,
          extra: recapDetailFilled,
          dark: dark,
          width: 390,
          height: 844,
          textScaler: TextScaler.linear(scale),
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/recap_detalle_$suffix.png'),
        );
      });
    }
  }
}
