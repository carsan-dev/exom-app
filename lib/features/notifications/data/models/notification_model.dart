import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.title,
    required super.body,
    required super.status,
    required super.createdAt,
    super.data,
    super.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    Map<String, dynamic>? data;
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    }

    return NotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'SENT',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      data: data,
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
    );
  }
}
