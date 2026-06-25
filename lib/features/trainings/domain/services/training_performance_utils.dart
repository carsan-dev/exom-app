import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

enum TimePerformanceUnit { seconds, minutes }

bool isTimeBasedPrescription(String value) {
  return timePerformanceUnit(value) != null;
}

TimePerformanceUnit? timePerformanceUnit(String value) {
  final normalized = value.toLowerCase().trim();
  if (RegExp(r'(\bmin\b|minutos?)').hasMatch(normalized)) {
    return TimePerformanceUnit.minutes;
  }
  if (RegExp(
    r'(\bseg\b|segundos?|\bsec\b|seconds?|\bs\b|tiempo|time)',
  ).hasMatch(normalized)) {
    return TimePerformanceUnit.seconds;
  }
  return null;
}

int? secondsFromTimeInput(int? value, TimePerformanceUnit? unit) {
  if (value == null) return null;
  return unit == TimePerformanceUnit.minutes ? value * 60 : value;
}

int? timeInputFromSeconds(int? seconds, TimePerformanceUnit? unit) {
  if (seconds == null) return null;
  return unit == TimePerformanceUnit.minutes && seconds % 60 == 0
      ? seconds ~/ 60
      : seconds;
}

SetPerformance? performanceForSet(
  List<SetPerformance>? performances,
  int setNumber,
) {
  if (performances == null || performances.isEmpty) return null;

  for (final performance in performances.reversed) {
    if (performance.setNumber == setNumber) return performance;
  }
  return performances.last;
}

String formatSetPerformance(SetPerformance performance) {
  final parts = <String>[];
  if (performance.reps != null) {
    parts.add('${performance.reps} reps');
  }
  if (performance.seconds != null) {
    parts.add('${performance.seconds}s');
  }
  if (performance.weightKg != null) {
    final weight = performance.weightKg!;
    parts.add('${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg');
  }
  return parts.join(' · ');
}
