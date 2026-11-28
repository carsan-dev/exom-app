// Alignment of the active exercise sections (owner report on the last-set
// reminder: «PREPÁRATE PARA GRABAR y la de justo debajo están desalineadas»).
// Measured on the real layout (see alignment_probe.dart): every section
// starts its text 20 dp from the start edge and ends its controls 20 dp from
// the end edge (`.pad`), the separators are single (no stacked rules, no
// empty strip between two rules) and the gaps follow the sketch tokens
// (`f-ej-ult`, `f-ej-ult-off`: `.stack.g8` inside the band, `mt24` between
// sections).
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/active_exercise_set_chips.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_exercise_redesign_test.dart'
    show activeExerciseDraftKey, activeExerciseTrainingId, pumpActiveExercise;
import 'alignment_probe.dart';
import 'last_set_video_test_support.dart';

const _width = 390.0;
const _start = 20.0;
const _end = _width - 20;
const _band = Key('last-set-video-reminder');
const _off = Key('last-set-video-reminder-off');

/// Set [current] of 3 executing; [weights] false reproduces the owner's
/// capture (no weight today, no previous session: «Sin datos anteriores»).
ActiveWorkoutHiveModel _seedAt(int current, {bool weights = true}) =>
    ActiveWorkoutHiveModel(
      trainingId: activeExerciseTrainingId,
      exerciseId: activeExerciseDraftKey,
      currentSet: current,
      completedSets: current - 1,
      lastWeightKg: weights ? 62.5 : null,
      completedSetData: [
        for (var set = 1; set < current; set++)
          {
            'set_number': set,
            'reps': 8,
            if (weights) 'weight_kg': 62.5,
            'rir': 2,
          },
      ],
    );

Future<void> _frames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required int current,
  bool video = false,
  bool reminder = true,
  bool weights = true,
  Brightness brightness = Brightness.light,
  TrainingExerciseEntity? exercise,
  ActiveWorkoutHiveModel? seed,
}) async {
  await pumpActiveExercise(
    tester,
    exercise: exercise,
    initialWeightKg: weights ? 62.5 : null,
    seed: seed ?? _seedAt(current, weights: weights),
    requiresLastSetVideo: video,
    lastSetVideoReminder: reminder,
    brightness: brightness,
    width: _width,
    registerExtra: () =>
        sl.registerSingleton<FeedbackUploadQueueService>(RecordingVideoQueue()),
  );
  await _frames(tester);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ActiveExercisePage)));

Finder get _scroll => find
    .descendant(
      of: find.byType(ActiveExercisePage),
      matching: find.byType(SingleChildScrollView),
    )
    .first;

Finder _kicker(String text) =>
    find.byWidgetPredicate((w) => w is ExomKicker && w.text == text);

/// Measured [value] for [label]; kept as a named step so each measurement
/// reads as such in the test body.
double _m(String label, double value) => value;

/// Mismatches of the current test, reported together at its end so one
/// failing measure does not hide the others.
final _failures = <String>[];

void _check(double value, Matcher matcher, String label) {
  _m(label, value);
  if (!matcher.matches(value, <Object?, Object?>{})) {
    _failures.add(
      '$label = ${value.toStringAsFixed(1)}, expected '
      '${matcher.describe(StringDescription())}',
    );
  }
}

void _expectNoFailures() {
  final failures = [..._failures];
  _failures.clear();
  expect(failures, isEmpty);
}

void _expectRules(WidgetTester tester) {
  final problems = probeRuleProblems(tester, _scroll, _width);
  _failures.addAll(problems);
}

/// The sections shared by every executing state: headline, load columns,
/// «Series» and the set list start 20 from the start edge.
void _expectExecutingSections(WidgetTester tester, AppLocalizations l10n) {
  _check(
    tester.getTopLeft(find.byType(ExomTwoLineHeadline)).dx,
    equals(_start),
    'headline.left',
  );
  _check(
    probeTextLeft(tester, find.byType(ExomFigureColumns)),
    equals(_start),
    'cols.label.left',
  );
  _check(
    tester.getTopLeft(_kicker(l10n.sets)).dx,
    equals(_start),
    'series.left',
  );
  final chips = tester.getRect(find.byType(ActiveExerciseSetChips));
  _check(chips.left, equals(_start), 'chips.left');
  _check(chips.right, equals(_end), 'chips.right');
}

