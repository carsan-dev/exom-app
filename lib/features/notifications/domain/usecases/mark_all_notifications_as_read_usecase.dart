import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';

class MarkAllNotificationsAsReadUseCase {
  final NotificationsRepository _repository;

  const MarkAllNotificationsAsReadUseCase(this._repository);

  Future<int> call() => _repository.markAllAsRead();
}
