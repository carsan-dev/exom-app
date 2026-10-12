import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unaligned saved minutes use seconds for a lossless edit', () {
    final unit = timePerformanceUnitForInput(TimePerformanceUnit.minutes, 90);
    expect(unit, TimePerformanceUnit.seconds);
    final value = timeInputFromSeconds(90, unit);
    expect(value, 90);
    expect(secondsFromTimeInput(value, unit), 90);
    expect(
      timePerformanceUnitForInput(TimePerformanceUnit.minutes, 600),
      TimePerformanceUnit.minutes,
    );
    expect(
      timePerformanceUnitForInput(TimePerformanceUnit.minutes, null),
      TimePerformanceUnit.minutes,
    );
    expect(timePerformanceUnitForInput(null, null), isNull);
  });
  test('structured minutes use minute input while storage remains seconds', () {
    const exercise = TrainingExerciseEntity(
      id: 'timed',
      order: 0,
      sets: 1,
      repsOrDuration: '600s',
      measureType: ExerciseMeasureType.seconds,
      targetValue: 600,
      timedPrescription: TimedPrescription(unit: TimeDisplayUnit.minutes),
      restSeconds: 0,
      exercise: ExerciseEntity(id: 'exercise', name: 'Walk', muscleGroups: []),
    );
    final unit = timePerformanceUnitForExercise(exercise);
    expect(unit, TimePerformanceUnit.minutes);
    expect(secondsFromTimeInput(10, unit), 600);
    expect(timeInputFromSeconds(600, unit), 10);
  });
  test('detects time based prescriptions', () {
    expect(isTimeBasedPrescription('40 seg'), isTrue);
    expect(isTimeBasedPrescription('1 min'), isTrue);
    expect(isTimeBasedPrescription('12 reps'), isFalse);
  });

  test('converts minute prescriptions to stored seconds', () {
    expect(timePerformanceUnit('10 min'), TimePerformanceUnit.minutes);
    expect(secondsFromTimeInput(10, TimePerformanceUnit.minutes), 600);
    expect(secondsFromTimeInput(45, TimePerformanceUnit.seconds), 45);
    expect(timeInputFromSeconds(600, TimePerformanceUnit.minutes), 10);
  });

  test(
    'structured measure wins and legacy prescription remains compatible',
    () {
      TrainingExerciseEntity exercise({ExerciseMeasureType? measureType}) =>
          TrainingExerciseEntity(
            id: 'te-1',
            order: 0,
            sets: 1,
            repsOrDuration: '45s',
            measureType: measureType,
            targetValue: measureType == null ? null : 45,
            targetRir: 2,
            restSeconds: 30,
            exercise: const ExerciseEntity(
              id: 'ex-1',
              name: 'Plancha',
              muscleGroups: ['core'],
            ),
          );

      expect(
        timePerformanceUnitForExercise(
          exercise(measureType: ExerciseMeasureType.reps),
        ),
        isNull,
      );
      expect(
        timePerformanceUnitForExercise(exercise()),
        TimePerformanceUnit.seconds,
      );
      expect(
        formatExercisePrescription(
          exercise(measureType: ExerciseMeasureType.seconds),
        ),
        '45s · RIR 2',
      );
    },
  );

  test('formats previous set performance with seconds and weight', () {
    expect(
      formatSetPerformance(
        const SetPerformance(setNumber: 1, seconds: 40, weightKg: 12.5, rir: 2),
      ),
      '40s · 12.5 kg · RIR 2',
    );
  });

  test('formats structured repetition and second ranges', () {
    TrainingExerciseEntity exercise({
      required ExerciseMeasureType measureType,
      required int min,
      required int max,
    }) => TrainingExerciseEntity(
      id: 'te-range',
      order: 0,
      sets: 1,
      repsOrDuration: 'legacy',
      measureType: measureType,
      targetValueMin: min,
      targetValueMax: max,
      restSeconds: 30,
      exercise: const ExerciseEntity(
        id: 'ex-1',
        name: 'Sentadilla',
        muscleGroups: ['pierna'],
      ),
    );

    expect(
      formatExercisePrescription(
        exercise(measureType: ExerciseMeasureType.reps, min: 8, max: 10),
      ),
      '8-10 reps',
    );
    expect(
      formatExercisePrescription(
        exercise(measureType: ExerciseMeasureType.seconds, min: 30, max: 45),
      ),
      '30-45s',
    );
  });

  test('picks matching set or latest fallback', () {
    final performances = [
      const SetPerformance(setNumber: 1, reps: 12),
      const SetPerformance(setNumber: 2, reps: 10),
    ];

    expect(performanceForSet(performances, 1)?.reps, 12);
    expect(performanceForSet(performances, 3)?.reps, 10);
  });
}
