// Redesign L5-E3e goldens: the timer of a timed set with the rule of the rest
// (L5-D48, «N1 · Barra con tic») under the clock line. Scene: 24 min of
// «Corre 2 min / Camina 1 min», running, 60 s into the first «Corre» (half of
// the bar lit, scale «0 · 30 · 60 · 90 · 120 s»), in dark and light at text
// scale 1.0 and 1.6 on 390x844, with an injected clock.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e3e_cronometro_golden_test.dart
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/trainings/presentation/widgets/execution_timer_rule_test.dart'
    show pumpTimer, ruleValue, timerState;

const _intervals = TimedPrescription(
  unit: TimeDisplayUnit.minutes,
  segments: [
    TimedSegment(action: 'Corre', seconds: 120, unit: TimeDisplayUnit.minutes),
    TimedSegment(action: 'Camina', seconds: 60, unit: TimeDisplayUnit.minutes),
  ],
);

void main() {
  final start = DateTime(2026, 11, 26, 10);
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'cronometro_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpTimer(
          tester,
          timerState(
            totalSeconds: 1440,
            prescription: _intervals,
            startedAt: start,
          ),
          now: () => start.add(const Duration(seconds: 60)),
          brightness: brightness,
          textScale: scale,
        );
        expect(ruleValue(tester), 0.5);
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
