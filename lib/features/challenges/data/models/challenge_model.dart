import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';

class ChallengeModel extends ChallengeEntity {
  const ChallengeModel({
    required super.id,
    required super.challengeId,
    required super.currentValue,
    required super.isCompleted,
    super.completedAt,
    required super.assignedAt,
    required super.title,
    required super.description,
    required super.type,
    required super.targetValue,
    required super.unit,
    required super.isManual,
    super.deadline,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    final challenge = json['challenge'] as Map<String, dynamic>? ?? {};
    return ChallengeModel(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      title: challenge['title'] as String? ?? '',
      description: challenge['description'] as String? ?? '',
      type: challenge['type'] as String? ?? 'WEEKLY',
      targetValue: (challenge['target_value'] as num?)?.toDouble() ?? 0,
      unit: challenge['unit'] as String? ?? '',
      isManual: challenge['is_manual'] as bool? ?? false,
      deadline: challenge['deadline'] != null
          ? DateTime.parse(challenge['deadline'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenge_id': challengeId,
      'current_value': currentValue,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'assigned_at': assignedAt.toIso8601String(),
      'challenge': {
        'id': challengeId,
        'title': title,
        'description': description,
        'type': type,
        'target_value': targetValue,
        'unit': unit,
        'is_manual': isManual,
        'deadline': deadline?.toIso8601String(),
      },
    };
  }
}
