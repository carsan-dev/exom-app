import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/metrics/domain/utils/seen_muscle_mass_estimator.dart';

void main() {
  test('SEEN estimator returns ASM and ASMI for male input', () {
    final estimate = estimateSeenMuscleMass(
      calfCm: 36,
      ageYears: 35,
      heightMeters: 1.78,
      sex: SeenBiologicalSex.male,
    );

    expect(estimate, isNotNull);
    expect(estimate!.estimatedAsmKg, closeTo(23.729, 0.001));
    expect(estimate.estimatedAsmiKgPerM2, closeTo(7.489, 0.001));
  });

  test('SEEN sex parser supports common Spanish labels', () {
    expect(parseSeenBiologicalSex('Hombre'), SeenBiologicalSex.male);
    expect(parseSeenBiologicalSex('mujer'), SeenBiologicalSex.female);
    expect(parseSeenBiologicalSex(''), isNull);
  });

  test('age calculation subtracts pending birthdays', () {
    final age = calculateAgeYears(
      DateTime(1990, 12, 10),
      now: DateTime(2026, 3, 23),
    );

    expect(age, 35);
  });
}
