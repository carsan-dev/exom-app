import 'dart:async';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/features/splash/presentation/pages/splash_page.dart';

class _UpdateService extends Fake implements AppUpdateService {
  _UpdateService(this.decision);

  final Future<AppUpdateDecision> decision;
  int checks = 0;

  @override
  Future<AppUpdateDecision> checkForUpdates() {
    checks++;
    return decision;
  }

  @override
  Future<bool> openStore(AppUpdateDecision decision) async => true;
}

const _upToDate = AppUpdateDecision(
  status: AppUpdateStatus.upToDate,
  currentVersion: '1.0.0',
  currentBuild: 1,
);

class _Firebase extends FirebaseAuthService {
  @override
  LocalAuthSession? get currentSession => null;
}

class _Repository implements AuthRepository {
  @override
  Future<UserEntity> getMe() => throw UnimplementedError();
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

AuthBloc _authBloc() {
  final repository = _Repository();
  return AuthBloc(
    loginUseCase: LoginUseCase(repository),
    socialLoginUseCase: SocialLoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getMeUseCase: GetMeUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    firebaseAuthService: _Firebase(),
  );
}

Future<int> _pumpUntilLogin(WidgetTester tester, {int limitMs = 8000}) async {
  var elapsed = 0;
  while (find.text('login-route').evaluate().isEmpty && elapsed < limitMs) {
    await tester.pump(const Duration(milliseconds: 10));
    elapsed += 10;
  }
  return elapsed;
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _mount(WidgetTester tester, AuthBloc bloc) async {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('login-route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

void main() {
  setUp(() async {
    await sl.reset();
  });
  tearDown(sl.reset);

  testWidgets('MEASURE splash simulated ms to navigation with gates ready', (
    tester,
  ) async {
    final update = _UpdateService(Future.value(_upToDate));
    sl.registerSingleton<AppUpdateService>(update);
    final bloc = _authBloc()..add(const AuthCheckStatusRequested());
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    final elapsed = await _pumpUntilLogin(tester);
    // ignore: avoid_print
    print('SPLASH_MS_TO_NAVIGATION=$elapsed');
    expect(find.text('login-route'), findsOneWidget);
    expect(elapsed, lessThanOrEqualTo(300));
  });

  testWidgets('does not navigate while auth is unresolved', (tester) async {
    sl.registerSingleton<AppUpdateService>(
      _UpdateService(Future.value(_upToDate)),
    );
    final bloc = _authBloc(); // AuthInitial: gate not resolved.
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    await _pumpFor(tester, 4000);
    expect(find.text('login-route'), findsNothing);
    bloc.add(const AuthCheckStatusRequested());
    final elapsed = await _pumpUntilLogin(tester);
    expect(find.text('login-route'), findsOneWidget);
    expect(elapsed, lessThanOrEqualTo(300));
  });

  testWidgets('does not navigate while the update gate is pending', (
    tester,
  ) async {
    final decision = Completer<AppUpdateDecision>();
    sl.registerSingleton<AppUpdateService>(_UpdateService(decision.future));
    final bloc = _authBloc()..add(const AuthCheckStatusRequested());
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    await _pumpFor(tester, 4000);
    expect(find.text('login-route'), findsNothing);
    decision.complete(_upToDate);
    final elapsed = await _pumpUntilLogin(tester);
    expect(find.text('login-route'), findsOneWidget);
    expect(elapsed, lessThanOrEqualTo(300));
  });

  testWidgets('blocking update keeps the splash and never navigates', (
    tester,
  ) async {
    sl.registerSingleton<AppUpdateService>(
      _UpdateService(
        Future.value(
          const AppUpdateDecision(
            status: AppUpdateStatus.requiredUpdate,
            currentVersion: '1.0.0',
            currentBuild: 1,
          ),
        ),
      ),
    );
    final bloc = _authBloc()..add(const AuthCheckStatusRequested());
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    await _pumpFor(tester, 4000);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _pumpFor(tester, 5000);
    expect(find.text('login-route'), findsNothing);
  });
}
