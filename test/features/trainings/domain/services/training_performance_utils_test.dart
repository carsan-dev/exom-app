import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('picks matching set or latest fallback', () {
    final performances = [
      const SetPerformance(setNumber: 1, reps: 12),
      const SetPerformance(setNumber: 2, reps: 10),
    ];

    expect(performanceForSet(performances, 1)?.reps, 12);
    expect(performanceForSet(performances, 3)?.reps, 10);
  });
}
