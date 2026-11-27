// Account switch A→B: the shell bell never shows A's unread count to B,
// neither from A's last state nor from an A response that arrives late.
import 'dart:async';

import 'package:exom_app/core/auth/auth_token_provider.dart';
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
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/onboarding_harness.dart';

const _sessionA = LocalAuthSession(
  uid: 'uid-a',
  email: 'a@x.test',
  generation: 1,
);
const _sessionB = LocalAuthSession(
  uid: 'uid-b',
  email: 'b@x.test',
  generation: 3,
);

class _HomeRepository implements HomeRepository {
  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) => Completer<HomeSummaryEntity>().future;
}

/// Each unread-count request waits for the test to answer it; the request
/// remembers the account that was signed in when it was sent.
class _NotificationsRepository extends Fake implements NotificationsRepository {
  _NotificationsRepository(this._auth);

  final SessionFirebaseAuthService _auth;
  final requests = <({String? uid, Completer<int> answer})>[];

  Completer<int> lastFor(String uid) =>
      requests.lastWhere((request) => request.uid == uid).answer;

  @override
  Future<int> getUnreadCount() {
    final answer = Completer<int>();
    requests.add((uid: _auth.currentSession?.uid, answer: answer));
    return answer.future;
  }
}

class _Fcm extends Fake implements FcmService {
  final _messages = StreamController<RemoteMessage>.broadcast();

  @override
  Stream<RemoteMessage> get onIncomingMessage => _messages.stream;
}

/// Never asked: AuthBloc stays in AuthInitial, so the shell reads no prompt.
class _Prompts extends Fake implements AutomaticPromptCoordinator {}

class _Harness {
  _Harness(this.auth, this.notifications, this.router);

  final SessionFirebaseAuthService auth;
  final _NotificationsRepository notifications;
  final GoRouter router;

  /// Leaves the shell (logout) and enters it again as [next].
  Future<void> switchTo(WidgetTester tester, LocalAuthSession next) async {
    router.go('/login');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MainShell), findsNothing);
    auth.session = null;
    auth.session = next;
    router.go(AppRoutes.home);
    // Stops at the first frame that builds the new account's shell.
    for (var i = 0; i < 30 && find.byType(MainShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<_Harness> _mountShellAs(
  WidgetTester tester,
  LocalAuthSession session,
) async {
  final home = _HomeRepository();
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(getHomeSummaryUseCase: GetHomeSummaryUseCase(home)),
  );
  final firebase = SessionFirebaseAuthService(session);
  sl.registerSingleton<FirebaseAuthService>(firebase);
  final notifications = _NotificationsRepository(firebase);
  sl.registerLazySingleton(() => GetMyNotificationsUseCase(notifications));
  sl.registerLazySingleton(() => GetUnreadCountUseCase(notifications));
  sl.registerLazySingleton(() => MarkNotificationAsReadUseCase(notifications));
  sl.registerLazySingleton(
    () => MarkAllNotificationsAsReadUseCase(notifications),
  );
  sl.registerLazySingleton(() => DeleteReadNotificationsUseCase(notifications));
  // The production wiring of the bell's bloc.
  registerAppNotificationsBloc();
  sl.registerSingleton<FcmService>(_Fcm());
  sl.registerSingleton<AutomaticPromptCoordinator>(_Prompts());
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
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login')),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byType(MainShell), findsOneWidget);
  return _Harness(firebase, notifications, router);
}

Finder _badge(String count) => find.descendant(
  of: find.byType(ShellUnreadBadge),
  matching: find.text(count),
);

void main() {
  setUp(() async {
    await sl.reset();
  });
  tearDown(() async {
    await sl.reset();
  });

  testWidgets('the first frame of account B does not show the unread count '
      'of account A', (tester) async {
    final harness = await _mountShellAs(tester, _sessionA);
    harness.notifications.lastFor('uid-a').complete(7);
    await tester.pump();
    expect(_badge('7'), findsOneWidget);

    await harness.switchTo(tester, _sessionB);

    expect(find.byType(MainShell), findsOneWidget);
    expect(_badge('7'), findsNothing);
    expect(find.byType(ShellUnreadBadge), findsNothing);

    // B's own count arrives and is shown.
    harness.notifications.lastFor('uid-b').complete(2);
    await tester.pump();
    expect(_badge('2'), findsOneWidget);
  });

  testWidgets('an unread count of account A that answers after the switch '
      'to account B is ignored', (tester) async {
    final harness = await _mountShellAs(tester, _sessionA);
    final lateA = harness.notifications.lastFor('uid-a');

    await harness.switchTo(tester, _sessionB);
    harness.notifications.lastFor('uid-b').complete(2);
    await tester.pump();
    expect(_badge('2'), findsOneWidget);

    lateA.complete(7);
    await tester.pump();
    await tester.pump();
    expect(_badge('7'), findsNothing);
    expect(_badge('2'), findsOneWidget);
  });

  testWidgets('an unread count of account A that answers after the switch '
      'and before B answers is ignored', (tester) async {
    final harness = await _mountShellAs(tester, _sessionA);
    final lateA = harness.notifications.lastFor('uid-a');

    await harness.switchTo(tester, _sessionB);
    lateA.complete(7);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShellUnreadBadge), findsNothing);

    harness.notifications.lastFor('uid-b').complete(2);
    await tester.pump();
    expect(_badge('2'), findsOneWidget);
  });

  testWidgets('within one session the bell and the notifications page share '
      'the bloc; a new sign-in gets another one', (tester) async {
    final harness = await _mountShellAs(tester, _sessionA);
    final ofA = sl<NotificationsBloc>();
    expect(sl<NotificationsBloc>(), same(ofA));

    // The same account signing in again is a new session.
    await harness.switchTo(
      tester,
      const LocalAuthSession(uid: 'uid-a', email: 'a@x.test', generation: 5),
    );
    final again = sl<NotificationsBloc>();
    expect(again, isNot(same(ofA)));
    expect(sl<NotificationsBloc>(), same(again));
    expect(ofA.isClosed, isFalse);
  });
}
