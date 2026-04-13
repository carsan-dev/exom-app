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

  factory BodyMetricModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(String key) => (json[key] as num?)?.toDouble();
    final legacyArm = parseDouble('arm_cm');
    final legacyForearm = parseDouble('forearm_cm');
    final legacyThigh = parseDouble('thigh_cm');
    final legacyCalf = parseDouble('calf_cm');

    return BodyMetricModel(
      id: json['id'] as String? ?? '',
      date:
          DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.utc(1970),
      weightKg: parseDouble('weight_kg'),
      heightCm: parseDouble('height_cm'),
      muscleMassKg: parseDouble('muscle_mass_kg'),
      sleepHours: parseDouble('sleep_hours'),
      neckCm: parseDouble('neck_cm'),
      shouldersCm: parseDouble('shoulders_cm'),
      chestCm: parseDouble('chest_cm'),
      armLeftCm: parseDouble('arm_left_cm') ?? legacyArm,
      armRightCm: parseDouble('arm_right_cm') ?? legacyArm,
      forearmLeftCm: parseDouble('forearm_left_cm') ?? legacyForearm,
      forearmRightCm: parseDouble('forearm_right_cm') ?? legacyForearm,
      waistCm: parseDouble('waist_cm'),
      hipsCm: parseDouble('hips_cm'),
      thighLeftCm: parseDouble('thigh_left_cm') ?? legacyThigh,
      thighRightCm: parseDouble('thigh_right_cm') ?? legacyThigh,
      calfLeftCm: parseDouble('calf_left_cm') ?? legacyCalf,
      calfRightCm: parseDouble('calf_right_cm') ?? legacyCalf,
    );
  }
}
