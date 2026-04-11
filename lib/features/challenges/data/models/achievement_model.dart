import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';

class AchievementModel extends AchievementEntity {
  const AchievementModel({
    required super.id,
    required super.name,
    required super.description,
    super.iconUrl,
    super.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    final achievement = json['achievement'] as Map<String, dynamic>? ?? {};
    return AchievementModel(
      id: achievement['id'] as String? ?? '',
      name: achievement['name'] as String? ?? '',
      description: achievement['description'] as String? ?? '',
      iconUrl: achievement['icon_url'] as String?,
      unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? ''),
    );
  }

  factory AchievementModel.fromCatalogJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
    );
  }
}
