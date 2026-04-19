import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';

class MarkNotificationAsReadUseCase {
  final NotificationsRepository _repository;

  const MarkNotificationAsReadUseCase(this._repository);

  Future<void> call(String id) => _repository.markAsRead(id);
}
