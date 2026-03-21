import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';

class AchievementModel extends AchievementEntity {
  const AchievementModel({
    required super.id,
    required super.name,
    required super.description,
    super.iconUrl,
    required super.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    final achievement = json['achievement'] as Map<String, dynamic>? ?? {};
    return AchievementModel(
      id: json['id'] as String,
      name: achievement['name'] as String? ?? '',
      description: achievement['description'] as String? ?? '',
      iconUrl: achievement['icon_url'] as String?,
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
    );
  }
}
