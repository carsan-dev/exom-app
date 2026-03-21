class ChallengeEntity {
  final String id;
  final String challengeId;
  final double currentValue;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime assignedAt;
  final String title;
  final String description;
  final String type; // WEEKLY or MAIN_GOAL
  final double targetValue;
  final String unit;
  final bool isManual;
  final DateTime? deadline;

  const ChallengeEntity({
    required this.id,
    required this.challengeId,
    required this.currentValue,
    required this.isCompleted,
    this.completedAt,
    required this.assignedAt,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.unit,
    required this.isManual,
    this.deadline,
  });

  double get progress => targetValue > 0 ? (currentValue / targetValue).clamp(0, 1) : 0;
  bool get isMainGoal => type == 'MAIN_GOAL';
}
