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
  int _operationGeneration = 0;

  void _checkOperation(int generation) {
    if (generation != _operationGeneration) {
      throw StateError('Authentication operation superseded');
    }
  }

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required FirebaseAuthService firebaseAuthService,
    required LocalStorage localStorage,
  }) : _remoteDataSource = remoteDataSource,
       _firebaseAuthService = firebaseAuthService,
       _localStorage = localStorage;

  @override
  Future<UserEntity> login(String email, String password) async {
    final generation = ++_operationGeneration;
    final response = await _remoteDataSource.login(email, password);
    _checkOperation(generation);
    await _firebaseAuthService.signInWithCustomToken(response.accessToken);
    _checkOperation(generation);
    _currentUser = response.user.toEntity();
    return _currentUser!;
  }

  @override
  Future<UserEntity> socialLogin(String token, String provider) async {
    final generation = ++_operationGeneration;
    try {
      final response = await _remoteDataSource.socialLogin(token, provider);
      _checkOperation(generation);
      await _firebaseAuthService.signInWithCustomToken(response.accessToken);
      _checkOperation(generation);
      _currentUser = response.user.toEntity();
      return _currentUser!;
    } catch (error) {
      if (generation == _operationGeneration) {
        await _firebaseAuthService.signOut();
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final generation = ++_operationGeneration;
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Best effort — always sign out of Firebase
    }
    if (generation != _operationGeneration) return;
    try {
      await _firebaseAuthService.signOut();
    } finally {
      if (generation == _operationGeneration) {
        await _localStorage.clearSessionData();
        _currentUser = null;
      }
    }
  }

  @override
  Future<UserEntity> getMe() async {
    final generation = _operationGeneration;
    final userModel = await _remoteDataSource.getMe();
    _checkOperation(generation);
    _currentUser = userModel.toEntity();
    return _currentUser!;
  }

  @override
  UserEntity? getCurrentUser() => _currentUser;

  @override
  Future<void> forgotPassword(String email) async {
    await _remoteDataSource.forgotPassword(email);
  }

  @override
  Future<void> deleteAccount() async {
    final generation = ++_operationGeneration;
    try {
      await _remoteDataSource.deleteAccount();
    } finally {
      if (generation == _operationGeneration) {
        try {
          await _firebaseAuthService.signOut();
        } catch (_) {
          // Firebase user may already be gone after backend delete.
        }
        if (generation == _operationGeneration) {
          await _localStorage.clearSessionData();
          _currentUser = null;
        }
      }
    }
  }
}
