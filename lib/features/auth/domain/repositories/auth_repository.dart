import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  Future<UserEntity> socialLogin(String token, String provider);
  Future<void> logout();
  Future<UserEntity> getMe();
  UserEntity? getCurrentUser();
  Future<void> deleteAccount();
  Future<void> forgotPassword(String email);
}
