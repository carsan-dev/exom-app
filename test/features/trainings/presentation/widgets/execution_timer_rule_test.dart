// L5-E3e: the timer of a timed set carries the 50-mark rule of the rest
// ([RestTickRule], `.x-ticks`) with its scale «0 · N s» (`.x-stops`) under the
// clock line. The rule shows the current phase: what is left of it over its
// duration, read from the same deadline-derived elapsed time as the clock
// (`state.elapsedAt(now)`), so a paused timer leaves it still and a finished
// one leaves every mark off. Each phase (e.g. «Corre» / «Camina») restarts the
// rule and its scale shows that phase's length; the trimmed last phase shows
// the length it really has.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart';
import '../pages/active_exercise_redesign_test.dart' show pumpActiveExercise;
import '../pages/circuit_test_harness.dart';

const _intervals = TimedPrescription(
  unit: TimeDisplayUnit.minutes,
  segments: [
    TimedSegment(action: 'Corre', seconds: 120, unit: TimeDisplayUnit.minutes),
    TimedSegment(action: 'Camina', seconds: 60, unit: TimeDisplayUnit.minutes),
  ],
);

final _t0 = DateTime(2026, 11, 26, 10);

ActiveExerciseState timerState({
  required int totalSeconds,
  TimedPrescription? prescription,
  int elapsedMs = 0,
  DateTime? startedAt,
}) => ActiveExerciseState(
  timedTotalSeconds: totalSeconds,
  timedPrescription: prescription,
  timedElapsedMs: elapsedMs,
  timedStartedAt: startedAt,
  currentSet: 1,
  totalSets: 1,
  completedSets: 0,
  repsOrDuration: '${totalSeconds}s',
  weightKg: null,
  setPerformances: const [],
  restSeconds: 0,
  status: ActiveExerciseStatus.executing,
  restEndsAt: null,
);

/// Pumps the bare timer for [state] with the clock [now].
Future<void> pumpTimer(
  WidgetTester tester,
  ActiveExerciseState state, {
  required DateTime Function() now,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  bool disableAnimations = false,
  Locale locale = const Locale('es'),
}) => pumpComponent(
  tester,
  SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ExecutionTimer(state: state, now: now),
  ),
  brightness: brightness,
  width: width,
  height: height,
  textScale: textScale,
  textScaler: textScaler,
  disableAnimations: disableAnimations,
  locale: locale,
);

Finder get _rule => find.descendant(
  of: find.byType(ExecutionTimer),
  matching: find.byType(RestTickRule),
);

double ruleValue(WidgetTester tester) =>
    tester.widget<RestTickRule>(_rule).value;

Finder _inTimer(String text) =>
    find.descendant(of: find.byType(ExecutionTimer), matching: find.text(text));

