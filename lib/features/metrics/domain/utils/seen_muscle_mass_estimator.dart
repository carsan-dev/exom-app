enum SeenBiologicalSex { male, female }

class SeenMuscleMassEstimate {
  final double estimatedAsmKg;
  final double estimatedAsmiKgPerM2;

  const SeenMuscleMassEstimate({
    required this.estimatedAsmKg,
    required this.estimatedAsmiKgPerM2,
  });
}

SeenBiologicalSex? parseSeenBiologicalSex(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  switch (normalized) {
    case 'male':
    case 'masculino':
    case 'hombre':
    case 'man':
    case 'm':
      return SeenBiologicalSex.male;
    case 'female':
    case 'femenino':
    case 'mujer':
    case 'woman':
    case 'f':
      return SeenBiologicalSex.female;
    default:
      return null;
  }
}

int calculateAgeYears(DateTime birthDate, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - birthDate.year;
  final hasHadBirthday =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!hasHadBirthday) {
    age -= 1;
  }
  return age;
}

SeenMuscleMassEstimate? estimateSeenMuscleMass({
  required double calfCm,
  required int ageYears,
  required double heightMeters,
  required SeenBiologicalSex sex,
}) {
  if (calfCm <= 0 || ageYears <= 0 || heightMeters <= 0) {
    return null;
  }

  final sexFactor = sex == SeenBiologicalSex.male ? 1.0 : 0.0;
  final estimatedAsmKg =
      (calfCm * 0.768) - (ageYears * 0.029) + (sexFactor * 7.523) - 10.427;

  if (estimatedAsmKg <= 0) {
    return null;
  }

  final estimatedAsmiKgPerM2 = estimatedAsmKg / (heightMeters * heightMeters);

  return SeenMuscleMassEstimate(
    estimatedAsmKg: estimatedAsmKg,
    estimatedAsmiKgPerM2: estimatedAsmiKgPerM2,
  );
}
