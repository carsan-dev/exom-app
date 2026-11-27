// L5-D49 (O4-CAMPANA): when Inicio goes from stale data (or an error) to
// fresh data, the shell asks again for the bell counter, once, of the
// session that is current at that moment.
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
import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc_session_scope.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/onboarding_harness.dart';

/// Inicio's summary: each call takes the next scripted answer.
class _HomeRepository implements HomeRepository {
  final _answers = <Completer<HomeSummaryEntity>>[];
  int calls = 0;

  void answerNext(HomeSummaryEntity summary) {
    _answers.add(Completer<HomeSummaryEntity>()..complete(summary));
  }

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) => _answers[calls++].future;
}

/// Counts the unread-count requests of one account; answers [count].
class _NotificationsRepository extends Fake implements NotificationsRepository {
  _NotificationsRepository(this.count);
  final int count;
  int requests = 0;

  @override
  Future<int> getUnreadCount() async {
    requests++;
    return count;
  }
}

class _Fcm extends Fake implements FcmService {
  final _messages = StreamController<RemoteMessage>.broadcast();

  @override
  Stream<RemoteMessage> get onIncomingMessage => _messages.stream;
}

class _Prompts extends Fake implements AutomaticPromptCoordinator {}

const _stale = HomeSummaryEntity(staleReason: 'ApiException(0): offline');
const _fresh = HomeSummaryEntity();

class _Mounted {
  _Mounted(this.home, this.accounts, this.owner);
  final _HomeRepository home;
  final Map<String, _NotificationsRepository> accounts;
  final ValueNotifier<String> owner;
}

Future<_Mounted> _mountShell(
  WidgetTester tester, {
  required HomeSummaryEntity first,
  int countOfA = 0,
}) async {
  final home = _HomeRepository()..answerNext(first);
  final accounts = {
    'a': _NotificationsRepository(countOfA),
    'b': _NotificationsRepository(7),
  };
  final owner = ValueNotifier<String>('a');
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(getHomeSummaryUseCase: GetHomeSummaryUseCase(home)),
  );
  // One bloc per account, as registerAppNotificationsBloc does.
  final scope = NotificationsBlocSessionScope(
    create: () {
      final repo = accounts[owner.value]!;
      return NotificationsBloc(
        getMyNotifications: GetMyNotificationsUseCase(repo),
        getUnreadCount: GetUnreadCountUseCase(repo),
        markAsRead: MarkNotificationAsReadUseCase(repo),
        markAllAsRead: MarkAllNotificationsAsReadUseCase(repo),
        deleteRead: DeleteReadNotificationsUseCase(repo),
      );
    },
    sessionKey: () => owner.value,
  );
  sl.registerFactory<NotificationsBloc>(() => scope.current);
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
  await _settle(tester);
  return _Mounted(home, accounts, owner);
}

Future<void> _reload(WidgetTester tester, _Mounted m, HomeSummaryEntity next) {
  m.home.answerNext(next);
  tester.element(find.text('home-route')).read<HomeBloc>().add(
    const HomeLoadRequested(),
  );
  return _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() async {
    await sl.reset();
  });
  tearDown(() async {
    V4dHandoff.reset();
    await sl.reset();
  });

  testWidgets('offline start: Inicio goes stale -> fresh, the counter is '
      'asked again once and the bell shows it', (tester) async {
    final m = await _mountShell(tester, first: _stale, countOfA: 4);
    // The start request ran; it is the only one so far.
    expect(m.accounts['a']!.requests, 1);

    await _reload(tester, m, _fresh);
    expect(m.accounts['a']!.requests, 2);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('Inicio already fresh: no extra request, however often it '
      'reloads', (tester) async {
    final m = await _mountShell(tester, first: _fresh);
    await _reload(tester, m, _fresh);
    await _reload(tester, m, _fresh);
    expect(m.accounts['a']!.requests, 1);
  });

  testWidgets('one request per stale -> fresh transition, none while it '
      'stays stale or once fresh', (tester) async {
    final m = await _mountShell(tester, first: _stale);
    await _reload(tester, m, _stale);
    expect(m.accounts['a']!.requests, 1);
    await _reload(tester, m, _fresh);
    expect(m.accounts['a']!.requests, 2);
    await _reload(tester, m, _fresh);
    expect(m.accounts['a']!.requests, 2);
  });

  testWidgets('account change while Inicio is stale: the request goes to the '
      'current account, not to the previous one', (tester) async {
    final m = await _mountShell(tester, first: _stale);
    expect(m.accounts['a']!.requests, 1);

    m.owner.value = 'b';
    await _reload(tester, m, _fresh);
    expect(m.accounts['a']!.requests, 1);
    expect(m.accounts['b']!.requests, 1);
  });
}
