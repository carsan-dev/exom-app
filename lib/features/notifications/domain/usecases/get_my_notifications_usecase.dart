import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';

class GetMyNotificationsUseCase {
  final NotificationsRepository _repository;

  const GetMyNotificationsUseCase(this._repository);

  Future<NotificationsPageEntity> call({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) =>
      _repository.getMyNotifications(
        page: page,
        limit: limit,
        unreadOnly: unreadOnly,
      );
}
