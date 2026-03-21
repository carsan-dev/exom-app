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
  })  : _remoteDataSource = remoteDataSource,
        _firebaseAuthService = firebaseAuthService;

  @override
  Future<UserEntity> login(String email, String password) async {
    // Sign into Firebase first — the _AuthInterceptor will attach the
    // Firebase ID token to the subsequent backend request automatically.
    await _firebaseAuthService.signInWithEmail(email, password);
    final response = await _remoteDataSource.login(email, password);
    _currentUser = response.user.toEntity();
    return _currentUser!;
  }

  @override
  Future<UserEntity> socialLogin(String token, String provider) async {
    final response = await _remoteDataSource.socialLogin(token, provider);
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
  UserEntity? getCurrentUser() => _currentUser;
}
