class ProfileModel {
  static const beginnerLevel = 'PRINCIPIANTE';
  static const intermediateLevel = 'INTERMEDIO';
  static const advancedLevel = 'AVANZADO';

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
  final int? targetCalories;

  const ProfileModel({
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
    this.targetCalories,
  });

  static String? normalizeLevelValue(String? value) {
    final normalized = value?.trim().toUpperCase();
    switch (normalized) {
      case 'BEGINNER':
      case beginnerLevel:
        return beginnerLevel;
      case 'INTERMEDIATE':
      case intermediateLevel:
        return intermediateLevel;
      case 'ADVANCED':
      case advancedLevel:
        return advancedLevel;
      default:
        return value?.trim();
    }
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;
    return ProfileModel(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: userMap?['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      level: normalizeLevelValue(json['level'] as String?),
      goal: json['main_goal'] as String?,
      heightCm: (json['height'] as num?)?.toDouble(),
      sex: json['sex'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      totalTrainings: json['totalTrainings'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
      currentWeightKg: (json['current_weight'] as num?)?.toDouble(),
      muscleMassGoalKg: (json['muscle_mass_goal'] as num?)?.toDouble(),
      currentBmi: (json['currentBmi'] as num?)?.toDouble(),
      targetCalories: (json['target_calories'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      if (email != null) 'user': {'email': email},
      'phone': phone,
      'avatar_url': avatarUrl,
      'level': normalizeLevelValue(level),
      'main_goal': goal,
      'height': heightCm,
      'sex': sex,
      'birth_date': birthDate?.toIso8601String(),
      'totalTrainings': totalTrainings,
      'streakDays': streakDays,
      'current_weight': currentWeightKg,
      'muscle_mass_goal': muscleMassGoalKg,
      'currentBmi': currentBmi,
      'target_calories': targetCalories,
    };
  }

  String get fullName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
}
