import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';

class _PreferencesStorage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.light;
  @override
  Locale? getLocalePreference() => const Locale('en');
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

class _Repository implements HomeRepository {
  int loads = 0;
  bool completed = false;

  /// Holds the loads while set.
  Completer<void>? gate;

  /// Makes the loads fail while set.
  Object? error;

  /// E1 D1: answers the saved copy (still pending) flagged with this reason.
  String? staleReason;

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) async {
    loads++;
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    final stale = staleReason;
    final done = completed && stale == null;
    return HomeSummaryEntity(
      trainingId: 'training',
      trainingName: 'Training',
      trainingTypes: const ['FUERZA'],
      trainingCompleted: done,
      totalExercises: 1,
      exercisesCompleted: done ? 1 : 0,
      staleReason: stale,
    );
  }
}

/// `/calendar/month` of the clock's month: today holds one session, pending.
/// It keeps answering pending, as a saved calendar would after the
/// completion.
class _Calendar implements CalendarRepository {
  int requests = 0;

  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) async {
    requests++;
    final now = DateTime.now();
    if (now.year != year || now.month != month) return const [];
    return [
      CalendarDayEntity(
        date: DateTime(now.year, now.month, now.day),
        hasTraining: true,
        hasDiet: false,
        isRestDay: false,
        trainingCompleted: false,
        dietCompleted: false,
        trainingsAssigned: 1,
        trainingsDone: 0,
        trainingCompletionMode: 'ALL',
      ),
    ];
  }

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) =>
      throw UnimplementedError();
}

String _today() => HomeWeekMarks.dayKey(DateTime.now());

const _stamp = 'owner:1:test';

