import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';

abstract class NotificationsRepository {
  Future<NotificationsPageEntity> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  });
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Future<int> markAllAsRead();
  Future<int> deleteRead();
}
