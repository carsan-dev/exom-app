class ProfileEntity {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? level;
  final String? goal;
  final double? heightCm;
  final String? sex;
  final DateTime? birthDate;
  final int totalTrainings;
  final int streakDays;
  final double? currentWeightKg;
  final double? muscleMassGoalKg;
  final double? currentBmi;

  const ProfileEntity({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.level,
    this.goal,
    this.heightCm,
    this.sex,
    this.birthDate,
    this.totalTrainings = 0,
    this.streakDays = 0,
    this.currentWeightKg,
    this.muscleMassGoalKg,
    this.currentBmi,
  });

  String get fullName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
}
