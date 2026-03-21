import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SocialLoginUseCase {
  final AuthRepository _repository;

  SocialLoginUseCase(this._repository);

  Future<UserEntity> call(String token, String provider) {
    return _repository.socialLogin(token, provider);
  }
}
