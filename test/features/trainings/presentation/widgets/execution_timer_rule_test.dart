// L5-E3e, L5-D48: the timer of a timed set carries the rule of the rest,
// «N1 · Barra con tic» ([RestStepRule]: one bar in the data colour over the
// rule tone and a scale of 3 to 5 marks) under the clock line. The bar shows
// the current phase: the whole seconds left of it over its length, read from
// the same deadline-derived elapsed time as the clock (`state.elapsedAt(now)`),
// so a paused timer leaves it still and a finished one leaves it empty. It
// steps once a second, on the boundary of the figures, in 140 ms; each phase
// (e.g. «Corre» / «Camina») starts a fresh, full bar without animating and
// its scale shows that phase's length; the trimmed last phase shows the
// length it really has.
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
  matching: find.byType(RestStepRule),
);

/// Share of the phase the bar stands for (its target, whole seconds).
double ruleValue(WidgetTester tester) =>
    tester.widget<RestStepRule>(_rule).value;

/// Painted share of the bar: lit width over the track width.
double _painted(WidgetTester tester) =>
    tester
        .getSize(
          find.descendant(
            of: _rule,
            matching: find.byKey(const Key('rest-step-bar')),
          ),
        )
        .width /
    tester
        .getSize(
          find.descendant(
            of: _rule,
            matching: find.byKey(const Key('rest-step-track')),
          ),
        )
        .width;

List<String> _labels(WidgetTester tester) => [
  for (final element
      in find.descendant(of: _rule, matching: find.byType(Text)).evaluate())
    (element.widget as Text).data!,
];

Finder _inTimer(String text) =>
    find.descendant(of: find.byType(ExecutionTimer), matching: find.text(text));

/// Moves the fake clock until [left] remains before [end], arriving with a
/// last 16 ms frame as on a device.
Future<void> _reach(WidgetTester tester, DateTime end, Duration left) async {
  const frame = Duration(milliseconds: 16);
  await tester.pump(end.difference(tester.binding.clock.now()) - left - frame);
  await tester.pump(frame);
}