void main() {
  testWidgets('single phase: the rule drains with the deadline-derived time '
      'and the scale reads «0 · 60 s»', (tester) async {
    var now = _t0.add(const Duration(seconds: 15));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
    );
    expect(_rule, findsOneWidget);
    expect(ruleValue(tester), closeTo(45 / 60, 1e-9));
    expect(_inTimer('0'), findsOneWidget);
    expect(_inTimer('60 s'), findsOneWidget);

    // The existing 200 ms refresh repaints it: no other timer is involved.
    now = _t0.add(const Duration(milliseconds: 30500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(29.5 / 60, 1e-9));

    now = _t0.add(const Duration(seconds: 59));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(1 / 60, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('not started: the rule is full', (tester) async {
    await pumpTimer(tester, timerState(totalSeconds: 45), now: () => _t0);
    expect(ruleValue(tester), 1.0);
    expect(_inTimer('45 s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('paused: the rule stays still while the wall clock runs', (
    tester,
  ) async {
    var now = _t0;
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, elapsedMs: 20000),
      now: () => now,
    );
    expect(ruleValue(tester), closeTo(40 / 60, 1e-9));
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(40 / 60, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phases: the rule restarts in each phase and the scale shows '
      'its length', (tester) async {
    // 1440 s of «Corre 2 min / Camina 1 min».
    var now = _t0.add(const Duration(seconds: 60));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 1440, prescription: _intervals, startedAt: _t0),
      now: () => now,
    );
    expect(_inTimer('Ahora: Corre'), findsOneWidget);
    expect(ruleValue(tester), closeTo(60 / 120, 1e-9));
    expect(_inTimer('120 s'), findsOneWidget);

    // Just before the change: almost empty.
    now = _t0.add(const Duration(milliseconds: 119900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(0.1 / 120, 1e-9));

    // «Camina» starts: full again, scale of 60 s.
    now = _t0.add(const Duration(seconds: 120));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_inTimer('Ahora: Camina'), findsOneWidget);
    expect(ruleValue(tester), 1.0);
    expect(_inTimer('60 s'), findsOneWidget);
    expect(_inTimer('120 s'), findsNothing);

    now = _t0.add(const Duration(seconds: 125));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(55 / 60, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  // r2: the phase, the marks and the scale come from the same frame as the
  // value; before, they waited for the 200 ms refresh, so the first frames of
  // «Camina» painted its fill over the marks and scale of «Corre».
  testWidgets('phase boundary: marks and scale change in the same frame as '
      'the value, before the 200 ms refresh', (tester) async {
    var now = _t0.add(const Duration(milliseconds: 119950));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 1440, prescription: _intervals, startedAt: _t0),
      now: () => now,
    );
    expect(tester.widget<RestTickRule>(_rule).totalSeconds, 120);
    now = _t0.add(const Duration(milliseconds: 120050));
    // One ticker frame, well before the next 200 ms refresh.
    await tester.pump(const Duration(milliseconds: 16));
    final rule = tester.widget<RestTickRule>(_rule);
    expect(rule.totalSeconds, 60);
    expect(rule.value, closeTo(59.95 / 60, 1e-9));
    expect(
      tester
          .widget<RestTickScale>(
            find.descendant(
              of: find.byType(ExecutionTimer),
              matching: find.byType(RestTickScale),
            ),
          )
          .totalSeconds,
      60,
    );
    expect(_inTimer('60 s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the live rule and its scale repaint on their own layer', (
    tester,
  ) async {
    final now = _t0.add(const Duration(seconds: 10));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
    );
    final boundary = find.descendant(
      of: find.byType(LiveTickRule),
      matching: find.byType(RepaintBoundary),
    );
    expect(find.ancestor(of: _rule, matching: boundary), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(RestTickScale), matching: boundary),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('trimmed last phase: the scale shows the length it really has', (
    tester,
  ) async {
    // 150 s: «Corre» 120 s, then «Camina» trimmed to 30 s.
    var now = _t0.add(const Duration(seconds: 130));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 150, prescription: _intervals, startedAt: _t0),
      now: () => now,
    );
    expect(_inTimer('Ahora: Camina'), findsOneWidget);
    expect(_inTimer('30 s'), findsOneWidget);
    expect(ruleValue(tester), closeTo(20 / 30, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('finished: every mark is off and the scale keeps the last '
      'phase', (tester) async {
    var now = _t0.add(const Duration(seconds: 140));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 150, prescription: _intervals, startedAt: _t0),
      now: () => now,
    );
    now = _t0.add(const Duration(seconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_inTimer('Tiempo finalizado'), findsOneWidget);
    expect(ruleValue(tester), 0.0);
    expect(_inTimer('30 s'), findsOneWidget);
    // No mark is painted in the data colour.
    final data = tester.element(_rule).exomPalette.data;
    final lit = find.descendant(
      of: _rule,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == data,
      ),
    );
    expect(lit, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the rule and its scale are hidden from screen readers and '
      'nothing is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => _t0.add(const Duration(seconds: 15)),
    );
    expect(find.bySemanticsLabel(RegExp(r'^60 s$')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^0$')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Tramo: 0:45')),
      findsOneWidget,
      reason: 'the clock line keeps its semantics',
    );
    final root = tester.getSemantics(find.byType(ExecutionTimer));
    void visit(SemanticsNode node) {
      expect(
        node.getSemanticsData().flagsCollection.isLiveRegion,
        isFalse,
        reason: 'no live region: ${node.label}',
      );
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: the marks change by state, no animation is '
      'added', (tester) async {
    var now = _t0.add(const Duration(seconds: 15));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
      disableAnimations: true,
    );
    expect(_rule, findsOneWidget);
    // Nothing animates the rule between the timer and the marks.
    expect(
      find.descendant(
        of: find.byType(ExecutionTimer),
        matching: find.ancestor(
          of: _rule,
          matching: find.byWidgetPredicate(
            (w) => w is ImplicitlyAnimatedWidget || w is TweenAnimationBuilder,
          ),
        ),
      ),
      findsNothing,
    );
    now = _t0.add(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(0.5, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  for (final scale in const [1.6, 2.0]) {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('320 dp at text scale $scale (${locale.languageCode}, '
          'nonlinear): no overflow with the rule and a long scale', (
        tester,
      ) async {
        await pumpTimer(
          tester,
          timerState(
            totalSeconds: 3600,
            prescription: const TimedPrescription(
              unit: TimeDisplayUnit.minutes,
              segments: [
                TimedSegment(
                  action: 'Corre',
                  seconds: 1800,
                  unit: TimeDisplayUnit.minutes,
                ),
                TimedSegment(
                  action: 'Camina',
                  seconds: 1800,
                  unit: TimeDisplayUnit.minutes,
                ),
              ],
            ),
            startedAt: _t0,
          ),
          now: () => _t0.add(const Duration(seconds: 100)),
          width: 320,
          height: 640,
          textScaler: AndroidNonlinearTextScaler(scale),
          locale: locale,
        );
        expect(_rule, findsOneWidget);
        expectNoOverflow(tester);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('active exercise: the timed set shows the rule under the '
      'clock', (tester) async {
    await pumpActiveExercise(
      tester,
      exercise: const TrainingExerciseEntity(
        id: 'plank',
        order: 0,
        sets: 2,
        repsOrDuration: '45s',
        measureType: ExerciseMeasureType.seconds,
        targetValue: 45,
        restSeconds: 30,
        exercise: ExerciseEntity(
          id: 'ex-plank',
          name: 'Plancha',
          muscleGroups: [],
        ),
      ),
    );
    expect(find.byType(ExecutionTimer), findsOneWidget);
    expect(_rule, findsOneWidget);
    expect(ruleValue(tester), 1.0);
    expect(_inTimer('45 s'), findsOneWidget);
    final clockLine = tester.getRect(find.textContaining('Tramo: 0:45'));
    expect(tester.getRect(_rule).top, greaterThan(clockLine.bottom));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('circuit: the interval timer shows the rule', (tester) async {
    final timed = circuitExercise(
      't',
      'Plancha',
      measureType: ExerciseMeasureType.seconds,
      targetValue: 45,
      repsOrDuration: '45s',
    );
    await pumpCircuit(tester, exercises: [timed, circuitExercise('b', 'Remo')]);
    expect(find.byType(CircuitExecutionTimer), findsOneWidget);
    expect(_rule, findsOneWidget);
    expect(ruleValue(tester), 1.0);
    expect(_inTimer('45 s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
