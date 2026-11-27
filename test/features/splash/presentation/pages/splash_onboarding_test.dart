import 'dart:io';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/onboarding/onboarding_sync_coordinator.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/splash/presentation/pages/splash_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/onboarding_harness.dart';
import '../../../../helpers/onboarding_remote_fakes.dart';

class _UpToDate extends Fake implements AppUpdateService {
  @override
  Future<AppUpdateDecision> checkForUpdates() async => const AppUpdateDecision(
    status: AppUpdateStatus.upToDate,
    currentVersion: '1.0.0',
    currentBuild: 1,
  );

  @override
  Future<bool> openStore(AppUpdateDecision decision) async => true;
}

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');
const _markKey = 'onboarding_complete::a@exom.test';

void main() {
  late Directory directory;
  late SessionFirebaseAuthService firebase;
  late LocalStorage storage;
  late FakeOnboardingRemote remote;
  late OnboardingSyncCoordinator coordinator;

  setUp(() async {
    await sl.reset();
    directory = await openInMemorySettingsBox();
    firebase = SessionFirebaseAuthService(_sessionA);
    storage = LocalStorage(currentSession: () => firebase.currentSession);
    sl.registerSingleton<AppUpdateService>(_UpToDate());
    sl.registerSingleton<FirebaseAuthService>(firebase);
    sl.registerSingleton<LocalStorage>(storage);
    remote = FakeOnboardingRemote();
    coordinator = OnboardingSyncCoordinator(
      storage: storage,
      currentSession: () => firebase.currentSession,
      remote: remote,
    );
  });

  tearDown(() async {
    await sl.reset();
    await closeSettingsBox(directory);
  });

  AuthBloc buildBloc(Object getMeResult) {
    final repository = ScriptedAuthRepository(getMeResult);
    return AuthBloc(
      loginUseCase: LoginUseCase(repository),
      socialLoginUseCase: SocialLoginUseCase(repository),
      logoutUseCase: LogoutUseCase(repository),
      getMeUseCase: GetMeUseCase(repository),
      deleteAccountUseCase: DeleteAccountUseCase(repository),
      firebaseAuthService: firebase,
      onSessionStateChanged: coordinator.handle,
    );
  }

  Future<void> runSplash(WidgetTester tester, AuthBloc bloc) async {
    final router = GoRouter(
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
        for (final route in [
          AppRoutes.login,
          AppRoutes.home,
          AppRoutes.onboarding,
          AppRoutes.accountLocked,
        ])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(body: Text('route:$route')),
          ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(bloc.close);
    bloc.add(const AuthCheckStatusRequested());
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
    for (var elapsed = 0; elapsed < 3500; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'OP-RED-01 reinstall: empty Hive + server done goes Home and caches',
    (tester) async {
      expect(settingsBox.isEmpty, isTrue);
      await runSplash(tester, buildBloc(userFromServer(profile: doneProfile)));

      expect(find.text('route:${AppRoutes.home}'), findsOneWidget);
      expect(find.text('route:${AppRoutes.onboarding}'), findsNothing);
      expect(settingsBox.get(_markKey), isTrue);
    },
  );

  testWidgets('OP-RED-03 offline /auth/me + empty Hive goes Home', (
    tester,
  ) async {
    await runSplash(
      tester,
      buildBloc(const ApiException(statusCode: 0, message: 'offline')),
    );

    expect(find.text('route:${AppRoutes.home}'), findsOneWidget);
    expect(find.text('route:${AppRoutes.onboarding}'), findsNothing);
  });

  testWidgets('OP-APP-04 reinstall with a stale pending clears it (R3)', (
    tester,
  ) async {
    await storage.markOnboardingLocallyDone(
      uid: 'uid-A',
      email: 'a@exom.test',
      outcome: 'SKIPPED',
    );
    await runSplash(tester, buildBloc(userFromServer(profile: doneProfile)));

    expect(find.text('route:${AppRoutes.home}'), findsOneWidget);
    expect(storage.onboardingPendingFor('uid-A'), isNull);
    expect(remote.calls, isEmpty);
  });

  for (final status in [401, 403]) {
    testWidgets('OP-APP-06 /auth/me $status goes to login, pending intact', (
      tester,
    ) async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: 'COMPLETED',
      );
      await runSplash(
        tester,
        buildBloc(ApiException(statusCode: status, message: 'rejected')),
      );

      expect(find.text('route:${AppRoutes.login}'), findsOneWidget);
      expect(storage.onboardingPendingFor('uid-A')?['outcome'], 'COMPLETED');
      expect(settingsBox.get(_markKey), isTrue);
      expect(remote.calls, isEmpty);
    });
  }

  testWidgets('OP-APP-06 /auth/me 423 goes to account locked', (tester) async {
    await storage.markOnboardingLocallyDone(
      uid: 'uid-A',
      email: 'a@exom.test',
      outcome: 'COMPLETED',
    );
    await runSplash(
      tester,
      buildBloc(const ApiException(statusCode: 423, message: 'locked')),
    );

    expect(find.text('route:${AppRoutes.accountLocked}'), findsOneWidget);
    expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    expect(remote.calls, isEmpty);
  });

  testWidgets('OP-APP-06 /auth/me 5xx keeps previous behaviour (login)', (
    tester,
  ) async {
    await storage.markOnboardingLocallyDone(
      uid: 'uid-A',
      email: 'a@exom.test',
      outcome: 'COMPLETED',
    );
    await runSplash(
      tester,
      buildBloc(const ApiException(statusCode: 503, message: 'down')),
    );

    expect(find.text('route:${AppRoutes.login}'), findsOneWidget);
    expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    expect(remote.calls, isEmpty);
  });

  testWidgets('OP-APP-06 offline with a pending entry never sends it', (
    tester,
  ) async {
    await storage.markOnboardingLocallyDone(
      uid: 'uid-A',
      email: 'a@exom.test',
      outcome: 'SKIPPED',
    );
    await runSplash(
      tester,
      buildBloc(const ApiException(statusCode: 0, message: 'offline')),
    );

    expect(find.text('route:${AppRoutes.home}'), findsOneWidget);
    expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    expect(remote.calls, isEmpty);
  });

  for (final role in ['ADMIN', 'SUPER_ADMIN']) {
    testWidgets('OP-APP-14 validated $role never sees onboarding nor POST', (
      tester,
    ) async {
      await runSplash(
        tester,
        buildBloc(userFromServer(role: role, profile: pendingProfile)),
      );

      expect(find.text('route:${AppRoutes.home}'), findsOneWidget);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
      expect(remote.calls, isEmpty);
    });
  }

  testWidgets('server pending + empty Hive still opens onboarding', (
    tester,
  ) async {
    await runSplash(tester, buildBloc(userFromServer(profile: pendingProfile)));

    expect(find.text('route:${AppRoutes.onboarding}'), findsOneWidget);
  });
}
