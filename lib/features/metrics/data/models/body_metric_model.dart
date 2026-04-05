class BodyMetricModel {
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

  const BodyMetricModel({
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

  factory BodyMetricModel.fromJson(Map<String, dynamic> json) {
    return BodyMetricModel(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.utc(1970),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      muscleMassKg: (json['muscle_mass_kg'] as num?)?.toDouble(),
      sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
      neckCm: (json['neck_cm'] as num?)?.toDouble(),
      shouldersCm: (json['shoulders_cm'] as num?)?.toDouble(),
      chestCm: (json['chest_cm'] as num?)?.toDouble(),
      armCm: (json['arm_cm'] as num?)?.toDouble(),
      forearmCm: (json['forearm_cm'] as num?)?.toDouble(),
      waistCm: (json['waist_cm'] as num?)?.toDouble(),
      hipsCm: (json['hips_cm'] as num?)?.toDouble(),
      thighCm: (json['thigh_cm'] as num?)?.toDouble(),
      calfCm: (json['calf_cm'] as num?)?.toDouble(),
    );
  }
}
