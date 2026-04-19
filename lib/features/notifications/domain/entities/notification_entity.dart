import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.data,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  String? get route {
    final value = data?['route'];
    if (value is String && value.startsWith('/')) return value;
    return null;
  }

  NotificationEntity copyWith({DateTime? readAt}) {
    return NotificationEntity(
      id: id,
      title: title,
      body: body,
      status: status,
      createdAt: createdAt,
      data: data,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  List<Object?> get props => [id, title, body, data, status, createdAt, readAt];
}

class NotificationsPageEntity extends Equatable {
  final List<NotificationEntity> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const NotificationsPageEntity({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [items, total, page, limit, totalPages];
}
