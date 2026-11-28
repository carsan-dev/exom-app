// L6 S11-01a: five screens (Inicio, detalle de entrenamiento, ejercicio
// activo, hoja de serie y descanso) at 390 x 844 dp with realistic data, in
// both themes, at 1.0, 1.3, 1.6 and 2.0 text scale (Android non-linear
// scaler): no overflow exception and, at 2.0, the last actionable element of
// each screen is reachable by scrolling (or already visible) and hit-testable.
//
// Reuses the harnesses of the redesign tests (see long_string_overflow_test).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/android_nonlinear_text_scaler.dart';
import '../features/home/presentation/pages/home_e1_harness.dart';
import '../features/trainings/presentation/pages/active_exercise_redesign_test.dart'
    show activeExerciseDraftKey, activeExerciseTrainingId, pumpActiveExercise;
import '../features/trainings/presentation/pages/training_detail_redesign_test.dart'
    show pumpTrainingDetail;
import '../golden/redesign_scenes.dart' show loadRedesignFonts;

const _scales = [1.0, 1.3, 1.6, 2.0];
const _width = 390.0;
const _height = 844.0;

const _previous = [
  SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
  SetPerformance(setNumber: 2, reps: 8, weightKg: 60, rir: 2),
];

ActiveWorkoutHiveModel _seed({required bool resting}) => ActiveWorkoutHiveModel(
  trainingId: activeExerciseTrainingId,
  exerciseId: activeExerciseDraftKey,
  currentSet: 2,
  completedSets: 1,
  restEndsAt: resting ? DateTime.now().add(const Duration(seconds: 90)) : null,
  lastWeightKg: 62.5,
  completedSetData: const [
    {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
  ],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Scrolls until [target] is visible (if it is not already) and expects it to
/// be hit-testable; no overflow may be reported on the way.
Future<void> _expectReachable(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  expect(tester.takeException(), isNull);
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scrollable ?? find.byType(Scrollable).first,
    );
    // The lazy list builds the row before it is fully on screen.
    await tester.ensureVisible(target);
    await tester.pump();
  }
  expect(tester.takeException(), isNull);
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _openSheet(
  WidgetTester tester, {
  required TextScaler textScaler,
  required Brightness brightness,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: app!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showSetPerformanceSheet(
                context,
                AppLocalizations.of(context),
                setNumber: 2,
                prescribedReps: '8 reps · RIR 2',
                repsRequired: false,
                timeUnit: null,
                previousWeight: 62.5,
                previousPerformance: const SetPerformance(
                  setNumber: 2,
                  reps: 8,
                  weightKg: 60,
                  rir: 2,
                ),
                targetCount: 8,
                targetRir: 2,
                exerciseName: 'Sentadilla búlgara',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in _scales) {
      final scaler = AndroidNonlinearTextScaler(scale);
      final label = '${brightness.name} ${scale}x';

      testWidgets('Inicio, $label', (tester) async {
        await pumpInicioE1(
          tester,
          repository: InicioE1Repository((_) => inicioE1Training),
          calendar: InicioE1Calendar(InicioE1Calendar.week({})),
          width: _width,
          height: _height,
          textScaler: scaler,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 12; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        if (scale == 2.0) {
          expect(find.textContaining('Sueño').hitTestable(), findsOneWidget);
        }
      });

      testWidgets('Detalle de entrenamiento, $label', (tester) async {
        await pumpTrainingDetail(
          tester,
          width: _width,
          locale: const Locale('es'),
          textScaler: scaler,
          brightness: brightness,
        );
        tester.view.physicalSize = const Size(_width, _height);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 2.0) {
          // The pinned CTA and the last exercise row of the list.
          await _expectReachable(
            tester,
            find.byKey(const Key('training-next-button')),
          );
          await _expectReachable(tester, find.text('Hip thrust'));
        }
      });

      testWidgets('Ejercicio activo, $label', (tester) async {
        await pumpActiveExercise(
          tester,
          initialWeightKg: 62.5,
          previous: _previous,
          seed: _seed(resting: false),
          width: _width,
          height: _height,
          textScaler: scaler,
          brightness: brightness,
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        if (scale == 2.0) {
          await _expectReachable(
            tester,
            find.byKey(const ValueKey('footer-executing')),
          );
          await _expectReachable(
            tester,
            find.byKey(const Key('active-exercise-technique')),
          );
        }
      });

      testWidgets('Hoja de serie, $label', (tester) async {
        await _openSheet(tester, textScaler: scaler, brightness: brightness);
        expect(tester.takeException(), isNull);
        if (scale == 2.0) {
          await _expectReachable(
            tester,
            find.byKey(const Key('set-sheet-save')),
            scrollable: find.byKey(const Key('set-sheet-fields-scroll')),
          );
        }
      });

      testWidgets('Descanso, $label', (tester) async {
        await pumpActiveExercise(
          tester,
          initialWeightKg: 62.5,
          previous: _previous,
          seed: _seed(resting: true),
          width: _width,
          height: _height,
          textScaler: scaler,
          brightness: brightness,
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        if (scale == 2.0) {
          await _expectReachable(
            tester,
            find.byKey(const Key('active-exercise-rest-skip')),
          );
          await _expectReachable(
            tester,
            find.byKey(const Key('active-exercise-rest-extend')),
          );
        }
      });
    }
  }
}
