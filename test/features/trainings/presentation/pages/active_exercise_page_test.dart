import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';

void main() {
  for (final scenario in [
    'new minutes',
    'saved minutes',
    'unaligned minutes',
    'seconds',
    'repetitions',
    'legacy minutes',
  ]) {
    testWidgets('individual set form preserves $scenario units', (
      tester,
    ) async {
      final timed = scenario.contains('minutes');
      final savedSeconds = scenario == 'saved minutes'
          ? 600
          : scenario == 'unaligned minutes'
          ? 90
          : null;
      final exercise = TrainingExerciseEntity(
        id: 'timed',
        order: 0,
        sets: 1,
        repsOrDuration: scenario == 'legacy minutes' ? '10 min' : '600s',
        measureType: scenario == 'legacy minutes'
            ? null
            : scenario == 'repetitions'
            ? ExerciseMeasureType.reps
            : ExerciseMeasureType.seconds,
        timedPrescription: timed
            ? const TimedPrescription(unit: TimeDisplayUnit.minutes)
            : null,
        restSeconds: 0,
        exercise: const ExerciseEntity(
          id: 'exercise',
          name: 'Walk',
          muscleGroups: [],
        ),
      );
      final results =
          <
            ({int? reps, int? seconds, double? weight, int? rir, bool skipped})
          >[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showSetPerformanceSheet(
                    context,
                    AppLocalizations.of(context),
                    setNumber: 1,
                    prescribedReps: formatExercisePrescription(exercise),
                    repsRequired: true,
                    timeUnit: timePerformanceUnitForExercise(exercise),
                    currentPerformance: savedSeconds == null
                        ? null
                        : SetPerformance(setNumber: 1, seconds: savedSeconds),
                  );
                  if (result != null) results.add(result);
                },
                child: const Text('Open set form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open set form'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      final field = tester.widget<TextField>(fields.first);
      final l10n = AppLocalizations.of(tester.element(fields.first));
      expect(
        field.decoration?.labelText,
        scenario == 'repetitions'
            ? l10n.setPerformanceReps
            : timed && savedSeconds != 90
            ? l10n.setPerformanceMinutes
            : l10n.setPerformanceSeconds,
      );
      if (savedSeconds != null) {
        expect(field.controller?.text, savedSeconds == 600 ? '10' : '90');
      } else {
        await tester.enterText(
          fields.first,
          timed
              ? '10'
              : scenario == 'seconds'
              ? '45'
              : '12',
        );
      }
      await tester.tap(find.text(l10n.weightInputSave));
      await tester.pumpAndSettle();
      expect(results, hasLength(1));
      expect(
        results.single.seconds,
        scenario == 'repetitions' ? null : savedSeconds ?? (timed ? 600 : 45),
      );
      expect(results.single.reps, scenario == 'repetitions' ? 12 : null);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  group('shouldPrepareLastSetVideo', () {
    test('waits until final set is executing', () {
      expect(
        shouldPrepareLastSetVideo(
          requiresLastSetVideo: true,
          isExecuting: false,
          currentSet: 3,
          totalSets: 3,
          completedSets: 2,
          feedbackId: null,
        ),
        isFalse,
      );
      expect(
        shouldPrepareLastSetVideo(
          requiresLastSetVideo: true,
          isExecuting: true,
          currentSet: 3,
          totalSets: 3,
          completedSets: 2,
          feedbackId: null,
        ),
        isTrue,
      );
    });

    test('does not reopen after evidence is attached', () {
      expect(
        shouldPrepareLastSetVideo(
          requiresLastSetVideo: true,
          isExecuting: true,
          currentSet: 3,
          totalSets: 3,
          completedSets: 2,
          feedbackId: 'feedback-1',
        ),
        isFalse,
      );
    });
  });

  group('trainingFooterBottomPadding', () {
    test('adds navigation bar inset on Android button navigation', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.android,
          navigationInset: 48,
          systemGestureInset: 24,
        ),
        64,
      );
    });

    test('keeps current inset on Android gesture navigation', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.android,
          navigationInset: 24,
          systemGestureInset: 24,
        ),
        24,
      );
    });

    test('keeps base margin on Android without bottom insets', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.android,
          navigationInset: 0,
          systemGestureInset: 0,
        ),
        16,
      );
    });

    test('ignores navigation insets on iOS', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.iOS,
          navigationInset: 34,
          systemGestureInset: 34,
        ),
        16,
      );
    });
  });
}
