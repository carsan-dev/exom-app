import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';

const _user = UserEntity(
  id: 'owner',
  email: 'synthetic@example.invalid',
  role: 'CLIENT',
);

class _Repository implements AuthRepository {
  int getMeCalls = 0;

  @override
  Future<UserEntity> getMe() async {
    getMeCalls++;
    return _user;
  }

  @override
  Future<UserEntity> login(String email, String password) async => _user;

  @override
  Future<UserEntity> socialLogin(String token, String provider) async => _user;

  @override
  Future<void> logout() async {}

  @override
  UserEntity? getCurrentUser() => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> forgotPassword(String email) async {}
}

class _Firebase extends FirebaseAuthService {
  @override
  LocalAuthSession? get currentSession =>
      const LocalAuthSession(uid: 'owner', generation: 1);

  @override
  Future<void> signOut() async {}
}

/// DESCANSO-AVISO r2: the rest timer guard cancels the native rest when an
/// active session goes through AuthLoading. That is only correct because, in
/// an active session, AuthLoading only comes from an explicit action (logout,
/// account deletion, a new login): AuthBloc does not revalidate on resume.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AuthBloc emits nothing when the app goes to background and back',
      () async {
    final repository = _Repository();
    final states = <AuthState>[];
    final bloc = AuthBloc(
      loginUseCase: LoginUseCase(repository),
      socialLoginUseCase: SocialLoginUseCase(repository),
      logoutUseCase: LogoutUseCase(repository),
      getMeUseCase: GetMeUseCase(repository),
      deleteAccountUseCase: DeleteAccountUseCase(repository),
      firebaseAuthService: _Firebase(),
    );
    addTearDown(bloc.close);
    final authenticated = bloc.stream.firstWhere(
      (state) => state is AuthAuthenticated,
    );
    bloc.add(const AuthCheckStatusRequested());
    await authenticated;
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);

    final binding = TestWidgetsFlutterBinding.instance;
    for (final lifecycle in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(lifecycle);
    }
    await pumpEventQueue();

    expect(states, isEmpty);
    expect(repository.getMeCalls, 1);
    expect(bloc.state, isA<AuthAuthenticated>());
  });

  test('in an active session AuthLoading only follows logout', () async {
    final repository = _Repository();
    final bloc = AuthBloc(
      loginUseCase: LoginUseCase(repository),
      socialLoginUseCase: SocialLoginUseCase(repository),
      logoutUseCase: LogoutUseCase(repository),
      getMeUseCase: GetMeUseCase(repository),
      deleteAccountUseCase: DeleteAccountUseCase(repository),
      firebaseAuthService: _Firebase(),
    );
    addTearDown(bloc.close);
    final authenticated = bloc.stream.firstWhere(
      (state) => state is AuthAuthenticated,
    );
    bloc.add(const AuthCheckStatusRequested());
    await authenticated;
    final states = <AuthState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);

    final loggedOut = bloc.stream.firstWhere(
      (state) => state is AuthUnauthenticated,
    );
    bloc.add(const AuthLogoutRequested());
    await loggedOut;
    expect(states.map((state) => state.runtimeType), [
      AuthLoading,
      AuthUnauthenticated,
    ]);
  });
}
