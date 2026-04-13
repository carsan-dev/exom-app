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
  final double? armLeftCm;
  final double? armRightCm;
  final double? forearmLeftCm;
  final double? forearmRightCm;
  final double? waistCm;
  final double? hipsCm;
  final double? thighLeftCm;
  final double? thighRightCm;
  final double? calfLeftCm;
  final double? calfRightCm;

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
    this.armLeftCm,
    this.armRightCm,
    this.forearmLeftCm,
    this.forearmRightCm,
    this.waistCm,
    this.hipsCm,
    this.thighLeftCm,
    this.thighRightCm,
    this.calfLeftCm,
    this.calfRightCm,
  });
}
