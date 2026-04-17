import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FirebaseAuthService _firebaseAuthService;
  final LocalStorage _localStorage;

  UserEntity? _currentUser;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required FirebaseAuthService firebaseAuthService,
    required LocalStorage localStorage,
  }) : _remoteDataSource = remoteDataSource,
       _firebaseAuthService = firebaseAuthService,
       _localStorage = localStorage;

  @override
  Future<UserEntity> login(String email, String password) async {
    final response = await _remoteDataSource.login(email, password);
    await _firebaseAuthService.signInWithCustomToken(response.accessToken);
    _currentUser = response.user.toEntity();
    return _currentUser!;
  }

  @override
  Future<UserEntity> socialLogin(String token, String provider) async {
    try {
      final response = await _remoteDataSource.socialLogin(token, provider);
      _currentUser = response.user.toEntity();
      return _currentUser!;
    } catch (error) {
      await _firebaseAuthService.signOut();
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Best effort — always sign out of Firebase
    }
    try {
      await _firebaseAuthService.signOut();
    } finally {
      await _localStorage.clearSessionData();
      _currentUser = null;
    }
  }

  @override
  Future<UserEntity> getMe() async {
    final userModel = await _remoteDataSource.getMe();
    _currentUser = userModel.toEntity();
    return _currentUser!;
  }

  @override
  UserEntity? getCurrentUser() => _currentUser;

  @override
  Future<void> deleteAccount() async {
    try {
      await _remoteDataSource.deleteAccount();
    } finally {
      try {
        await _firebaseAuthService.signOut();
      } catch (_) {
        // Firebase user may already be gone after backend delete
      }
      await _localStorage.clearSessionData();
      _currentUser = null;
    }
  }
}
