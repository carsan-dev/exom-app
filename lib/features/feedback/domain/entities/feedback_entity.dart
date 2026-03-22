class FeedbackEntity {
  final String id;
  final String mediaType; // IMAGE or VIDEO
  final String mediaUrl;
  final String? notes;
  final String? adminResponse;
  final String status; // PENDING or REVIEWED
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? exerciseName;

  const FeedbackEntity({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.notes,
    this.adminResponse,
    required this.status,
    this.reviewedAt,
    required this.createdAt,
    this.exerciseName,
  });

  bool get isPending => status == 'PENDING';
  bool get isReviewed => status == 'REVIEWED';
  bool get isVideo => mediaType == 'VIDEO';
}
