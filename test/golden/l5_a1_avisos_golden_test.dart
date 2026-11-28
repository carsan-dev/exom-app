// Redesign L5-A1 golden (docs/plans/rediseno-app-l5-contrato-v2.md, L5-A1 and
// section 5.3): the «Avisos» screen with read and unread notifications, in dark
// and light at text scale 1.0 and 1.6 on a 390x844 surface. Skeleton-free and
// without animation (disableAnimations), so the image does not depend on a
// pulse; relative times come from ages fixed in the middle of their range.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_a1_avisos_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../core/widgets/expect_no_lime_ink.dart';
import '../features/notifications/notifications_test_support.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'avisos_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        final repo = FakeNotificationsRepository(mainSceneItems());
        await pumpNotificationsPage(
          tester,
          repo,
          brightness: brightness,
          textScale: scale,
          disableAnimations: true,
        );
        expectNoOverflow(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await expectTapTargetGuidelines(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
