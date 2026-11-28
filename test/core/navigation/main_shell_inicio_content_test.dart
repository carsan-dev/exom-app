// L5-D3 r5, review follow-up 2: the real MainShell wiring of the content
// signal (D3-Q6). splash_page_timing_test.dart counts HomeBloc with a probe
// that replicates `_MainShellState.initState`; here the real MainShell,
// with a real HomeBloc, reports Inicio's content to the hand-off from
// `_homeBloc.stream`, only during a hand-off and only once its data arrive.
import 'dart:async';

import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/services/fcm_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:exom_app/features/notifications/domain/usecases/delete_read_notifications_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/get_my_notifications_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/get_unread_count_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/mark_all_notifications_as_read_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/mark_notification_as_read_usecase.dart';
import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/onboarding_harness.dart';

/// Inicio's summary, answered when the test completes [answer].
class _HomeRepository implements HomeRepository {
  final answer = Completer<HomeSummaryEntity>();

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) => answer.future;
}

class _NotificationsRepository extends Fake implements NotificationsRepository {
  @override
  Future<int> getUnreadCount() async => 0;
}

class _Fcm extends Fake implements FcmService {
  final _messages = StreamController<RemoteMessage>.broadcast();

  @override
  Stream<RemoteMessage> get onIncomingMessage => _messages.stream;
}

/// Never asked: without a session the shell reads no prompt.
class _Prompts extends Fake implements AutomaticPromptCoordinator {}

Future<_HomeRepository> _mountShell(WidgetTester tester) async {
  final home = _HomeRepository();
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(getHomeSummaryUseCase: GetHomeSummaryUseCase(home)),
  );
  final notifications = _NotificationsRepository();
  sl.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(
      getMyNotifications: GetMyNotificationsUseCase(notifications),
      getUnreadCount: GetUnreadCountUseCase(notifications),
      markAsRead: MarkNotificationAsReadUseCase(notifications),
      markAllAsRead: MarkAllNotificationsAsReadUseCase(notifications),
      deleteRead: DeleteReadNotificationsUseCase(notifications),
    ),
  );
  sl.registerSingleton<FcmService>(_Fcm());
  sl.registerSingleton<AutomaticPromptCoordinator>(_Prompts());
  final firebase = SessionFirebaseAuthService(null);
  sl.registerSingleton<FirebaseAuthService>(firebase);
  sl.registerSingleton<LocalStorage>(
    LocalStorage(currentSession: () => firebase.currentSession),
  );
  final repository = ScriptedAuthRepository(
    userFromServer(profile: doneProfile),
  );
  final auth = AuthBloc(
    loginUseCase: LoginUseCase(repository),
    socialLoginUseCase: SocialLoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getMeUseCase: GetMeUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    firebaseAuthService: firebase,
  );
  addTearDown(auth.close);
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Text('splash')),
      ),
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const Text('home-route'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  router.go(AppRoutes.home);
  return home;
}

void main() {
  setUp(() async {
    await sl.reset();
  });
  tearDown(() async {
    V4dHandoff.reset();
    await sl.reset();
  });

  testWidgets('during a hand-off, MainShell reports Inicio content once its '
      'HomeBloc has data, after the frame that paints it', (tester) async {
    V4dHandoff.current.value = const V4dOpening.waiting(
      centre: Offset.zero,
      reduced: false,
    );
    final home = await _mountShell(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MainShell), findsOneWidget);
    // HomeLoading (the skeleton) is not content.
    expect(V4dHandoff.inicioContent.value, isFalse);

    home.answer.complete(const HomeSummaryEntity());
    await tester.pump();
    await tester.pump();
    expect(V4dHandoff.inicioContent.value, isTrue);
  });

  testWidgets('outside a hand-off MainShell reports nothing', (tester) async {
    final home = await _mountShell(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MainShell), findsOneWidget);
    // A hand-off that starts later does not pick up this shell's data.
    V4dHandoff.current.value = const V4dOpening.waiting(
      centre: Offset.zero,
      reduced: false,
    );
    home.answer.complete(const HomeSummaryEntity());
    await tester.pump();
    await tester.pump();
    expect(V4dHandoff.inicioContent.value, isFalse);
  });
}
