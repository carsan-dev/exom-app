import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterTrialUseCase {
  final AuthRepository _repository;

  RegisterTrialUseCase(this._repository);

  Future<UserEntity> call({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) {
    return _repository.registerTrial(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
