import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects time based prescriptions', () {
    expect(isTimeBasedPrescription('40 seg'), isTrue);
    expect(isTimeBasedPrescription('1 min'), isTrue);
    expect(isTimeBasedPrescription('12 reps'), isFalse);
  });

  test('formats previous set performance with seconds and weight', () {
    expect(
      formatSetPerformance(
        const SetPerformance(setNumber: 1, seconds: 40, weightKg: 12.5),
      ),
      '40s · 12.5 kg',
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
