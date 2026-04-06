import 'package:exom_app/core/auth/firebase_auth_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FirebaseAuthService _firebaseAuthService;

  UserEntity? _currentUser;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required FirebaseAuthService firebaseAuthService,
  }) : _remoteDataSource = remoteDataSource,
       _firebaseAuthService = firebaseAuthService;

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
  Future<UserEntity> registerTrial({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _remoteDataSource.registerTrial(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    await _firebaseAuthService.signInWithCustomToken(response.accessToken);
    _currentUser = response.user.toEntity();
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Best effort — always sign out of Firebase
    }
    await _firebaseAuthService.signOut();
    _currentUser = null;
  }

  @override
  Future<UserEntity> getMe() async {
    final userModel = await _remoteDataSource.getMe();
    _currentUser = userModel.toEntity();
    return _currentUser!;
  }

  @override
  UserEntity? getCurrentUser() => _currentUser;
}
