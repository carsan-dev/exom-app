import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class GetMeUseCase {
  final AuthRepository _repository;

  GetMeUseCase(this._repository);

  Future<UserEntity> call() {
    return _repository.getMe();
  }
}
