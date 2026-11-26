// Alignment of the active circuit sections around the last-round reminder
// (the same band as the active exercise, sketch `f-circ-ult`). Measured on
// the real layout (see alignment_probe.dart): text 20 dp from the start edge,
// controls 20 dp from the end edge, single separators and the sketch gaps
// (`.stack.g8` inside the band, `mt24` before «Esta ronda»).
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'alignment_probe.dart';
import 'circuit_test_harness.dart';

const _width = 390.0;
const _start = 20.0;
const _end = _width - 20;
const _band = Key('last-set-video-reminder');
const _off = Key('last-set-video-reminder-off');

Finder get _scroll => find
    .descendant(
      of: find.byType(ActiveCircuitPage),
      matching: find.byType(SingleChildScrollView),
    )
    .first;

final _failures = <String>[];

void _check(double value, Matcher matcher, String label) {
  if (!matcher.matches(value, <Object?, Object?>{})) {
    _failures.add(
      '$label = ${value.toStringAsFixed(1)}, expected '
      '${matcher.describe(StringDescription())}',
    );
  }
}

void _expectRulesAndFailures(WidgetTester tester) {
  _failures.addAll(probeRuleProblems(tester, _scroll, _width));
  final failures = [..._failures];
  _failures.clear();
  expect(failures, isEmpty);
}

/// One-round circuit (its only round is the last one) with a required video.
/// [previous] gives the first exercise a «Última vez» column; [rest] its
/// «Descanso después» line (none at 0: the band then follows the columns).
Future<void> _pump(
  WidgetTester tester, {
  bool reminder = true,
  bool previous = false,
  int rest = 0,
}) async {
  await pumpCircuit(
    tester,
    exercises: [
      circuitExercise('a', 'Burpees', restSeconds: rest),
      circuitExercise('b', 'Sentadilla con salto'),
    ],
    rounds: 1,
    requiresLastSetVideo: true,
    lastSetVideoReminder: reminder,
    previous: previous
        ? const {
            'a': [SetPerformance(setNumber: 1, reps: 10)],
          }
        : const {},
    brightness: Brightness.light,
  );
  await settleFrames(tester);
}

void main() {
  for (final (previous, rest) in [(false, 0), (true, 30), (true, 0)]) {
    testWidgets('last-round band on (previous: $previous, rest: $rest): page '
        'margins, no rule inside, single separators, g8 / mt24 rhythm', (
      tester,
    ) async {
      await _pump(tester, previous: previous, rest: rest);
      final l10n = circuitL10n(tester);
      final band = tester.getRect(find.byKey(_band));
      final kicker = tester.getRect(
        find.descendant(
          of: find.byKey(_band),
          matching: find.byType(ExomKicker),
        ),
      );
      final message = tester.getRect(
        find.text(l10n.lastSetReminderMessage('Burpees')),
      );
      final row = tester.getRect(
        find.descendant(
          of: find.byKey(_band),
          matching: find.byType(ExomSwitchRow),
        ),
      );
      final label = tester.getRect(find.text(l10n.lastSetVideoRemindMe));
      final track = tester.getRect(
        find.descendant(
          of: find.byKey(_band),
          matching: find.byKey(const Key('exom-switch-track')),
        ),
      );
      final title = tester.getRect(
        find.text(l10n.circuitThisRound.toUpperCase()),
      );

      _check(kicker.left, equals(_start), 'band.kicker.left');
      _check(message.left, equals(_start), 'band.message.left');
      _check(message.right, lessThanOrEqualTo(_end), 'band.message.right');
      _check(label.left, equals(_start), 'band.switch.label.left');
      _check(track.right, equals(_end), 'band.switch.right');
      _check(title.left, equals(_start), 'round.title.left');
      _check(kicker.top - band.top, equals(20), 'band.kicker.top-band.top');
      _check(
        message.top - kicker.bottom,
        equals(8),
        'message.top-kicker.bottom',
      );
      _check(
        row.top - message.bottom,
        equals(8),
        'switchrow.top-message.bottom',
      );
      _check(row.height, greaterThanOrEqualTo(48), 'switchrow.height');
      _check(
        band.bottom - row.bottom,
        equals(20),
        'band.bottom-switchrow.bottom',
      );
      _check(
        title.top - band.bottom,
        equals(24),
        'round.title.top-band.bottom',
      );
      final inside = probeFullWidthRules(
        tester,
        _scroll,
        _width,
      ).where((rule) => rule.y > band.top + 1.5 && rule.y < band.bottom - 1.5);
      for (final rule in inside) {
        _failures.add('rule inside the band: $rule');
      }
      _expectRulesAndFailures(tester);
    });
  }

  for (final (previous, rest) in [(false, 0), (true, 0)]) {
    testWidgets('last-round reminder off (previous: $previous, rest: $rest): '
        'the minimal line on the page margins and single separators', (
      tester,
    ) async {
      await _pump(tester, reminder: false, previous: previous, rest: rest);
      final l10n = circuitL10n(tester);
      final off = tester.getRect(find.byKey(_off));
      final label = tester.getRect(find.text(l10n.lastSetVideoRemindMe));
      final track = tester.getRect(
        find.descendant(
          of: find.byKey(_off),
          matching: find.byKey(const Key('exom-switch-track')),
        ),
      );
      final title = tester.getRect(
        find.text(l10n.circuitThisRound.toUpperCase()),
      );
      _check(label.left, equals(_start), 'off.label.left');
      _check(track.right, equals(_end), 'off.switch.right');
      _check(off.height, greaterThanOrEqualTo(48), 'off.height');
      _check(title.top - off.bottom, equals(24), 'round.title.top-off.bottom');
      _expectRulesAndFailures(tester);
    });
  }
}