/// Inicio inside a shell that owns [bloc], as `MainShell` does.
Future<GoRouter> _mountInicio(
  WidgetTester tester, {
  required HomeBloc bloc,
  required String initialRoute,
}) async {
  await initializeDateFormatting('en');
  final preferences = AppPreferencesCubit(_PreferencesStorage());
  addTearDown(preferences.close);
  final router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      ShellRoute(
        builder: (_, _, child) =>
            BlocProvider<HomeBloc>.value(value: bloc, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => NoTransitionPage(
              child: HomePage(
                completionRefresh: switch (state.extra) {
                  HomeCompletionRefresh refresh => refresh,
                  _ => null,
                },
              ),
            ),
          ),
          GoRoute(
            path: '/calendar',
            builder: (_, _) => const Scaffold(body: Text('Calendar')),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

Future<void> _unmount(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
}

void main() {
  for (final initialRoute in ['/', '/calendar']) {
    testWidgets(
      'completion refresh reaches scoped HomeBloc from $initialRoute and repeats',
      (tester) async {
        await initializeDateFormatting('en');
        final repository = _Repository();
        final preferences = AppPreferencesCubit(_PreferencesStorage());
        final bloc = HomeBloc(
          getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
        )..add(const HomeLoadRequested());
        final router = GoRouter(
          initialLocation: initialRoute,
          routes: [
            ShellRoute(
              builder: (_, _, child) =>
                  BlocProvider<HomeBloc>.value(value: bloc, child: child),
              routes: [
                GoRoute(
                  path: '/',
                  pageBuilder: (_, state) => NoTransitionPage(
                    child: HomePage(
                      completionRefresh: switch (state.extra) {
                        HomeCompletionRefresh refresh => refresh,
                        _ => null,
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: '/calendar',
                  builder: (_, _) => const Scaffold(body: Text('Calendar')),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          BlocProvider<AppPreferencesCubit>.value(
            value: preferences,
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 1);
        repository.completed = true;
        final firstRefresh = HomeCompletionRefresh();
        router.go('/', extra: firstRefresh);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 2);
        expect((bloc.state as HomeLoaded).summary.trainingCompleted, isTrue);
        expect(find.byType(HomePage), findsOneWidget);
        // A route rebuild with the same intent must not reload the summary.
        router.go('/', extra: firstRefresh);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 2);
        repository.completed = false;
        router.go('/', extra: HomeCompletionRefresh());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 3);
        expect((bloc.state as HomeLoaded).summary.trainingCompleted, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        addTearDown(bloc.close);
        addTearDown(preferences.close);
      },
    );
  }

  // E6a, owner decision 2026-11-26: back from «Sesión hecha», Inicio paints
  // the confirmed session as done at once (no skeleton, no pending frame)
  // and settles when the one reload lands.
  group('back from the milestone', () {
    late _Repository repository;
    late _Calendar calendar;
    late HomeBloc bloc;
    late String? currentStamp;

    setUp(() {
      repository = _Repository();
      calendar = _Calendar();
      currentStamp = _stamp;
    });

    /// Built inside the test body, so its async work runs in the test's
    /// fake-async zone and settles with each pump.
    Future<GoRouter> mount(WidgetTester tester, {String initialRoute = '/'}) {
      bloc = HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
        getMonthCalendarUseCase: GetMonthCalendarUseCase(calendar),
        sessionStamp: () => currentStamp,
      )..add(const HomeLoadRequested());
      addTearDown(bloc.close);
      return _mountInicio(tester, bloc: bloc, initialRoute: initialRoute);
    }

    HomeCompletionRefresh confirmed({
      String trainingId = 'training',
      String? date,
      String? stamp = _stamp,
    }) => HomeCompletionRefresh(
      trainingId: trainingId,
      date: date ?? _today(),
      sessionStamp: stamp,
    );

    Completer<void> holdReload() {
      final gate = repository.gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      return gate;
    }

    void expectDone() {
      expect(find.text('START SESSION'), findsNothing);
      expect(find.text('Open training'), findsOneWidget);
      expect(find.text('1 of 1 session done'), findsOneWidget);
      expect(find.byType(ExomSkeleton), findsNothing);
    }

    void expectPending() {
      expect(find.text('START SESSION'), findsOneWidget);
      expect(find.text('0 of 1 session done'), findsOneWidget);
    }

    for (final initialRoute in ['/', '/calendar']) {
      testWidgets('from $initialRoute, the first frame shows the session '
          'and the week done, with one reload', (tester) async {
        final router = await mount(tester, initialRoute: initialRoute);
        expect(repository.loads, 1);
        expect(calendar.requests, 1);
        if (initialRoute == '/') expectPending();

        repository.completed = true;
        final gate = holdReload();
        router.go('/', extra: confirmed());
        await tester.pump();
        // First frame back on Inicio, reload still in flight.
        expectDone();
        await tester.pump(const Duration(milliseconds: 800));
        expectDone();

        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expectDone();
        // The return reloads once (summary and its week), nothing more.
        expect(repository.loads, 2);
        expect(calendar.requests, 2);
        await _unmount(tester, router);
      });
    }

    testWidgets('a reload that fails keeps the session done and reports it', (
      tester,
    ) async {
      final router = await mount(tester);
      expectPending();

      final gate = holdReload();
      repository.error = const ApiException(statusCode: 0, message: 'x');
      router.go('/', extra: confirmed());
      await tester.pump();
      expectDone();

      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectDone();
      expect(find.text('Offline · saved data'), findsOneWidget);
      expect(repository.loads, 2);
      await _unmount(tester, router);
    });

    testWidgets('a reload served from the saved copy (still pending) keeps '
        'the session done and reports it', (tester) async {
      final router = await mount(tester);
      expectPending();

      final gate = holdReload();
      repository.staleReason = 'ApiException(0): x';
      router.go('/', extra: confirmed());
      await tester.pump();
      expectDone();

      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectDone();
      expect(find.text('Offline · saved data'), findsOneWidget);
      expect(repository.loads, 2);
      await _unmount(tester, router);
    });

    testWidgets('another account meanwhile: no patch, the reload decides', (
      tester,
    ) async {
      final router = await mount(tester);
      expectPending();

      final gate = holdReload();
      currentStamp = 'other:1:test';
      router.go('/', extra: confirmed());
      await tester.pump();
      expectPending();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.loads, 2);
      await _unmount(tester, router);
    });

    testWidgets('a completion confirmed by another session: no patch', (
      tester,
    ) async {
      final router = await mount(tester);
      final gate = holdReload();
      router.go('/', extra: confirmed(stamp: 'other:1:test'));
      await tester.pump();
      expectPending();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _unmount(tester, router);
    });

    testWidgets('the same refresh again (route rebuilt with its extra alive) '
        'does not bring back a completion the reload said undone', (
      tester,
    ) async {
      final router = await mount(tester);
      expectPending();

      // The reload answers "not done": the patch is replaced by it.
      final refresh = confirmed();
      router.go('/', extra: refresh);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectPending();

      // Inicio is rebuilt with the very same retained extra.
      router.go('/calendar');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      router.go('/', extra: refresh);
      await tester.pump();
      expectPending();
      await tester.pump(const Duration(milliseconds: 300));
      expectPending();
      await _unmount(tester, router);
    });

    for (final (label, refresh) in [
      ('another training', () => confirmed(trainingId: 'other')),
      ('another date', () => confirmed(date: '2000-01-03')),
      ('no identity (older caller)', HomeCompletionRefresh.new),
    ]) {
      testWidgets('$label: no patch, Inicio keeps its content until the '
          'reload', (tester) async {
        final router = await mount(tester);
        repository.completed = true;
        final gate = holdReload();
        router.go('/', extra: refresh());
        await tester.pump();
        expectPending();

        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Open training'), findsOneWidget);
        expect(repository.loads, 2);
        await _unmount(tester, router);
      });
    }
  });
}
