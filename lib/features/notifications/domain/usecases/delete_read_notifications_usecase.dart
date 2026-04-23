import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';

class DeleteReadNotificationsUseCase {
  final NotificationsRepository _repository;

  const DeleteReadNotificationsUseCase(this._repository);

  Future<int> call() => _repository.deleteRead();
}
