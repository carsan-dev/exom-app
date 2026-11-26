// Alignment of Entrenar (L5-A3, sketch `a-diario` «Entrenar · sin
// pendiente»): the «Historial» band must not open an empty strip between two
// rules under a day block that already closes with a rule (the figure
// columns of the session, or the group of the other trainings of the day);
// it shares that rule instead, as the active exercise band does. After a
// block without a closing rule (rest day) the 24 gap stays. Measured on the
// real layout (alignment_probe.dart).
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/features/trainings/presentation/pages/trainings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'alignment_probe.dart';
import 'trainings_redesign_fixture.dart';

const _width = 390.0;

Finder get _list => find
    .descendant(of: find.byType(TrainingsPage), matching: find.byType(ListView))
    .first;

Finder get _historyBand => find.byType(ExomBand).last;

void main() {
  for (final (label, today) in [
    ('one training (figure columns)', [kSceneTraining]),
    ('two trainings (row group)', [kSceneTraining, kSceneTraining]),
    ('rest day (no rule above)', const <Never>[]),
  ]) {
    testWidgets('$label: single separators above «Historial», kicker on '
        'the 20 margin', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(today: today),
        brightness: Brightness.light,
      );
      await tester.pump(const Duration(milliseconds: 400));
      final band = tester.getRect(_historyBand);
      final kicker = tester.getRect(
        find.descendant(of: _historyBand, matching: find.byType(ExomKicker)),
      );
      final problems = probeRuleProblems(tester, _list, _width);
      expect(kicker.left, 20);
      final top = band.top.toStringAsFixed(1);
      expect(
        problems.where((p) => p.contains('rule y=$top ')),
        isEmpty,
        reason: 'empty strip right above «Historial»',
      );
      // The strips left between two rules are spacing tokens of the sketch
      // `a-diario` (alignment r3): 16 (`ExomSpacing.lg`, `.mt16` like every
      // block of the day) plus the 1 dp rule between the columns and the
      // group of the other trainings, and the 20 of `.x-band{padding:20px 0}`
      // between the last history row and the band's bottom rule.
      for (final problem in problems) {
        final gap = RegExp(r'empty strip of ([\d.]+) dp').firstMatch(problem);
        expect(gap, isNotNull, reason: problem);
        expect(
          double.parse(gap!.group(1)!),
          anyOf(ExomSpacing.lg + 1, ExomSpacing.xl),
          reason: problem,
        );
      }
    });
  }
}
