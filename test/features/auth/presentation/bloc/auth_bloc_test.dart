import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/api/api_client.dart';
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

void main() {
  test('late login result cannot authenticate after logout', () async {
    final repository = _DelayedLoginRepository();
    final firebase = _MutableFirebaseAuthService();
    final bloc = AuthBloc(
      loginUseCase: LoginUseCase(repository),
      socialLoginUseCase: SocialLoginUseCase(repository),
      logoutUseCase: LogoutUseCase(repository),
      getMeUseCase: GetMeUseCase(repository),
      deleteAccountUseCase: DeleteAccountUseCase(repository),
      firebaseAuthService: firebase,
    );
    bloc.add(
      const AuthLoginRequested(email: 'client@exom.dev', password: 'password'),
    );
    await repository.started.future;
    final loggedOut = bloc.stream.firstWhere(
      (state) => state is AuthUnauthenticated,
    );
    bloc.add(const AuthLogoutRequested());
    await loggedOut;
    repository.result.complete(
      const UserEntity(
        id: 'old-user',
        email: 'client@exom.dev',
        role: 'CLIENT',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<AuthUnauthenticated>());
    await bloc.close();
  });
  group('AuthCheckStatusRequested', () {
    test(
      'a network failure after backend 401 cannot restore offline authentication',
      () async {
        final fixture = _fixture(
          const ApiException(
            statusCode: 0,
            message: 'refresh offline after rejection',
            backendRejectedSession: true,
          ),
        );
        expect(await fixture.checkStatus(), isA<AuthError>());
        expect(fixture.firebase.signOutCalls, 0);
      },
    );
    test('401 does not authenticate and clears Firebase session', () async {
      final fixture = _fixture(
        const ApiException(statusCode: 401, message: 'unauthorized'),
      );

      final state = await fixture.checkStatus();

      expect(state, isA<AuthUnauthenticated>());
      expect(fixture.firebase.signOutCalls, 1);
    });

    test('403 does not authenticate and clears Firebase session', () async {
      final fixture = _fixture(
        const ApiException(statusCode: 403, message: 'forbidden'),
      );

      final state = await fixture.checkStatus();

      expect(state, isA<AuthUnauthenticated>());
      expect(fixture.firebase.signOutCalls, 1);
    });

    test('423 becomes account locked', () async {
      final fixture = _fixture(
        const ApiException(statusCode: 423, message: 'locked'),
      );

      final state = await fixture.checkStatus();

      expect(state, isA<AuthAccountLocked>());
      expect(fixture.firebase.signOutCalls, 0);
    });

    test(
      'real network error permits offline mode with local session',
      () async {
        final fixture = _fixture(
          const ApiException(statusCode: 0, message: 'offline'),
        );

        final state = await fixture.checkStatus();

        expect(
          state,
          isA<AuthAuthenticated>().having(
            (value) => value.user,
            'offline user',
            const UserEntity(
              id: 'firebase-user',
              email: 'client@exom.dev',
              role: 'CLIENT',
            ),
          ),
        );
        expect(fixture.firebase.signOutCalls, 0);
      },
    );

    test('5xx is temporary failure and does not authenticate', () async {
      final fixture = _fixture(
        const ApiException(statusCode: 503, message: 'temporary'),
      );

      final state = await fixture.checkStatus();

      expect(
        state,
        isA<AuthError>().having(
          (value) => value.message,
          'message',
          'temporary',
        ),
      );
      expect(fixture.firebase.signOutCalls, 0);
    });

    test('stale /me rejection cannot clear a replacement session', () async {
      final repository = _RacingAuthRepository();
      final firebase = _MutableFirebaseAuthService();
      final bloc = AuthBloc(
        loginUseCase: LoginUseCase(repository),
        socialLoginUseCase: SocialLoginUseCase(repository),
        logoutUseCase: LogoutUseCase(repository),
        getMeUseCase: GetMeUseCase(repository),
        deleteAccountUseCase: DeleteAccountUseCase(repository),
        firebaseAuthService: firebase,
      );

      bloc.add(const AuthCheckStatusRequested());
      await repository.getMeStarted.future;

      firebase.session = const LocalAuthSession(uid: 'replacement-user');
      final replacementAuthenticated = bloc.stream.firstWhere(
        (state) =>
            state is AuthAuthenticated && state.user.id == 'replacement-user',
      );
      bloc.add(
        const AuthLoginRequested(
          email: 'replacement@exom.dev',
          password: 'password-123',
        ),
      );
      await replacementAuthenticated;

      repository.getMeResult.completeError(
        const ApiException(statusCode: 401, message: 'old session rejected'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        bloc.state,
        isA<AuthAuthenticated>().having(
          (state) => state.user.id,
          'user id',
          'replacement-user',
        ),
      );
      expect(firebase.signOutCalls, 0);
      await bloc.close();
    });
  });
}

_AuthFixture _fixture(Object getMeError) {
  final repository = _FakeAuthRepository(getMeError);
  final firebase = _FakeFirebaseAuthService();
  final bloc = AuthBloc(
    loginUseCase: LoginUseCase(repository),
    socialLoginUseCase: SocialLoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getMeUseCase: GetMeUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    firebaseAuthService: firebase,
  );
  return _AuthFixture(bloc, firebase);
}

class _AuthFixture {
  _AuthFixture(this.bloc, this.firebase);

  final AuthBloc bloc;
  final _FakeFirebaseAuthService firebase;

  Future<AuthState> checkStatus() async {
    final nextState = bloc.stream.firstWhere((state) => state is! AuthLoading);
    bloc.add(const AuthCheckStatusRequested());
    final state = await nextState;
    await bloc.close();
    return state;
  }
}

class _FakeFirebaseAuthService extends FirebaseAuthService {
  int signOutCalls = 0;

  @override
  LocalAuthSession get currentSession =>
      const LocalAuthSession(uid: 'firebase-user', email: 'client@exom.dev');

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.getMeError);

  final Object getMeError;

  @override
  Future<UserEntity> getMe() => Future<UserEntity>.error(getMeError);

  @override
  Future<UserEntity> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserEntity> socialLogin(String token, String provider) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  UserEntity? getCurrentUser() => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> forgotPassword(String email) async {}
}

class _MutableFirebaseAuthService extends FirebaseAuthService {
  LocalAuthSession? session = const LocalAuthSession(uid: 'original-user');
  int signOutCalls = 0;

  @override
  LocalAuthSession? get currentSession => session;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    session = null;
  }
}

class _RacingAuthRepository implements AuthRepository {
  final Completer<void> getMeStarted = Completer<void>();
  final Completer<UserEntity> getMeResult = Completer<UserEntity>();

  @override
  Future<UserEntity> getMe() {
    getMeStarted.complete();
    return getMeResult.future;
  }

  @override
  Future<UserEntity> login(String email, String password) async {
    return const UserEntity(
      id: 'replacement-user',
      email: 'replacement@exom.dev',
      role: 'CLIENT',
    );
  }

  @override
  Future<UserEntity> socialLogin(String token, String provider) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  UserEntity? getCurrentUser() => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> forgotPassword(String email) async {}
}

class _DelayedLoginRepository extends _RacingAuthRepository {
  final started = Completer<void>();
  final result = Completer<UserEntity>();
  @override
  Future<UserEntity> login(String email, String password) {
    started.complete();
    return result.future;
  }
}
