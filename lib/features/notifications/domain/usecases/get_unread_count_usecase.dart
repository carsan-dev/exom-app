import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';

class GetUnreadCountUseCase {
  final NotificationsRepository _repository;

  const GetUnreadCountUseCase(this._repository);

  Future<int> call() => _repository.getUnreadCount();
}