void main() {
  testWidgets('normal set: sections share the 20 dp margins and single '
      'separators', (tester) async {
    await _pump(tester, current: 1);
    final l10n = _l10n(tester);
    expect(find.byKey(_band), findsNothing);
    _expectExecutingSections(tester, l10n);
    _expectRules(tester);
    _expectNoFailures();
  });

  for (final weights in [true, false]) {
    testWidgets('last-set band on (weights: $weights): kicker, message and '
        '«Recordármelo» on the page margins, no rule inside, no empty strip '
        'before it and the g8 / mt24 rhythm', (tester) async {
      await _pump(tester, current: 3, video: true, weights: weights);
      final l10n = _l10n(tester);
      _expectExecutingSections(tester, l10n);
      final band = tester.getRect(find.byKey(_band));
      final kicker = tester.getRect(
        find.descendant(
          of: find.byKey(_band),
          matching: find.byType(ExomKicker),
        ),
      );
      final message = tester.getRect(find.text(l10n.currentLastSetMessage));
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
      final cols = tester.getRect(find.byType(ExomFigureColumns));
      final series = tester.getRect(_kicker(l10n.sets));

      _check(kicker.left, equals(_start), 'band.kicker.left');
      _check(message.left, equals(_start), 'band.message.left');
      _check(message.right, lessThanOrEqualTo(_end), 'band.message.right');
      _check(label.left, equals(_start), 'band.switch.label.left');
      _check(track.right, equals(_end), 'band.switch.right');
      _check(band.width, equals(_width), 'band.width');

      _m('cols.bottom', cols.bottom);
      _m('band.top', band.top);
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
      _check(series.top - band.bottom, equals(24), 'series.top-band.bottom');

      // No separator crosses the band between its own top and bottom rules.
      final inside = probeFullWidthRules(
        tester,
        _scroll,
        _width,
      ).where((rule) => rule.y > band.top + 1.5 && rule.y < band.bottom - 1.5);
      for (final rule in inside) {
        _failures.add('rule inside the band: $rule');
      }
      _expectRules(tester);
      _expectNoFailures();
    });
  }

  testWidgets('last-set reminder off: the minimal line on the page margins, '
      'no empty strip before it and mt24 after it', (tester) async {
    await _pump(tester, current: 3, video: true, reminder: false);
    final l10n = _l10n(tester);
    _expectExecutingSections(tester, l10n);
    final off = tester.getRect(find.byKey(_off));
    final label = tester.getRect(find.text(l10n.lastSetVideoRemindMe));
    final track = tester.getRect(
      find.descendant(
        of: find.byKey(_off),
        matching: find.byKey(const Key('exom-switch-track')),
      ),
    );
    final series = tester.getRect(_kicker(l10n.sets));
    _check(label.left, equals(_start), 'off.label.left');
    _check(track.right, equals(_end), 'off.switch.right');
    _check(off.height, greaterThanOrEqualTo(48), 'off.height');
    _m('off.top', off.top);
    _m('cols.bottom', tester.getRect(find.byType(ExomFigureColumns)).bottom);
    _check(series.top - off.bottom, equals(24), 'series.top-off.bottom');
    _expectRules(tester);
    _expectNoFailures();
  });

  testWidgets('rest: headline, countdown, next-set band and chips share the '
      '20 dp margins and single separators', (tester) async {
    await _pump(tester, current: 1);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const ValueKey('footer-executing')));
    await _frames(tester, 3);
    await tester.tap(find.byKey(const Key('set-sheet-save')));
    await _frames(tester, 6);
    _check(
      tester.getTopLeft(find.byType(ExomTwoLineHeadline)).dx,
      equals(_start),
      'rest.headline.left',
    );
    _check(
      tester.getTopLeft(_kicker(l10n.activeExerciseNextLabel)).dx,
      equals(_start),
      'rest.next.kicker.left',
    );
    _check(
      tester.getTopLeft(find.byKey(const Key('active-exercise-rest-next'))).dx,
      equals(_start),
      'rest.next.text.left',
    );
    final chips = tester.getRect(find.byType(ActiveExerciseSetChips));
    _check(chips.left, equals(_start), 'rest.chips.left');
    _check(chips.right, equals(_end), 'rest.chips.right');
    _expectRules(tester);
    _expectNoFailures();
  });

  // A timed set shows the execution timer between the load columns (or the
  // last-set band) and «Series»: one more section, mt24 above and below it.
  for (final video in [false, true]) {
    testWidgets('timed set (band: $video): the execution timer is a section '
        'of its own, 24 below the block above and 24 above «Series»', (
      tester,
    ) async {
      await _pump(
        tester,
        current: 2,
        video: video,
        weights: false,
        exercise: _plank,
        seed: ActiveWorkoutHiveModel(
          trainingId: activeExerciseTrainingId,
          exerciseId: activeExerciseDraftKey,
          currentSet: 2,
          completedSets: 1,
          completedSetData: const [
            {'set_number': 1, 'seconds': 45},
          ],
        ),
      );
      final l10n = _l10n(tester);
      expect(find.byKey(_band), video ? findsOneWidget : findsNothing);
      final above = tester.getRect(
        video ? find.byKey(_band) : find.byType(ExomFigureColumns),
      );
      final timer = tester.getRect(find.byType(ExecutionTimer));
      final series = tester.getRect(_kicker(l10n.sets));
      _check(timer.top - above.bottom, equals(24), 'timer.top-above.bottom');
      _check(series.top - timer.bottom, equals(24), 'series.top-timer.bottom');
      _check(
        probeTextLeft(tester, find.byType(ExecutionTimer)),
        equals(_start),
        'timer.text.left',
      );
      _check(timer.left, equals(_start), 'timer.left');
      _check(timer.right, equals(_end), 'timer.right');
      _expectRules(tester);
      _expectNoFailures();
    });
  }
}

const _plank = TrainingExerciseEntity(
  id: 'te-1',
  order: 1,
  sets: 2,
  repsOrDuration: '45s',
  measureType: ExerciseMeasureType.seconds,
  targetValue: 45,
  restSeconds: 0,
  requestSetTracking: true,
  exercise: ExerciseEntity(id: 'ex-1', name: 'Plancha', muscleGroups: []),
);
