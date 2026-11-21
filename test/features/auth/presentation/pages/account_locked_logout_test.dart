// Regression of D2 (L5 emulator run): on «Cuenta bloqueada», «Volver al inicio
// de sesión» dispatched a voluntary logout but the app stayed on
// `/account-locked`, because that route is an access route for
// `resolveAppRouteRedirect` and nothing navigated on the unauthenticated
// state. The harness uses the real AuthBloc, AuthRepositoryImpl and app
// redirect; only the remote datasource, Firebase and storage are doubles.
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:exom_app/features/auth/data/models/auth_response_model.dart';
import 'package:exom_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/pages/account_locked_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _locked = ApiException(statusCode: 423, message: 'Account locked');

/// How the remote `POST /auth/logout` ends.
enum _LogoutOutcome {
  success(null),
  unauthorized(ApiException(statusCode: 401, message: 'Unauthorized')),
  locked(_locked),
  forbidden(ApiException(statusCode: 403, message: 'Forbidden')),
  network(ApiException(statusCode: 0, message: 'No connection')),
  serverError(ApiException(statusCode: 500, message: 'Server error'));

  const _LogoutOutcome(this.error);
  final ApiException? error;
}

class _FakeRemote extends Fake implements AuthRemoteDataSource {
  _FakeRemote(this.outcome);

  final _LogoutOutcome outcome;
  Completer<void>? gate;
  int logoutCalls = 0;

  @override
  Future<UserModel> getMe() => Future<UserModel>.error(_locked);

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      Future<AuthResponseModel>.error(_locked);

  @override
  Future<void> logout() async {
    logoutCalls++;
    await gate?.future;
    final error = outcome.error;
    if (error != null) throw error;
  }
}

/// Firebase double. Signing out a present user notifies [authChanges], like
/// the `authStateChanges` stream the real router refreshes on.
class _FakeFirebase extends FirebaseAuthService {
  _FakeFirebase({required this.signedIn});

  bool signedIn;
  int signOutCalls = 0;
  final ValueNotifier<int> authChanges = ValueNotifier<int>(0);

  @override
  LocalAuthSession? get currentSession => signedIn
      ? const LocalAuthSession(uid: 'locked-user', email: 'bea@exom.dev')
      : null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signedIn) {
      signedIn = false;
      authChanges.value++;
    }
  }
}

/// Only `clearSessionData` is expected; any other storage call (queues,
/// caches, drafts) fails the test through [Fake].
class _FakeStorage extends Fake implements LocalStorage {
  int clearSessionDataCalls = 0;

  @override
  Future<void> clearSessionData() async {
    clearSessionDataCalls++;
  }
}

class _Harness {
  _Harness({required _LogoutOutcome outcome, required bool firebaseSignedIn})
    : remote = _FakeRemote(outcome),
      firebase = _FakeFirebase(signedIn: firebaseSignedIn) {
    final repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      firebaseAuthService: firebase,
      localStorage: storage,
    );
    bloc = AuthBloc(
      loginUseCase: LoginUseCase(repository),
      socialLoginUseCase: SocialLoginUseCase(repository),
      logoutUseCase: LogoutUseCase(repository),
      getMeUseCase: GetMeUseCase(repository),
      deleteAccountUseCase: DeleteAccountUseCase(repository),
      firebaseAuthService: firebase,
    );
  }

  final _FakeRemote remote;
  final _FakeFirebase firebase;
  final _FakeStorage storage = _FakeStorage();
  late final AuthBloc bloc;
  late final GoRouter router;

  /// Same redirect inputs as `AppRouter.router`.
  GoRouter buildRouter() => router = GoRouter(
    initialLocation: AppRoutes.accountLocked,
    refreshListenable: firebase.authChanges,
    redirect: (context, state) => resolveAppRouteRedirect(
      location: state.matchedLocation,
      isAuthenticated: bloc.state is AuthAuthenticated,
      hasFirebaseUser: firebase.signedIn,
      isOnboardingComplete: true,
      isLocked: bloc.state is AuthAccountLocked,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.accountLocked,
        builder: (context, state) => const AccountLockedPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const Scaffold(body: Text('login-page')),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(body: Text('home-page')),
      ),
    ],
  );

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Reaches the locked state through the real bloc: `/auth/me` answering 423
/// with a Firebase session (app start), or `/auth/login` answering 423 before
/// any Firebase sign-in (login form).
Future<_Harness> _pumpLocked(
  WidgetTester tester, {
  required _LogoutOutcome outcome,
  bool viaLogin = false,
}) async {
  final harness = _Harness(outcome: outcome, firebaseSignedIn: !viaLogin);
  addTearDown(harness.bloc.close);
  harness.bloc.add(
    viaLogin
        ? const AuthLoginRequested(email: 'bea@exom.dev', password: 'secret')
        : const AuthCheckStatusRequested(),
  );
  await tester.pump();
  await tester.pump();
  expect(harness.bloc.state, isA<AuthAccountLocked>());

  final router = harness.buildRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: harness.bloc,
      child: MaterialApp.router(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(harness.location, AppRoutes.accountLocked);
  expect(find.byType(AccountLockedPage), findsOneWidget);
  return harness;
}

Future<void> _tapBackToLogin(WidgetTester tester) async {
  await tester.tap(find.byType(ExomSecondaryButton));
  await tester.pumpAndSettle();
}

void main() {
  for (final outcome in _LogoutOutcome.values) {
    testWidgets(
      'back to login from the locked account ends on /login with a local '
      'logout when the remote logout ends in ${outcome.name}',
      (tester) async {
        final harness = await _pumpLocked(tester, outcome: outcome);

        await _tapBackToLogin(tester);

        expect(harness.remote.logoutCalls, 1);
        expect(harness.bloc.state, isA<AuthUnauthenticated>());
        expect(harness.location, AppRoutes.login);
        expect(find.text('login-page'), findsOneWidget);
        expect(find.byType(AccountLockedPage), findsNothing);
        // Same local cleanup as a successful logout: Firebase signed out and
        // only the session record cleared; nothing else in storage touched.
        expect(harness.firebase.signOutCalls, 1);
        expect(harness.firebase.signedIn, isFalse);
        expect(harness.storage.clearSessionDataCalls, 1);
      },
    );
  }

  testWidgets(
    'locked at login (no Firebase session, no router refresh) still reaches '
    '/login after a 401 logout',
    (tester) async {
      final harness = await _pumpLocked(
        tester,
        outcome: _LogoutOutcome.unauthorized,
        viaLogin: true,
      );

      await _tapBackToLogin(tester);

      expect(harness.bloc.state, isA<AuthUnauthenticated>());
      expect(harness.location, AppRoutes.login);
      expect(harness.firebase.signOutCalls, 1);
      expect(harness.storage.clearSessionDataCalls, 1);
    },
  );

  testWidgets('stays on the locked page until the local logout completes', (
    tester,
  ) async {
    final harness = await _pumpLocked(
      tester,
      outcome: _LogoutOutcome.unauthorized,
    );
    final gate = Completer<void>();
    harness.remote.gate = gate;

    await tester.tap(find.byType(ExomSecondaryButton));
    await tester.pump();
    await tester.pump();

    expect(harness.bloc.state, isA<AuthLoading>());
    expect(harness.location, AppRoutes.accountLocked);
    expect(harness.firebase.signOutCalls, 0);
    expect(harness.storage.clearSessionDataCalls, 0);

    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.bloc.state, isA<AuthUnauthenticated>());
    expect(harness.location, AppRoutes.login);
  });
}