void main() {
  testWidgets('single phase: the bar shows the whole seconds left and the '
      'scale reads «0 · 15 · 30 · 45 · 60 s»', (tester) async {
    var now = _t0.add(const Duration(seconds: 15));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
    );
    expect(_rule, findsOneWidget);
    expect(ruleValue(tester), closeTo(45 / 60, 1e-9));
    expect(_painted(tester), closeTo(45 / 60, 1e-9));
    expect(_labels(tester), ['0', '15', '30', '45', '60 s']);

    // The existing 200 ms refresh repaints it: no other timer is involved.
    now = _t0.add(const Duration(milliseconds: 30500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(30 / 60, 1e-9));

    now = _t0.add(const Duration(seconds: 59));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(1 / 60, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('not started: the bar is full', (tester) async {
    await pumpTimer(tester, timerState(totalSeconds: 45), now: () => _t0);
    expect(ruleValue(tester), 1.0);
    expect(_painted(tester), 1.0);
    expect(_labels(tester), ['0', '15', '30', '45 s']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('paused: the bar stays still while the wall clock runs', (
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
    expect(_painted(tester), closeTo(40 / 60, 1e-9));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phases: the bar restarts in each phase and the scale shows '
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
    expect(_labels(tester), ['0', '30', '60', '90', '120 s']);

    // Just before the change: the last second.
    now = _t0.add(const Duration(milliseconds: 119900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(1 / 120, 1e-9));

    // «Camina» starts: full again, scale of 60 s.
    now = _t0.add(const Duration(seconds: 120));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_inTimer('Ahora: Camina'), findsOneWidget);
    expect(ruleValue(tester), 1.0);
    expect(_labels(tester), ['0', '15', '30', '45', '60 s']);

    now = _t0.add(const Duration(seconds: 125));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(55 / 60, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phase boundary: bar and scale change with the figures, before '
      'the 200 ms refresh, and the new phase starts full without '
      'animating', (tester) async {
    DateTime now() => tester.binding.clock.now();
    final startedAt = now().subtract(const Duration(milliseconds: 119950));
    await pumpTimer(
      tester,
      timerState(
        totalSeconds: 1440,
        prescription: _intervals,
        startedAt: startedAt,
      ),
      now: now,
    );
    expect(tester.widget<RestStepRule>(_rule).totalSeconds, 120);
    expect(_painted(tester), closeTo(1 / 120, 1e-9));
    // The figure timer fires on the boundary, 50 ms in.
    await tester.pump(const Duration(milliseconds: 60));
    expect(_inTimer('Ahora: Camina'), findsOneWidget);
    final rule = tester.widget<RestStepRule>(_rule);
    expect(rule.totalSeconds, 60);
    expect(rule.value, 1.0);
    expect(_labels(tester), ['0', '15', '30', '45', '60 s']);
    expect(_painted(tester), 1.0);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bar and figures change on the same whole second; the step '
      'lasts 140 ms and no ticker runs in between', (tester) async {
    DateTime now() => tester.binding.clock.now();
    // Started 10.5 s ago: the 200 ms refresh runs out of phase.
    final startedAt = now().subtract(const Duration(milliseconds: 10500));
    final deadline = startedAt.add(const Duration(seconds: 60));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: startedAt),
      now: now,
    );
    expect(find.textContaining('Tramo: 0:50'), findsOneWidget);
    for (var k = 49; k >= 1; k--) {
      await _reach(tester, deadline, Duration(milliseconds: k * 1000 - 1));
      final figure = formatRestClock(k);
      expect(
        find.text('Tramo: $figure · Total restante: $figure'),
        findsOneWidget,
        reason: '$k',
      );
      expect(tester.widget<RestStepRule>(_rule).remainingSeconds, k);
      expect(_painted(tester), closeTo((k + 1) / 60, 1e-9), reason: '$k');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(_painted(tester), closeTo(k / 60, 1e-9), reason: 'step $k');
      // The ticker lets go on the first frame after the 140 ms.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0, reason: '$k');
    }
    await _reach(tester, deadline, Duration.zero);
    expect(find.text('Tiempo finalizado'), findsOneWidget);
    expect(ruleValue(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the bar repaints on its own layer', (tester) async {
    final now = _t0.add(const Duration(seconds: 10));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('rest-step-bar')),
        matching: find.descendant(
          of: _rule,
          matching: find.byType(RepaintBoundary),
        ),
      ),
      findsWidgets,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('trimmed last phase: the scale shows the length it really has', (
    tester,
  ) async {
    // 150 s: «Corre» 120 s, then «Camina» trimmed to 30 s.
    final now = _t0.add(const Duration(seconds: 130));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 150, prescription: _intervals, startedAt: _t0),
      now: () => now,
    );
    expect(_inTimer('Ahora: Camina'), findsOneWidget);
    expect(_labels(tester), ['0', '10', '20', '30 s']);
    expect(ruleValue(tester), closeTo(20 / 30, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('finished: the bar is empty and the scale keeps the last '
      'phase', (tester) async {
    var now = _t0.add(const Duration(seconds: 140));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 150, prescription: _intervals, startedAt: _t0),
      now: () => now,
    );
    now = _t0.add(const Duration(seconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_inTimer('Tiempo finalizado'), findsOneWidget);
    expect(ruleValue(tester), 0.0);
    expect(_painted(tester), 0.0);
    expect(_labels(tester).last, '30 s');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the bar and its scale are hidden from screen readers and '
      'nothing is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => _t0.add(const Duration(seconds: 15)),
    );
    expect(find.bySemanticsLabel(RegExp(r'^60 s$')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^0$')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^45$')), findsNothing);
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

  testWidgets('reduced motion: the bar jumps once a second, no ticker', (
    tester,
  ) async {
    var now = _t0.add(const Duration(seconds: 15));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
      disableAnimations: true,
    );
    expect(_painted(tester), closeTo(45 / 60, 1e-9));
    now = _t0.add(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ruleValue(tester), closeTo(0.5, 1e-9));
    expect(_painted(tester), closeTo(0.5, 1e-9));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the same bar and scale colours as the '
        'rest', (tester) async {
      await pumpTimer(
        tester,
        timerState(totalSeconds: 60, startedAt: _t0),
        now: () => _t0.add(const Duration(seconds: 15)),
        brightness: brightness,
      );
      final palette = tester.element(_rule).exomPalette;
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byKey(const Key('rest-step-bar')),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        palette.data,
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const Key('rest-step-track')))
            .color,
        palette.borderSoft,
      );
      for (final label
          in find
              .descendant(of: _rule, matching: find.byType(Text))
              .evaluate()) {
        expect((label.widget as Text).style?.color, palette.textSecondary);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

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

  // Round r2 of CRONO: the scale depends only on the total and the width, so
  // the 200 ms refresh and the steps of the bar leave it alone (no LayoutBuilder
  // pass, no TextPainter). Its widgets stay the very same instances.
  testWidgets('the 200 ms refresh does not rebuild the scale', (tester) async {
    var now = _t0.add(const Duration(milliseconds: 10100));
    await pumpTimer(
      tester,
      timerState(totalSeconds: 60, startedAt: _t0),
      now: () => now,
    );
    final scale = find.byKey(const Key('rest-step-scale'));
    Widget layout() => tester.widget(
      find.descendant(of: scale, matching: find.byType(LayoutBuilder)),
    );
    List<Widget> labels() => [
      for (final e
          in find.descendant(of: scale, matching: find.byType(Text)).evaluate())
        e.widget,
    ];
    final layoutBefore = layout();
    final labelsBefore = labels();
    expect(labelsBefore, hasLength(5));
    // 2 s: ten refreshes and two whole seconds of the bar.
    for (var i = 0; i < 10; i++) {
      now = now.add(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(ruleValue(tester), closeTo(48 / 60, 1e-9));
    expect(identical(layout(), layoutBefore), isTrue);
    final labelsAfter = labels();
    expect(labelsAfter, hasLength(labelsBefore.length));
    for (var i = 0; i < labelsAfter.length; i++) {
      expect(identical(labelsAfter[i], labelsBefore[i]), isTrue, reason: '$i');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
