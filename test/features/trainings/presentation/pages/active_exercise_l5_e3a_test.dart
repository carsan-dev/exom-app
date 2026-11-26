// L5-E3a «Ejercicio activo y descanso (piel)»: structure of the new skin
// (e-migradas.html, frames «Ejercicio activo» and «Descanso»), the D19 colour
// rule of the set chips, no lime ink in the light theme, no overflow at
// 320 dp with 1.3x/1.6x and 360 dp with 1.6x in es and en (Android non-linear
// scaler), and everything reachable by scrolling at 2.0x (CC 3). The flow and
// the timers are covered, unchanged, by active_exercise_redesign_test.dart.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_overlay.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'active_exercise_redesign_test.dart'
    show activeExerciseDraftKey, activeExerciseTrainingId, pumpActiveExercise;

const _previous = [
  SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
  SetPerformance(setNumber: 2, reps: 8, weightKg: 60, rir: 2),
];

/// Set 2 of 3 after saving set 1, resting until 90 s from now.
ActiveWorkoutHiveModel _restSeed() => ActiveWorkoutHiveModel(
  trainingId: activeExerciseTrainingId,
  exerciseId: activeExerciseDraftKey,
  currentSet: 2,
  completedSets: 1,
  restEndsAt: DateTime.now().add(const Duration(seconds: 90)),
  lastWeightKg: 62.5,
  completedSetData: const [
    {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
  ],
);

/// Set 2 of 3 after saving set 1, executing.
ActiveWorkoutHiveModel _executingSeed() => ActiveWorkoutHiveModel(
  trainingId: activeExerciseTrainingId,
  exerciseId: activeExerciseDraftKey,
  currentSet: 2,
  completedSets: 1,
  lastWeightKg: 62.5,
  completedSetData: const [
    {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
  ],
);

/// All 3 sets saved, resting after the last one (final rest) for 60 s.
ActiveWorkoutHiveModel _finalRestSeed({String? sessionId}) =>
    ActiveWorkoutHiveModel(
      trainingId: activeExerciseTrainingId,
      exerciseId: sessionId == null
          ? activeExerciseDraftKey
          : '$activeExerciseDraftKey:$sessionId',
      sessionId: sessionId,
      currentSet: 3,
      completedSets: 3,
      restEndsAt: DateTime.now().add(const Duration(seconds: 60)),
      lastWeightKg: 62.5,
      completedSetData: const [
        {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
        {'set_number': 2, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
        {'set_number': 3, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
      ],
    );

const _firstEx = TrainingExerciseEntity(
  id: 'te-0',
  order: 0,
  sets: 3,
  repsOrDuration: '5',
  restSeconds: 120,
  exercise: ExerciseEntity(id: 'ex-0', name: 'Sentadilla', muscleGroups: []),
);

/// Same id as the pumped exercise (`te-1`).
const _secondEx = TrainingExerciseEntity(
  id: 'te-1',
  order: 1,
  sets: 3,
  repsOrDuration: '8',
  restSeconds: 90,
  exercise: ExerciseEntity(
    id: 'ex-1',
    name: 'Sentadilla búlgara',
    muscleGroups: [],
  ),
);

const _thirdEx = TrainingExerciseEntity(
  id: 'te-2',
  order: 2,
  sets: 3,
  repsOrDuration: '10',
  restSeconds: 90,
  exercise: ExerciseEntity(id: 'ex-2', name: 'Press', muscleGroups: []),
);

const _circuitEx = TrainingExerciseEntity(
  id: 'te-c',
  order: 0,
  sets: 3,
  repsOrDuration: '12',
  restSeconds: 30,
  blockId: 'b1',
  blockName: 'Core rápido',
  exercise: ExerciseEntity(id: 'ex-c', name: 'Plancha', muscleGroups: []),
);

const _unnamedCircuitEx = TrainingExerciseEntity(
  id: 'te-c',
  order: 0,
  sets: 3,
  repsOrDuration: '12',
  restSeconds: 30,
  blockId: 'b1',
  exercise: ExerciseEntity(id: 'ex-c', name: 'Plancha', muscleGroups: []),
);

/// The pumped exercise (id `te-1`, same draft key) with an optional video.
TrainingExerciseEntity _bulgarianWith({String? videoUrl}) =>
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: 3,
      repsOrDuration: '8',
      measureType: ExerciseMeasureType.reps,
      targetValue: 8,
      targetRir: 2,
      restSeconds: 90,
      requestSetTracking: true,
      exercise: ExerciseEntity(
        id: 'ex-1',
        name: 'Sentadilla búlgara',
        muscleGroups: const [],
        techniqueText: 'Pie trasero apoyado en el banco.',
        videoUrl: videoUrl,
      ),
    );

ExomThemePalette _palette(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).exomPalette;

/// Colour of the first text style of a `Text` or `Text.rich` found by [finder].
Color? _inkOf(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  return text.style?.color ?? text.textSpan?.style?.color;
}

/// Font size of a `Text` or `Text.rich` found by [finder].
double? _sizeOf(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  return text.style?.fontSize ?? text.textSpan?.style?.fontSize;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('executing: «Serie N / de M.» headline, target at 140 in '
          'the data colour, load columns and «Ver técnica» link', (
        tester,
      ) async {
        await pumpActiveExercise(
          tester,
          initialWeightKg: 62.5,
          previous: _previous,
          seed: _executingSeed(),
          brightness: brightness,
        );
        final palette = _palette(tester);

        final headline = tester.widget<ExomTwoLineHeadline>(
          find.byType(ExomTwoLineHeadline),
        );
        expect(headline.first, 'Serie 2');
        expect(headline.second, 'de 3.');

        final target = find.byKey(const Key('active-exercise-target'));
        expect(target, findsOneWidget);
        final targetText = tester.widget<Text>(target);
        expect(targetText.style?.fontSize, ExomType.hero140.fontSize);
        expect(targetText.style?.color, palette.data);
        expect(targetText.textSpan?.toPlainText(), '8reps');
        expect(find.text('objetivo de la serie'), findsOneWidget);

        // «Tu peso» is today's figure (data, 64); «Última vez» is a
        // reference in the text colour with its reps and RIR below.
        expect(find.text('TU PESO'), findsOneWidget);
        expect(find.text('ÚLTIMA VEZ'), findsOneWidget);
        // Both columns are the shared component with the labels above, as in
        // the circuit (L5-E5 API).
        final columns = tester.widget<ExomFigureColumns>(
          find.byType(ExomFigureColumns),
        );
        expect(columns.labelsAbove, isTrue);
        expect(columns.numbered, isFalse);
        expect(columns.items, hasLength(2));
        final loadItem = columns.items.first;
        expect(loadItem.itemKey, const Key('active-exercise-your-weight'));
        expect((loadItem.value, loadItem.unit), ('62,5', 'kg'));
        expect(loadItem.size, ExomFigureSize.s64);
        expect(loadItem.tone, ExomFigureTone.data);
        final referenceItem = columns.items.last;
        expect(referenceItem.itemKey, const Key('active-exercise-previous'));
        expect((referenceItem.value, referenceItem.unit), ('60', 'kg'));
        expect(referenceItem.size, ExomFigureSize.s56);
        expect(referenceItem.tone, ExomFigureTone.text);
        expect(referenceItem.detail, isNotNull);
        // The painted figures carry that tone and size.
        Finder figureIn(Key cell) => find.descendant(
          of: find.byKey(cell),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.textSpan?.toPlainText().endsWith('kg') ?? false),
          ),
        );
        final load = figureIn(const Key('active-exercise-your-weight'));
        expect(tester.widget<Text>(load).textSpan?.toPlainText(), '62,5kg');
        expect(_inkOf(tester, load), palette.data);
        expect(_sizeOf(tester, load), ExomType.hero64.fontSize);
        final reference = figureIn(const Key('active-exercise-previous'));
        expect(tester.widget<Text>(reference).textSpan?.toPlainText(), '60kg');
        expect(_inkOf(tester, reference), palette.textPrimary);
        expect(_sizeOf(tester, reference), 56);
        expect(find.text('8 reps · RIR 2'), findsOneWidget);

        expect(find.text('SERIES'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is ExomTextLink && w.label == 'Ver técnica',
          ),
          findsOneWidget,
        );
        // One lime action per state (principle 15): only «Registrar serie».
        expect(find.byType(ExomPrimaryButton), findsOneWidget);
        expectNoLimeInk(tester);
      });

      testWidgets('set chips (D19): a done set carries a data-coloured top '
          'rule and check, never the phone icon', (tester) async {
        await pumpActiveExercise(
          tester,
          initialWeightKg: 62.5,
          previous: _previous,
          seed: _executingSeed(),
          brightness: brightness,
        );
        final palette = _palette(tester);
        final chip = find.byKey(const ValueKey('set-chip-1'));
        final check = find.descendant(
          of: chip,
          matching: find.byIcon(ExomIcons.check),
        );
        expect(check, findsOneWidget);
        expect(tester.widget<Icon>(check).color, palette.data);
        expect(
          find.descendant(of: chip, matching: find.byIcon(ExomIcons.phone)),
          findsNothing,
        );
        final rule = find.descendant(
          of: chip,
          matching: find.byKey(const ValueKey('set-chip-done-rule')),
        );
        expect(rule, findsOneWidget);
        expect(tester.widget<ColoredBox>(rule).color, palette.data);
        expect(tester.getSize(rule).height, 3);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('set-chip-2')),
            matching: find.byKey(const ValueKey('set-chip-done-rule')),
          ),
          findsNothing,
        );
      });

      testWidgets('rest: «Descanso. / Después, serie N.», countdown at 140 '
          'with the 50-mark rule, next set in a band, no lime button', (
        tester,
      ) async {
        await pumpActiveExercise(
          tester,
          initialWeightKg: 62.5,
          previous: _previous,
          seed: _restSeed(),
          brightness: brightness,
        );
        await _settle(tester);
        final palette = _palette(tester);

        final headline = tester.widget<ExomTwoLineHeadline>(
          find.byType(ExomTwoLineHeadline),
        );
        expect(headline.first, 'Descanso.');
        expect(headline.second, 'Después, serie 2.');

        final clock = find.byKey(const Key('rest-countdown-clock'));
        final clockText = tester.widget<Text>(clock);
        expect(clockText.style?.fontSize, ExomType.hero140.fontSize);
        expect(clockText.style?.color, palette.data);
        expect(
          find.byKey(const ValueKey('rest-countdown-mark')),
          findsNWidgets(50),
        );
        expect(find.text('0'), findsOneWidget);
        expect(find.text('90 s'), findsOneWidget);

        final band = find.byType(ExomBand);
        expect(band, findsOneWidget);
        expect(
          find.descendant(of: band, matching: find.text('SIGUIENTE')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: band, matching: find.text('SERIE 2')),
          findsOneWidget,
        );
        expect(find.byType(ExomPrimaryButton), findsNothing);
        expect(
          find.byKey(const Key('active-exercise-rest-extend')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('active-exercise-rest-skip')),
          findsOneWidget,
        );
        expectNoLimeInk(tester);
      });
    });
  }

  group('rest after the last set (v2, decision 2026-11-26)', () {
    for (final brightness in Brightness.values) {
      testWidgets('«Descanso. / Después, <next exercise>.» with the '
          '«Siguiente» band naming it (${brightness.name})', (tester) async {
        await pumpActiveExercise(
          tester,
          initialWeightKg: 62.5,
          previous: _previous,
          seed: _finalRestSeed(),
          brightness: brightness,
        );
        await _settle(tester);
        final headline = tester.widget<ExomTwoLineHeadline>(
          find.byType(ExomTwoLineHeadline),
        );
        expect(headline.first, 'Descanso.');
        // The first unfinished exercise of the training, in list order.
        expect(headline.second, 'Después, Sentadilla.');
        final band = find.byType(ExomBand);
        expect(band, findsOneWidget);
        expect(
          find.descendant(of: band, matching: find.text('SIGUIENTE')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: band, matching: find.text('SENTADILLA')),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label?.startsWith('Siguiente: Sentadilla') ??
                    false),
          ),
          findsOneWidget,
        );
        expectNoLimeInk(tester);
      });
    }

    testWidgets('last exercise of the training: «Descanso. / Ejercicio '
        'completado.» and no band', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(sessionId: 's1'),
        completedExerciseIds: const {'te-0'},
        sessionId: 's1',
        sessionProgress: const {
          's1': TrainingDayProgress(ids: {'te-0'}),
        },
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.first, 'Descanso.');
      expect(headline.second, 'Ejercicio completado.');
      expect(find.byType(ExomBand), findsNothing);
    });

    testWidgets('new execution: the day aggregate is done but this session '
        'has nothing, so the first exercise is next', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(sessionId: 's1'),
        completedExerciseIds: const {'te-0'},
        sessionId: 's1',
        sessionProgress: const {'s1': TrainingDayProgress()},
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Después, Sentadilla.');
      expect(find.byType(ExomBand), findsOneWidget);
    });

    testWidgets('no session progress at all counts as nothing done, as the '
        'detail does', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(),
        completedExerciseIds: const {'te-0'},
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Después, Sentadilla.');
    });

    testWidgets('last pending exercise with another one done in another '
        'session: nothing left in this one', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(sessionId: 's2'),
        completedExerciseIds: const {'te-0'},
        sessionId: 's2',
        sessionProgress: const {
          's1': TrainingDayProgress(ids: {'te-0'}),
          's2': TrainingDayProgress(ids: {'te-0'}),
        },
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Ejercicio completado.');
      expect(find.byType(ExomBand), findsNothing);
    });

    testWidgets('out of order: te-1 is current, te-0 done and te-2 pending '
        'makes te-2 next, not te-0', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(sessionId: 's1'),
        sessionId: 's1',
        sessionProgress: const {
          's1': TrainingDayProgress(ids: {'te-0'}),
        },
        trainingExercises: const [_firstEx, _secondEx, _thirdEx],
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Después, Press.');
    });

    testWidgets('a circuit as next is named by its block, without '
        'prescription', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(sessionId: 's1'),
        sessionId: 's1',
        sessionProgress: const {'s1': TrainingDayProgress()},
        trainingExercises: const [_circuitEx, _secondEx],
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Después, Core rápido.');
      final band = find.byType(ExomBand);
      expect(
        find.descendant(of: band, matching: find.text('CORE RÁPIDO')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: band, matching: find.textContaining('×')),
        findsNothing,
      );
    });

    testWidgets('a circuit without blockName is named «Circuito», as the '
        'detail does', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(sessionId: 's1'),
        sessionId: 's1',
        sessionProgress: const {'s1': TrainingDayProgress()},
        trainingExercises: const [_unnamedCircuitEx, _secondEx],
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Después, Circuito.');
      expect(
        find.descendant(
          of: find.byType(ExomBand),
          matching: find.text('CIRCUITO'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('in English: «Rest. / Then, <next exercise>.»', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _finalRestSeed(),
        locale: const Locale('en'),
      );
      await _settle(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.second, 'Then, Sentadilla.');
    });
  });

  testWidgets('«Ver técnica»: play icon with a video, no icon with only '
      'texts; 48 dp target (v2)', (tester) async {
    for (final (video, icon) in const [
      (null, null),
      ('https://example.com/v.mp4', ExomIcons.play),
    ]) {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: _executingSeed(),
        exercise: _bulgarianWith(videoUrl: video),
      );
      final link = find.byKey(const Key('active-exercise-technique'));
      await tester.scrollUntilVisible(
        link,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final widget = tester.widget<ExomTextLink>(link);
      expect(widget.label, 'Ver técnica');
      expect(widget.icon, icon);
      final size = tester.getSize(
        find.descendant(of: link, matching: find.byType(InkWell)),
      );
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  group('no overflow (CC 3)', () {
    const sizes = [(320.0, 1.3), (320.0, 1.6), (360.0, 1.6)];
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in sizes) {
        for (final resting in const [false, true]) {
          testWidgets('${width.toInt()}dp ${scale}x ${locale.languageCode} '
              '${resting ? 'rest' : 'executing'}', (tester) async {
            await pumpActiveExercise(
              tester,
              initialWeightKg: 62.5,
              previous: _previous,
              seed: resting ? _restSeed() : _executingSeed(),
              width: width,
              height: 640,
              locale: locale,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            await _settle(tester);
            expect(tester.takeException(), isNull);
            final scrollable = find.byType(Scrollable).first;
            for (var i = 0; i < 10; i++) {
              await tester.drag(scrollable, const Offset(0, -300));
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          });
        }
      }
    }
  });

  for (final resting in const [false, true]) {
    testWidgets('2.0x at 320x568: the last set chip is reachable by '
        'scrolling (${resting ? 'rest' : 'executing'})', (tester) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        previous: _previous,
        seed: resting ? _restSeed() : _executingSeed(),
        width: 320,
        height: 568,
        textScaler: const AndroidNonlinearTextScaler(2.0),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final last = find.byKey(const ValueKey('set-chip-3'));
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(last.hitTestable(), findsOneWidget);
    });
  }

  testWidgets('2.0x at 320x568: «Ver técnica» is reachable by scrolling '
      '(executing, v2)', (tester) async {
    await pumpActiveExercise(
      tester,
      initialWeightKg: 62.5,
      previous: _previous,
      seed: _executingSeed(),
      width: 320,
      height: 568,
      textScaler: const AndroidNonlinearTextScaler(2.0),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final link = find.byKey(const Key('active-exercise-technique'));
    await tester.scrollUntilVisible(
      link,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(link.hitTestable(), findsOneWidget);
  });

  group('rest rule motion (principle 5, CC 5)', () {
    /// Filled share of the rule: data-coloured height over 50 full marks.
    double filled(WidgetTester tester) {
      final palette = tester.element(find.byType(RestTickRule)).exomPalette;
      var total = 0.0;
      for (final element
          in find
              .descendant(
                of: find.byType(RestTickRule),
                matching: find.byType(ColoredBox),
              )
              .evaluate()) {
        if ((element.widget as ColoredBox).color == palette.data) {
          total += element.size!.height;
        }
      }
      return total / (RestTickRule.count * RestTickRule.height);
    }

    for (final reduced in const [false, true]) {
      testWidgets(
        reduced
            ? 'reduced motion: the rule steps once a second'
            : 'the rule drains linearly towards the next second',
        (tester) async {
          var now = DateTime(2026, 11, 25, 10);
          final endsAt = now.add(const Duration(seconds: 90));
          await pumpComponent(
            tester,
            RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
            disableAnimations: reduced,
          );
          // Reduced: exactly the remaining share; otherwise already aiming at
          // the next whole second.
          expect(filled(tester), closeTo(reduced ? 1.0 : 89 / 90, 0.001));

          now = now.add(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 500));
          if (reduced) {
            expect(filled(tester), closeTo(89 / 90, 0.001));
          } else {
            final value = filled(tester);
            expect(value, lessThan(89 / 90 - 0.001));
            expect(value, greaterThan(88 / 90 + 0.001));
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });

  testWidgets('RestTimerOverlay opens as a straight EXOM sheet and closes '
      'when the router location changes (CC 11)', (tester) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    RestTimerOverlay.show(context, restSeconds: 60),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          builder: (_, _) => const Scaffold(body: Text('other')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RestTimerOverlay), findsOneWidget);
    expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    router.go('/b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RestTimerOverlay), findsNothing);
    expect(find.text('other'), findsOneWidget);
  });
}
