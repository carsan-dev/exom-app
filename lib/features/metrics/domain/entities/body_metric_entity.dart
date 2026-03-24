class BodyMetricEntity {
  final String id;
  final DateTime date;
  final double? weightKg;
  final double? heightCm;
  final double? muscleMassKg;
  final double? sleepHours;
  final double? neckCm;
  final double? shouldersCm;
  final double? chestCm;
  final double? armCm;
  final double? forearmCm;
  final double? waistCm;
  final double? hipsCm;
  final double? thighCm;
  final double? calfCm;

  const BodyMetricEntity({
    required this.id,
    required this.date,
    this.weightKg,
    this.heightCm,
    this.muscleMassKg,
    this.sleepHours,
    this.neckCm,
    this.shouldersCm,
    this.chestCm,
    this.armCm,
    this.forearmCm,
    this.waistCm,
    this.hipsCm,
    this.thighCm,
    this.calfCm,
  });
}
