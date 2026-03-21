class AchievementEntity {
  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final DateTime unlockedAt;

  const AchievementEntity({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.unlockedAt,
  });
}
