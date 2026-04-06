import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  Future<UserEntity> socialLogin(String token, String provider);
  Future<UserEntity> registerTrial({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });
  Future<void> logout();
  Future<UserEntity> getMe();
  UserEntity? getCurrentUser();
}
