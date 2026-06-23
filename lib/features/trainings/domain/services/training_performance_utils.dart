import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

bool isTimeBasedPrescription(String value) {
  final normalized = value.toLowerCase().trim();
  return RegExp(
    r'(\bseg\b|segundos?|\bsec\b|seconds?|\bmin\b|minutos?|\bs\b|tiempo|time)',
  ).hasMatch(normalized);
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
