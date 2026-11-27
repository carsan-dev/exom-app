// L5-E1 «Inicio» test support: HomePage over a real HomeBloc with a fake
// summary repository and an optional fake `/calendar/month`, inside a
// GoRouter, with the injectable clock fixed to Wednesday 18 Nov 2026.
// Not a test file: it has no `main` and is only imported.
import 'dart:async';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
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

final inicioE1Now = DateTime(2026, 11, 18, 9);
final inicioE1Wednesday = DateTime(2026, 11, 18);

class _PreferencesStorage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => const Locale('es');
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

/// Summary repository: [summaryFor] by date; [error] makes the next loads
/// fail; [gate] holds them.
class InicioE1Repository implements HomeRepository {
  InicioE1Repository(this.summaryFor);

  HomeSummaryEntity Function(DateTime? date) summaryFor;
  Object? error;
  Completer<void>? gate;
  final dates = <DateTime?>[];

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) async {
    dates.add(date);
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    return summaryFor(date);
  }
}

/// `/calendar/month` stand-in: [days] by `yyyy-mm-dd`. [error] makes every
/// month fail. [gates] holds the n-th request (0-based) until completed, and
/// [daysFor] can give that request its own days.
class InicioE1Calendar implements CalendarRepository {
  InicioE1Calendar(this.days, {this.error});

  Map<String, CalendarDayEntity> days;
  Object? error;
  final gates = <int, Completer<void>>{};
  final daysFor = <int, Map<String, CalendarDayEntity>>{};
  int calls = 0;

  static CalendarDayEntity day(
    String date, {
    bool training = false,
    bool diet = false,
    bool rest = false,
    bool done = false,
  }) => CalendarDayEntity(
    date: DateTime.parse(date),
    hasTraining: training,
    hasDiet: diet,
    isRestDay: rest,
    trainingCompleted: done,
    dietCompleted: false,
  );

  /// Every day of the week of 16-22 Nov 2026 without assignment, then
  /// [overrides].
  static Map<String, CalendarDayEntity> week(
    Map<String, CalendarDayEntity> overrides,
  ) => {
    for (var d = 16; d <= 22; d++) '2026-11-$d': day('2026-11-$d'),
    ...overrides,
  };

  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) async {
    final call = calls++;
    final own = daysFor[call] ?? days;
    final gate = gates[call];
    if (gate != null) await gate.future;
    final failure = error;
    if (failure != null) throw failure;
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    return [
      for (final entry in own.entries)
        if (entry.key.startsWith(prefix)) entry.value,
    ];
  }

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) =>
      throw UnimplementedError();
}

const inicioE1Training = HomeSummaryEntity(
  trainingId: 'training-1',
  trainingName: 'Pierna fuerza',
  trainingTypes: ['FUERZA'],
  trainingDurationMin: 55,
  remainingTrainingDurationMin: 55,
  trainings: [
    HomeTrainingItemEntity(
      id: 'training-1',
      name: 'Pierna fuerza',
      completed: false,
    ),
  ],
  totalExercises: 6,
  totalSets: 22,
  dietId: 'diet-1',
  dietName: 'Definición',
  totalCalories: 2150,
  remainingCalories: 1500,
  mealsCompleted: 1,
  totalMeals: 4,
  streakDays: 12,
  lastWeightKg: 62.5,
  lastSleepHours: 7.5,
  programWeek: 3,
  programDay: 2,
);

/// Same session, in progress: 2 of 6 exercises done, about 30 min left.
const inicioE1InProgress = HomeSummaryEntity(
  trainingId: 'training-1',
  trainingName: 'Pierna fuerza',
  trainingDurationMin: 55,
  remainingTrainingDurationMin: 30,
  trainings: [
    HomeTrainingItemEntity(
      id: 'training-1',
      name: 'Pierna fuerza',
      completed: false,
    ),
  ],
  exercisesCompleted: 2,
  totalExercises: 6,
  totalSets: 22,
  streakDays: 12,
);

/// Same session, done.
const inicioE1Done = HomeSummaryEntity(
  trainingId: 'training-1',
  trainingName: 'Pierna fuerza',
  trainingDurationMin: 55,
  trainingCompleted: true,
  trainings: [
    HomeTrainingItemEntity(
      id: 'training-1',
      name: 'Pierna fuerza',
      completed: true,
    ),
  ],
  exercisesCompleted: 6,
  totalExercises: 6,
  totalSets: 22,
  streakDays: 12,
);

/// A day with neither training nor diet in the summary (rest day or no plan:
/// the summary cannot tell them apart, L5-D27).
const inicioE1Empty = HomeSummaryEntity(isRestDay: true, streakDays: 0);

class InicioE1Harness {
  InicioE1Harness(this.repository, this.bloc, this.router);
  final InicioE1Repository repository;
  final HomeBloc bloc;
  final GoRouter router;
  Uri? opened;
}

Future<InicioE1Harness> pumpInicioE1(
  WidgetTester tester, {
  required InicioE1Repository repository,
  InicioE1Calendar? calendar,
  DateTime? date,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.dark,
  Locale locale = const Locale('es'),
  bool settle = true,
}) async {
  await initializeDateFormatting(locale.languageCode);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final preferences = AppPreferencesCubit(_PreferencesStorage());
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
    getMonthCalendarUseCase: calendar == null
        ? null
        : GetMonthCalendarUseCase(calendar),
  )..add(HomeLoadRequested(date: date ?? inicioE1Wednesday));
  late final InicioE1Harness harness;
  Widget destination(String label, GoRouterState state) {
    harness.opened = state.uri;
    return Scaffold(body: Text(label));
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: HomePage(now: () => inicioE1Now)),
      ),
      for (final path in const [
        '/trainings/:id',
        '/calendar',
        '/diets',
        '/challenges',
        '/profile/metrics',
      ])
        GoRoute(path: path, builder: (_, state) => destination(path, state)),
    ],
  );
  harness = InicioE1Harness(repository, bloc, router);
  addTearDown(router.dispose);
  addTearDown(bloc.close);
  addTearDown(preferences.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AppPreferencesCubit>.value(value: preferences),
        BlocProvider<HomeBloc>.value(value: bloc),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return harness;
}
