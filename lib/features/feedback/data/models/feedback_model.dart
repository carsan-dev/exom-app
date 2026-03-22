import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';

class FeedbackModel extends FeedbackEntity {
  const FeedbackModel({
    required super.id,
    required super.mediaType,
    required super.mediaUrl,
    super.notes,
    super.adminResponse,
    required super.status,
    super.reviewedAt,
    required super.createdAt,
    super.exerciseName,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'] as Map<String, dynamic>?;
    return FeedbackModel(
      id: json['id'] as String,
      mediaType: json['media_type'] as String? ?? 'IMAGE',
      mediaUrl: json['media_url'] as String? ?? '',
      notes: json['notes'] as String?,
      adminResponse: json['admin_response'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      exerciseName: exercise?['name'] as String?,
    );
  }
}
