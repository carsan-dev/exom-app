// Shared fixture of the L5-A4a «Calendario» tests and goldens: a bloc seeded
// with a fixed state (no network) that records the events the page sends, a
// router with stub destinations and the real CalendarPage with the redesign
// theme, fonts, locale and text scale.
// Not a test file: it has no `main` and is only imported.
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_week_summary_usecase.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/exom_component_harness.dart';
import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

class _UnusedCalendarRepository extends Fake implements CalendarRepository {}

class _UnusedChallengesRepository extends Fake
    implements ChallengesRepository {}

/// Bloc that starts in [seed] and records the events the page sends instead of
/// loading anything.
class SeededCalendarBloc extends CalendarBloc {
  SeededCalendarBloc(CalendarState seed)
    : super(
        getMonthCalendarUseCase: GetMonthCalendarUseCase(
          _UnusedCalendarRepository(),
        ),
        getWeekSummaryUseCase: GetWeekSummaryUseCase(
          _UnusedCalendarRepository(),
        ),
        getMyChallengesUseCase: GetMyChallengesUseCase(
          _UnusedChallengesRepository(),
        ),
      ) {
    emit(seed);
  }

  final events = <CalendarEvent>[];

  @override
  void add(CalendarEvent event) => events.add(event);

  /// Moves the bloc to [state], as a real load would.
  void seed(CalendarState state) => emit(state);
}

/// Month of every scene: a past month, so no day is «today» and pending
/// sessions before today are «not done» whatever the real clock says.
const int kSceneYear = 2026;
const int kSceneMonth = 10;

/// Selected day of the main scene: Thursday 15 October 2026.
final DateTime kSceneSelected = DateTime(2026, 10, 15);

/// Training days of the scene and the ones completed (9 of 12).
const List<int> kSceneTrainingDays = [1, 2, 5, 6, 8, 9, 12, 13, 15, 16, 19, 20];
const List<int> kSceneTrainingDone = [1, 2, 5, 6, 8, 9, 12, 13, 16];

/// Rest days of the scene (weekends of the first two weeks).
const List<int> kSceneRestDays = [3, 4, 10, 11];

/// Day with a challenge deadline.
final DateTime kSceneChallengeDay = DateTime(2026, 10, 21);

List<CalendarDayEntity> sceneDays() => [
  for (var d = 1; d <= 31; d++)
    CalendarDayEntity(
      date: DateTime(kSceneYear, kSceneMonth, d),
      hasTraining: kSceneTrainingDays.contains(d),
      hasDiet: !kSceneRestDays.contains(d),
      isRestDay: kSceneRestDays.contains(d),
      trainingCompleted: kSceneTrainingDone.contains(d),
      dietCompleted: d <= 14 && !kSceneRestDays.contains(d),
    ),
];

ChallengeEntity sceneChallenge({String title = 'Diez mil pasos'}) =>
    ChallengeEntity(
      id: 'uc-1',
      challengeId: 'c-1',
      currentValue: 2,
      isCompleted: false,
      assignedAt: DateTime(2026, 9, 1),
      title: title,
      description: '',
      type: 'WEEKLY',
      targetValue: 5,
      unit: 'días',
      isManual: false,
      deadline: kSceneChallengeDay,
    );

const WeekSummaryEntity kSceneWeek = WeekSummaryEntity(
  weekStart: '2026-10-12',
  trainingsAssigned: 4,
  trainingsCompleted: 3,
  totalMeals: 28,
  mealsCompleted: 9,
);

CalendarLoaded sceneLoaded({
  List<CalendarDayEntity>? days,
  WeekSummaryEntity? week = kSceneWeek,
  List<ChallengeEntity>? challenges,
  DateTime? selected,
  int year = kSceneYear,
  int month = kSceneMonth,
}) => CalendarLoaded(
  days: days ?? sceneDays(),
  weekSummary: week,
  challenges: challenges ?? [sceneChallenge()],
  selectedDate: selected ?? kSceneSelected,
  year: year,
  month: month,
);

/// A month with nothing scheduled (December 2026).
CalendarLoaded sceneEmpty() => CalendarLoaded(
  days: const [],
  weekSummary: null,
  challenges: const [],
  selectedDate: DateTime(2026, 12),
  year: 2026,
  month: 12,
);

CalendarError sceneOffline() => const CalendarError(
  message: 'offline',
  apiException: ApiException(statusCode: 0, message: 'offline'),
);

CalendarError sceneServerError() => const CalendarError(
  message: 'boom',
  apiException: ApiException(statusCode: 500, message: 'boom'),
);

/// URIs opened from the calendar (destinations are stubs).
final List<String> openedRoutes = [];

/// Registers a bloc seeded with [state] and mounts the real CalendarPage inside
/// a Scaffold under a GoRouter. [textScaler], when given, replaces the linear
/// [textScale] (e.g. the nonlinear scaler of an Android 14+ device).
Future<SeededCalendarBloc> pumpCalendarScene(
  WidgetTester tester, {
  required CalendarState state,
  String? initialDate = '2026-10-15',
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
  double devicePixelRatio = 1.0,
}) async {
  final bloc = SeededCalendarBloc(state);
  await pumpCalendarWithBloc(
    tester,
    bloc,
    initialDate: initialDate,
    brightness: brightness,
    width: width,
    height: height,
    textScale: textScale,
    textScaler: textScaler,
    locale: locale,
    disableAnimations: disableAnimations,
    devicePixelRatio: devicePixelRatio,
  );
  return bloc;
}

/// Mounts the real CalendarPage, as [pumpCalendarScene], on [bloc] (e.g. the
/// real CalendarBloc over controlled repositories).
Future<void> pumpCalendarWithBloc(
  WidgetTester tester,
  CalendarBloc bloc, {
  String? initialDate = '2026-10-15',
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
  double devicePixelRatio = 1.0,
}) async {
  await loadRedesignFonts();
  await sl.reset();
  openedRoutes.clear();
  sl.registerFactory<CalendarBloc>(() => bloc);
  tester.view.physicalSize = Size(width, height) * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget stub(GoRouterState routeState) {
    openedRoutes.add(routeState.uri.toString());
    return const Scaffold(body: SizedBox.shrink());
  }

  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (_, _) =>
            Scaffold(body: CalendarPage(initialDate: initialDate)),
      ),
      GoRoute(path: '/trainings', builder: (_, s) => stub(s)),
      GoRoute(path: '/diets', builder: (_, s) => stub(s)),
      GoRoute(path: '/challenges', builder: (_, s) => stub(s)),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(sl.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: themeFor(brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler ?? TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: app!,
        );
      },
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
