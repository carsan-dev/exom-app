import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository _repository;

  const GetProfileUseCase(this._repository);

  Future<ProfileEntity> call() => _repository.getProfile();
}
