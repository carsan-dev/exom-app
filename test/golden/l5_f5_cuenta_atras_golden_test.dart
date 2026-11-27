// L5-F5 «Cuenta atrás de inicio» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// sketch `f-resto.html` frames f5-cuenta and f5-160): the countdown dialog at
// «3 s» (three of five segments lit) over a plain page, in dark and light at
// text scale 1.0 and 1.6 on 390x844; the 160 % frame again at 320 dp; and the
// reduced motion frame, captured 40 ms after the figure changed (with full
// motion it would still be fading in; reduced, it has already cut).
//
// The scene is the harness of execution_start_countdown_redesign_test.dart,
// which opens the dialog like `execution_timer.dart` with an injected clock.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_f5_cuenta_atras_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/widgets/execution_start_countdown_redesign_test.dart'
    show CountdownClock, pumpStartCountdown;

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';

      testWidgets('golden cuenta_atras_$suffix', (tester) async {
        final clock = CountdownClock();
        await pumpStartCountdown(
          tester,
          clock: clock,
          brightness: brightness,
          textScale: scale,
        );
        await clock.advance(tester, const Duration(milliseconds: 2500));
        await clock.advance(tester, const Duration(milliseconds: 300));
        expect(find.text('3'), findsOneWidget);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cuenta_atras_$suffix.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('golden cuenta_atras_dark_1_6x_320', (tester) async {
    final clock = CountdownClock();
    await pumpStartCountdown(
      tester,
      clock: clock,
      width: 320,
      height: 640,
      textScale: 1.6,
    );
    await clock.advance(tester, const Duration(milliseconds: 2500));
    await clock.advance(tester, const Duration(milliseconds: 300));
    expectNoOverflow(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cuenta_atras_dark_1_6x_320.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });

  // Halfway through the 180 ms change «5» -> «4»: only one figure is drawn
  // (the old one already left, the new one is fading in); before the fix the
  // two digits overlapped at half opacity as a lime block.
  testWidgets('golden cuenta_atras_transicion_dark_1_0x', (tester) async {
    final clock = CountdownClock();
    await pumpStartCountdown(tester, clock: clock);
    await clock.advance(tester, const Duration(milliseconds: 950));
    await clock.advance(tester, const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 90));
    expectNoOverflow(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cuenta_atras_transicion_dark_1_0x.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('golden cuenta_atras_reducido_dark_1_0x', (tester) async {
    final clock = CountdownClock();
    await pumpStartCountdown(tester, clock: clock, disableAnimations: true);
    await clock.advance(tester, const Duration(milliseconds: 300));
    // 1950 ms in: «4». The next tick reaches 3000 ms remaining: «3».
    await clock.advance(tester, const Duration(milliseconds: 1650));
    expect(find.text('4'), findsOneWidget);
    await clock.advance(tester, const Duration(milliseconds: 50));
    await clock.advance(tester, const Duration(milliseconds: 40));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    expectNoOverflow(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cuenta_atras_reducido_dark_1_0x.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
