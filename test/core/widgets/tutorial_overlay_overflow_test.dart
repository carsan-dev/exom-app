import 'package:exom_app/core/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

// L5-F2 emulator defect D4: the «Siguiente» button of the drawer step (7,
// «Recap semanal») overflowed the dots + button row by 0.75 px.
void main() {
  const sizes = [(411.0, 914.0), (360.0, 800.0), (320.0, 640.0)];
  for (final (width, height) in sizes) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('step 7 has no overflow at ${width}dp x$scale', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          TutorialOverlay(
            onNavigate: (_) {},
            onOpenDrawer: () {},
            onCloseDrawer: () {},
            onComplete: () {},
            drawerItemKeys: const [],
          ),
          width: width,
          height: height,
          textScale: scale,
          wrapInScaffold: false,
        );
        for (var i = 0; i < 6; i++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(find.text('Recap semanal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
