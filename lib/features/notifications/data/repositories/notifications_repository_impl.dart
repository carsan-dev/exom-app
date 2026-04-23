import 'package:exom_app/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;

  const NotificationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<NotificationsPageEntity> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) {
    return _remoteDataSource.getMyNotifications(
      page: page,
      limit: limit,
      unreadOnly: unreadOnly,
    );
  }

  @override
  Future<int> getUnreadCount() => _remoteDataSource.getUnreadCount();

  @override
  Future<void> markAsRead(String id) => _remoteDataSource.markAsRead(id);

  @override
  Future<int> markAllAsRead() => _remoteDataSource.markAllAsRead();

  @override
  Future<int> deleteRead() => _remoteDataSource.deleteRead();
}
