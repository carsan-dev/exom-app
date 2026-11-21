// Redesign L3, unit 1: Inicio in direction A «Sesión de hoy».
//
// Every test runs HomePage with the injectable clock (decision D10) fixed to
// Wednesday 18 Nov 2026 and a real HomeBloc over a fake repository, inside a
// GoRouter so navigation and reload-on-return are observed end to end.
import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart';
import 'package:exom_app/features/home/presentation/widgets/home_session_photo.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

final _now = DateTime(2026, 11, 18, 9);
final _wednesday = DateTime(2026, 11, 18);

class _PreferencesStorage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => const Locale('es');
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

class _Repository implements HomeRepository {
  _Repository(this.summaryFor);

  HomeSummaryEntity Function(DateTime? date) summaryFor;
  final dates = <DateTime?>[];
  Completer<void>? gate;
  Object? error;

  int get loads => dates.length;

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

/// L4b: `/calendar/month` stand-in. [days] by `yyyy-mm-dd`; [error] makes
/// every month fail.
class _Calendar implements CalendarRepository {
  _Calendar(this.days, {this.error});

  final Map<String, CalendarDayEntity> days;
  final Object? error;
  final months = <String>[];

  static CalendarDayEntity day(
    String date, {
    bool training = true,
    bool done = false,
    bool rest = false,
  }) => CalendarDayEntity(
    date: DateTime.parse(date),
    hasTraining: training,
    hasDiet: false,
    isRestDay: rest,
    trainingCompleted: done,
    dietCompleted: false,
  );

  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) async {
    months.add('$year-$month');
    final failure = error;
    if (failure != null) throw failure;
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    return [
      for (final entry in days.entries)
        if (entry.key.startsWith(prefix)) entry.value,
    ];
  }

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) =>
      throw UnimplementedError();
}

const _training = HomeSummaryEntity(
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
  totalExercises: 3,
  dietId: 'diet-1',
  dietName: 'Definición',
  remainingCalories: 1500,
  mealsCompleted: 1,
  totalMeals: 4,
  streakDays: 12,
  lastWeightKg: 62.5,
  lastSleepHours: 7.5,
);

HomeSummaryEntity _summary({
  String? trainingId = 'training-1',
  String trainingName = 'Pierna fuerza',
  List<HomeTrainingItemEntity>? trainings,
  bool completed = false,
  int exercisesCompleted = 0,
  int? remaining = 55,
  String? dietId = 'diet-1',
  String? nextMealId,
  bool isRestDay = false,
  int? programWeek,
}) {
  return HomeSummaryEntity(
    trainingId: trainingId,
    trainingName: trainingId == null ? null : trainingName,
    trainingTypes: const ['FUERZA'],
    trainingDurationMin: trainingId == null ? null : 55,
    remainingTrainingDurationMin: trainingId == null ? null : remaining,
    trainingCompleted: completed,
    trainings:
        trainings ??
        (trainingId == null
            ? const []
            : [
                HomeTrainingItemEntity(
                  id: trainingId,
                  name: trainingName,
                  completed: completed,
                ),
              ]),
    exercisesCompleted: exercisesCompleted,
    totalExercises: trainingId == null ? 0 : 3,
    dietId: dietId,
    dietName: dietId == null ? null : 'Definición',
    nextMealId: nextMealId,
    remainingCalories: dietId == null ? null : 1500,
    mealsCompleted: 1,
    totalMeals: dietId == null ? 0 : 4,
    isRestDay: isRestDay,
    programWeek: programWeek,
    streakDays: 12,
    lastWeightKg: 62.5,
    lastSleepHours: 7.5,
  );
}

class _Harness {
  _Harness(this.repository, this.bloc, this.router);
  final _Repository repository;
  final HomeBloc bloc;
  final GoRouter router;
  Uri? opened;
}

Future<_Harness> _pumpHome(
  WidgetTester tester, {
  required _Repository repository,
  DateTime? date,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  ThemeData? theme,
  bool settle = true,
  Locale locale = const Locale('es'),
  _Calendar? calendar,
}) async {
  await initializeDateFormatting('es');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final preferences = AppPreferencesCubit(_PreferencesStorage());
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
    getMonthCalendarUseCase: calendar == null
        ? null
        : GetMonthCalendarUseCase(calendar),
  )..add(HomeLoadRequested(date: date ?? _wednesday));
  late final _Harness harness;
  Widget destination(String label, GoRouterState state) {
    harness.opened = state.uri;
    return Scaffold(body: Text(label));
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: HomePage(now: () => _now)),
      ),
      GoRoute(
        path: '/trainings/:id',
        builder: (_, state) => destination('Detalle', state),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, state) => destination('Calendario', state),
      ),
      GoRoute(
        path: '/diets',
        builder: (_, state) => destination('Dietas', state),
      ),
      GoRoute(
        path: '/challenges',
        builder: (_, state) => destination('Retos', state),
      ),
      GoRoute(
        path: '/profile/metrics',
        builder: (_, state) => destination('Métricas', state),
      ),
    ],
  );
  harness = _Harness(repository, bloc, router);
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
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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

/// Widgets painting the lime fill (the "next step" colour).
Finder _limeFills() => find.byWidgetPredicate((widget) {
  if (widget is DecoratedBox) {
    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.color == AppColors.primary;
  }
  if (widget is Material) return widget.color == AppColors.primary;
  if (widget is Container) return widget.color == AppColors.primary;
  return false;
});

void main() {
  group('day with a session today', () {
    testWidgets('session first: title, date line, facts, one lime action', (
      tester,
    ) async {
      await _pumpHome(tester, repository: _Repository((_) => _training));

      expect(find.text('PIERNA FUERZA'), findsOneWidget);
      expect(find.text('Miércoles 18 de noviembre'), findsOneWidget);
      expect(find.text('3 ejercicios · 55 min aprox.'), findsOneWidget);
      expect(find.byType(ExomPrimaryButton), findsOneWidget);
      expect(find.text('EMPEZAR SESIÓN'), findsOneWidget);
      expect(_limeFills(), findsOneWidget);
      // Quiet rows: diet, streak, weight, sleep.
      expect(find.text('Definición'), findsOneWidget);
      expect(
        find.text('1 de 4 comidas hechas · 1.500 kcal restantes'),
        findsOneWidget,
      );
      expect(find.text('Racha de 12 días'), findsOneWidget);
      // L3 review B-F4 (display only): Spanish decimal comma, as the detail.
      expect(find.text('Peso · 62,5 kg'), findsOneWidget);
      expect(find.text('Sueño · 7,5 horas'), findsOneWidget);
    });

    testWidgets('weight and sleep use the locale decimal separator', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
        locale: const Locale('en'),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      expect(find.text('${l10n.weight} · 62.5 kg'), findsOneWidget);
      expect(find.text('${l10n.sleep} · 7.5 ${l10n.hours}'), findsOneWidget);
      expect(find.textContaining('62,5'), findsNothing);
    });

    testWidgets('the title is uppercase on screen but read in its own case', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpHome(tester, repository: _Repository((_) => _training));
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
      // The session block merges the title into its tap node.
      expect(find.bySemanticsLabel(RegExp('Pierna fuerza')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('PIERNA FUERZA')), findsNothing);
      semantics.dispose();
    });

    testWidgets('start opens the session with its date and reloads on return', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
      );
      expect(harness.repository.loads, 1);

      await tester.tap(find.text('EMPEZAR SESIÓN'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);
      expect(harness.opened?.path, '/trainings/training-1');
      expect(harness.opened?.queryParameters['date'], '2026-11-18');
      expect(harness.repository.loads, 1);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.repository.loads, 2);
      expect(harness.repository.dates.last, _wednesday);
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
    });

    testWidgets('tapping the session block opens the same session', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
      );

      await tester.tap(find.text('PIERNA FUERZA'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/trainings/training-1');
      expect(harness.opened?.queryParameters['date'], '2026-11-18');

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.repository.loads, 2);
    });

    testWidgets('session in progress offers to continue', (tester) async {
      await _pumpHome(
        tester,
        repository: _Repository(
          (_) => _summary(exercisesCompleted: 1, remaining: 40),
        ),
      );

      expect(find.text('CONTINUAR SESIÓN'), findsOneWidget);
      expect(
        find.text('1 de 3 ejercicios · ≈ 40 min restantes'),
        findsOneWidget,
      );
      expect(_limeFills(), findsOneWidget);
    });

    testWidgets('session done: quiet status, no lime, secondary view', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository(
          (_) => _summary(completed: true, exercisesCompleted: 3),
        ),
      );

      expect(find.byType(ExomPrimaryButton), findsNothing);
      expect(_limeFills(), findsNothing);
      expect(find.text('Hecha'), findsOneWidget);
      expect(find.byIcon(ExomIcons.done), findsOneWidget);
      expect(find.text('3 ejercicios'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Miércoles 18 de noviembre, hoy, sesión hecha'),
        findsOneWidget,
      );

      await tester.tap(find.text('Ver entrenamiento'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/trainings/training-1');
      expect(harness.opened?.queryParameters['date'], '2026-11-18');
    });

    testWidgets('several sessions: first unfinished leads, others are rows', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository(
          (_) => _summary(
            exercisesCompleted: 2,
            remaining: 30,
            trainings: const [
              HomeTrainingItemEntity(
                id: 'training-1',
                name: 'Movilidad',
                completed: true,
              ),
              HomeTrainingItemEntity(
                id: 'training-2',
                name: 'Torso',
                completed: false,
              ),
            ],
          ),
        ),
      );

      expect(find.text('TORSO'), findsOneWidget);
      expect(find.text('Movilidad'), findsOneWidget);
      expect(find.text('Hecha'), findsOneWidget);
      expect(find.textContaining('2 sesiones'), findsOneWidget);
      // Exercise counts are aggregated over the day, so «continuar» is only
      // offered for a single session.
      expect(find.text('EMPEZAR SESIÓN'), findsOneWidget);

      await tester.tap(find.text('EMPEZAR SESIÓN'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/trainings/training-2');
      harness.router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Movilidad'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/trainings/training-1');
      expect(harness.opened?.queryParameters['date'], '2026-11-18');
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.repository.loads, 3);
    });
  });

  group('day without a training', () {
    testWidgets('rest day: DESCANSO, copy, calendar, no lime', (tester) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository(
          (_) => _summary(trainingId: null, dietId: null, isRestDay: true),
        ),
      );
      expect(harness.bloc.state, isA<HomeRestDay>());

      expect(find.text('DESCANSO'), findsOneWidget);
      expect(
        find.text('Hoy no tienes entrenamiento asignado.'),
        findsOneWidget,
      );
      expect(find.byType(ExomPrimaryButton), findsNothing);
      expect(_limeFills(), findsNothing);
      expect(find.text('Definición'), findsNothing);

      await tester.tap(find.text('Ver calendario'));
      await tester.pumpAndSettle();
      expect(find.text('Calendario'), findsOneWidget);
    });

    testWidgets('diet-only day keeps the diet row and opens the diet', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _summary(trainingId: null)),
      );
      expect(harness.bloc.state, isA<HomeLoaded>());

      expect(find.text('DESCANSO'), findsOneWidget);
      expect(find.byType(ExomPrimaryButton), findsNothing);
      expect(find.text('Definición'), findsOneWidget);

      await tester.tap(find.text('Definición'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/diets');
      expect(harness.opened?.queryParameters['date'], '2026-11-18');
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.repository.loads, 2);
    });
  });

  group('other days of the week', () {
    testWidgets('a past day shows the session without the lime start', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
        date: DateTime(2026, 11, 17),
      );

      expect(find.text('Ayer · Martes 17 de noviembre'), findsOneWidget);
      expect(find.byType(ExomPrimaryButton), findsNothing);
      expect(_limeFills(), findsNothing);

      await tester.tap(find.text('Ver entrenamiento'));
      await tester.pumpAndSettle();
      expect(harness.opened?.queryParameters['date'], '2026-11-17');
    });

    testWidgets('a future rest day uses the non-today copy', (tester) async {
      await _pumpHome(
        tester,
        repository: _Repository(
          (_) => _summary(trainingId: null, dietId: null, isRestDay: true),
        ),
        date: DateTime(2026, 11, 19),
      );

      expect(find.text('Mañana · Jueves 19 de noviembre'), findsOneWidget);
      expect(
        find.text('Este día no tienes entrenamiento asignado.'),
        findsOneWidget,
      );
    });

    testWidgets('week strip: labels, selection and day change', (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Miércoles 18 de noviembre, hoy'),
        ),
        matchesSemantics(
          label: 'Miércoles 18 de noviembre, hoy',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasEnabledState: false,
        ),
      );
      expect(find.bySemanticsLabel('Lunes 16 de noviembre'), findsOneWidget);
      expect(find.bySemanticsLabel('Domingo 22 de noviembre'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Jueves 19 de noviembre'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.repository.dates.last, DateTime(2026, 11, 19));
      expect(find.text('Mañana · Jueves 19 de noviembre'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('week strip slots meet the tap target guidelines', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpHome(tester, repository: _Repository((_) => _training));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final day in [16, 17, 18, 19, 20, 21, 22]) {
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('$day de noviembre') ?? false),
        );
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      semantics.dispose();
    });

    testWidgets('at 360 dp each slot is tappable across its full width', (
      tester,
    ) async {
      // L3 review B-F2: the 1 px inset used to sit outside the InkWell, so
      // the hit area was 2 px narrower than the slot (46 px at 360 dp).
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
        size: const Size(360, 800),
      );
      for (final day in [16, 17, 18, 19, 20, 21, 22]) {
        final slot = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('$day de noviembre') ?? false),
        );
        final slotRect = tester.getRect(slot);
        expect(slotRect.width, greaterThanOrEqualTo(48));
        expect(slotRect.height, greaterThanOrEqualTo(48));

        // Taps on the outermost columns of the slot select that day.
        for (final x in [slotRect.left + 0.5, slotRect.right - 0.5]) {
          harness.repository.dates.clear();
          await tester.tapAt(Offset(x, slotRect.center.dy));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(harness.repository.dates, [DateTime(2026, 11, day)]);
        }
      }
    });
  });

  group('loading, error and refresh', () {
    testWidgets('loading shows the skeleton without actions', (tester) async {
      final repository = _Repository((_) => _training)..gate = Completer();
      await _pumpHome(tester, repository: repository, settle: false);
      await tester.pump();

      expect(find.byType(ShimmerCard), findsWidgets);
      expect(find.byType(ExomPrimaryButton), findsNothing);

      repository.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
    });

    testWidgets('error offers retry that reloads', (tester) async {
      final repository = _Repository((_) => _training)
        ..error = Exception('boom');
      await _pumpHome(tester, repository: repository);

      expect(find.byType(ErrorWidget2), findsOneWidget);
      repository.error = null;
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.loads, 2);
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
    });

    testWidgets('pull to refresh stays open until the reload lands', (
      tester,
    ) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
      );
      harness.repository.gate = Completer();

      await tester.fling(
        find.text('PIERNA FUERZA'),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(harness.repository.loads, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      harness.repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
    });

    testWidgets('a failed pull to refresh ends at once, says so and keeps '
        'the data on screen', (tester) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
      );
      harness.repository.error = Exception('boom');

      await tester.fling(
        find.text('PIERNA FUERZA'),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(harness.repository.loads, 2);
      // Well under HomePage.refreshTimeout: the failure ends the wait.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(
        find.text('No se pudo cargar el resumen. Vuelve a intentarlo.'),
        findsOneWidget,
      );
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
      expect(find.byType(ErrorWidget2), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('pull to refresh gives up after the timeout', (tester) async {
      final harness = await _pumpHome(
        tester,
        repository: _Repository((_) => _training),
      );
      final gate = Completer<void>();
      harness.repository.gate = gate;

      await tester.fling(
        find.text('PIERNA FUERZA'),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      await tester.pump(HomePage.refreshTimeout);
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('large text on a narrow screen', () {
    for (final brightness in Brightness.values) {
      testWidgets('320 dp at 1.6x, ${brightness.name}: nothing clipped', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          repository: _Repository(
            (_) => _summary(
              trainingName: 'Pierna y glúteo con cadena posterior',
              nextMealId: null,
            ),
          ),
          size: const Size(320, 640),
          textScale: 1.6,
          theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        );
        expect(tester.takeException(), isNull);

        // The pinned action stays reachable inside the screen.
        final action = find.text('EMPEZAR SESIÓN').hitTestable();
        expect(action, findsOneWidget);
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(640));

        // Scrolling the content to the end builds every row without overflow.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // L3 review B-F4 (display only): decimal comma in Spanish.
        expect(find.text('Sueño · 7,5 horas'), findsOneWidget);
        expect(find.text('EMPEZAR SESIÓN').hitTestable(), findsOneWidget);
      });
    }
  });

  testWidgets('L3b P5c: at 320x568 and 2.0x the pinned action is bounded and '
      'the content stays reachable', (tester) async {
    await _pumpHome(
      tester,
      repository: _Repository(
        (_) => _summary(
          trainingName: 'Pierna y glúteo con cadena posterior',
          nextMealId: null,
        ),
      ),
      size: const Size(320, 568),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);

    final footer = tester.getRect(find.byType(HomeSessionAction));
    expect(footer.height, lessThanOrEqualTo(568 * 0.4 + 0.5));
    expect(find.text('EMPEZAR SESIÓN').hitTestable(), findsOneWidget);
    expect(find.text('PIERNA Y GLÚTEO CON CADENA POSTERIOR'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Sueño'), findsWidgets);
  });

  group('L4b', () {
    HomeSummaryEntity l4b({
      int? week,
      int? day,
      int totalExercises = 6,
      int totalSets = 0,
      String? photo,
      List<HomeTrainingItemEntity>? trainings,
      bool completed = false,
      String name = 'Pierna fuerza',
    }) => HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: name,
      trainingTypes: const ['FUERZA'],
      trainingDurationMin: 55,
      remainingTrainingDurationMin: 55,
      trainingCompleted: completed,
      trainings:
          trainings ??
          [
            HomeTrainingItemEntity(
              id: 'training-1',
              name: name,
              completed: completed,
              thumbnailUrl: photo,
            ),
          ],
      exercisesCompleted: completed ? totalExercises : 0,
      totalExercises: totalExercises,
      totalSets: totalSets,
      programWeek: week,
      programDay: day,
      trainingThumbnailUrl: photo,
      dietId: 'diet-1',
      dietName: 'Definición',
      remainingCalories: 1500,
      mealsCompleted: 1,
      totalMeals: 4,
      streakDays: 12,
      lastWeightKg: 62.5,
      lastSleepHours: 7.5,
    );

    group('program week in the date line', () {
      testWidgets('week and day', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(week: 3, day: 2)),
        );
        expect(
          find.text('Miércoles 18 de noviembre · semana 3, día 2'),
          findsOneWidget,
        );
      });

      testWidgets('week only', (tester) async {
        await _pumpHome(tester, repository: _Repository((_) => l4b(week: 3)));
        expect(
          find.text('Miércoles 18 de noviembre · semana 3'),
          findsOneWidget,
        );
      });

      testWidgets('a day without a week shows the date alone', (tester) async {
        await _pumpHome(tester, repository: _Repository((_) => l4b(day: 2)));
        expect(find.text('Miércoles 18 de noviembre'), findsOneWidget);
      });

      testWidgets('no week shows the date alone', (tester) async {
        await _pumpHome(tester, repository: _Repository((_) => l4b()));
        expect(find.text('Miércoles 18 de noviembre'), findsOneWidget);
      });

      testWidgets('another day keeps its relative label first', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(week: 3, day: 1)),
          date: DateTime(2026, 11, 17),
        );
        expect(
          find.text('Ayer · Martes 17 de noviembre · semana 3, día 1'),
          findsOneWidget,
        );
      });

      testWidgets('English', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(week: 3, day: 2)),
          locale: const Locale('en'),
        );
        expect(
          find.text('Wednesday November 18 · week 3, day 2'),
          findsOneWidget,
        );
      });

      testWidgets('English, week only', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(week: 3)),
          locale: const Locale('en'),
        );
        expect(find.text('Wednesday November 18 · week 3'), findsOneWidget);
      });
    });

    group('program week on a rest day', () {
      HomeSummaryEntity rest({int? week}) => _summary(
        trainingId: null,
        dietId: null,
        isRestDay: true,
        programWeek: week,
      );

      testWidgets('date line carries the week, without a day', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(tester, repository: _Repository((_) => rest(week: 3)));
        expect(find.text('DESCANSO'), findsOneWidget);
        expect(
          find.text('Miércoles 18 de noviembre · semana 3'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('Miércoles 18 de noviembre · semana 3')),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('another rest day keeps its relative label', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => rest(week: 3)),
          date: DateTime(2026, 11, 17),
        );
        expect(
          find.text('Ayer · Martes 17 de noviembre · semana 3'),
          findsOneWidget,
        );
      });

      testWidgets('English', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => rest(week: 3)),
          locale: const Locale('en'),
        );
        expect(find.text('Wednesday November 18 · week 3'), findsOneWidget);
      });

      testWidgets('no week shows the date alone', (tester) async {
        await _pumpHome(tester, repository: _Repository((_) => rest()));
        expect(find.text('Miércoles 18 de noviembre'), findsOneWidget);
      });
    });

    group('fact line with total sets', () {
      testWidgets('exercises, sets and minutes', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(totalSets: 22)),
        );
        expect(
          find.text('6 ejercicios · 22 series · 55 min aprox.'),
          findsOneWidget,
        );
      });

      testWidgets('one set uses the singular', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(totalExercises: 1, totalSets: 1)),
        );
        expect(
          find.text('1 ejercicio · 1 serie · 55 min aprox.'),
          findsOneWidget,
        );
      });

      testWidgets('without sets the piece is omitted', (tester) async {
        await _pumpHome(tester, repository: _Repository((_) => l4b()));
        expect(find.text('6 ejercicios · 55 min aprox.'), findsOneWidget);
      });

      testWidgets('English', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(totalSets: 22)),
          locale: const Locale('en'),
        );
        expect(
          find.text('6 exercises · 22 sets · About 55 min'),
          findsOneWidget,
        );
      });

      testWidgets('session done: exercises and sets, no minutes', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(totalSets: 22, completed: true)),
        );
        expect(find.text('6 ejercicios · 22 series'), findsOneWidget);
      });
    });

    group('session photo', () {
      const url = 'https://cdn.exom.test/hero.jpg';

      testWidgets('with a thumbnail: decorative, between date and facts', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(totalSets: 22, photo: url)),
        );
        final photo = find.byType(HomeSessionPhoto);
        expect(photo, findsOneWidget);
        final image = tester.widget<CachedNetworkImage>(
          find.descendant(of: photo, matching: find.byType(CachedNetworkImage)),
        );
        expect(image.imageUrl, url);
        expect(image.memCacheWidth, isNotNull);
        expect(
          find.descendant(of: photo, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
        final dateLine = tester.getRect(find.text('Miércoles 18 de noviembre'));
        final facts = tester.getRect(
          find.text('6 ejercicios · 22 series · 55 min aprox.'),
        );
        final photoRect = tester.getRect(photo);
        expect(photoRect.top, greaterThanOrEqualTo(dateLine.bottom));
        expect(photoRect.bottom, lessThanOrEqualTo(facts.top));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('without a thumbnail there is no photo', (tester) async {
        await _pumpHome(tester, repository: _Repository((_) => l4b()));
        expect(find.byType(HomeSessionPhoto), findsNothing);
        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('the photo is the one of the hero session', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository(
            (_) => l4b(
              trainings: const [
                HomeTrainingItemEntity(
                  id: 'training-1',
                  name: 'Movilidad',
                  completed: true,
                  thumbnailUrl: 'https://cdn.exom.test/movilidad.jpg',
                ),
                HomeTrainingItemEntity(
                  id: 'training-2',
                  name: 'Torso',
                  completed: false,
                  thumbnailUrl: 'https://cdn.exom.test/torso.jpg',
                ),
              ],
            ),
          ),
        );
        expect(find.text('TORSO'), findsOneWidget);
        expect(
          tester
              .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .imageUrl,
          'https://cdn.exom.test/torso.jpg',
        );
      });

      testWidgets('a hero without a thumbnail shows none', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository(
            (_) => l4b(
              trainings: const [
                HomeTrainingItemEntity(
                  id: 'training-1',
                  name: 'Movilidad',
                  completed: true,
                  thumbnailUrl: 'https://cdn.exom.test/movilidad.jpg',
                ),
                HomeTrainingItemEntity(
                  id: 'training-2',
                  name: 'Torso',
                  completed: false,
                ),
              ],
            ),
          ),
        );
        expect(find.byType(HomeSessionPhoto), findsNothing);
      });

      Future<void> pumpBuilt(
        WidgetTester tester,
        Widget Function(BuildContext context) build,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(builder: build),
                  const Text('after'),
                ],
              ),
            ),
          ),
        );
      }

      CachedNetworkImage imageOf(WidgetTester tester) =>
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

      testWidgets('loading: a raised box of the same size, no spinner', (
        tester,
      ) async {
        await pumpBuilt(tester, (_) => const HomeSessionPhoto(url: url));
        final image = imageOf(tester);
        await pumpBuilt(tester, (context) => image.placeholder!(context, url));
        final box = find.byKey(HomeSessionPhoto.placeholderKey);
        expect(tester.getSize(box), const Size(390, HomeSessionPhoto.height));
        final context = tester.element(box);
        expect(
          tester.widget<ColoredBox>(box).color,
          context.exomPalette.surfaceElevated,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('loaded: 200 high, full width, cover', (tester) async {
        await pumpBuilt(tester, (_) => const HomeSessionPhoto(url: url));
        final image = imageOf(tester);
        await pumpBuilt(
          tester,
          (context) => image.imageBuilder!(context, MemoryImage(_onePixelPng)),
        );
        final picture = find.byKey(HomeSessionPhoto.imageKey);
        expect(
          tester.getSize(picture),
          const Size(390, HomeSessionPhoto.height),
        );
        expect(tester.widget<Image>(picture).fit, BoxFit.cover);
      });

      testWidgets('on Inicio the photo bleeds edge to edge, square', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(photo: url)),
        );
        final photo = find.byType(HomeSessionPhoto);
        final rect = tester.getRect(photo);
        expect(rect.left, 0);
        expect(rect.width, 390);
        expect(rect.height, HomeSessionPhoto.height + ExomSpacing.lg);
        expect(
          find.descendant(of: photo, matching: find.byType(ClipRRect)),
          findsNothing,
        );
        // The rest of the block keeps its 20 dp margin.
        expect(tester.getTopLeft(find.text('PIERNA FUERZA')).dx, 20);
        expect(
          tester.getTopLeft(find.text('6 ejercicios · 55 min aprox.')).dx,
          20,
        );
      });

      testWidgets('loaded photo is square and as wide as the screen', (
        tester,
      ) async {
        await pumpBuilt(tester, (_) => const HomeSessionPhoto(url: url));
        final image = imageOf(tester);
        await pumpBuilt(
          tester,
          (context) => image.imageBuilder!(context, MemoryImage(_onePixelPng)),
        );
        final picture = find.byKey(HomeSessionPhoto.imageKey);
        expect(tester.getSize(picture).width, 390);
        expect(tester.getTopLeft(picture).dx, 0);
        expect(find.byType(ClipRRect), findsNothing);
      });

      testWidgets('load error or expired URL: no gap and no exception', (
        tester,
      ) async {
        await pumpBuilt(tester, (_) => const HomeSessionPhoto(url: url));
        final image = imageOf(tester);
        await pumpBuilt(
          tester,
          (context) => image.errorWidget!(context, url, Exception('403')),
        );
        // Nothing above the next widget: the slot and its gap collapse.
        expect(tester.getTopLeft(find.text('after')).dy, 0);
        expect(find.byType(Icon), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('week strip marks', () {
      Finder mark(String kind, int day) =>
          find.byKey(ValueKey('home-week-mark-$kind-$day'));

      testWidgets('dot for pending, check for done, nothing otherwise', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final calendar = _Calendar({
          '2026-11-16': _Calendar.day('2026-11-16', done: true),
          '2026-11-18': _Calendar.day('2026-11-18'),
          '2026-11-20': _Calendar.day('2026-11-20'),
          '2026-11-21': _Calendar.day(
            '2026-11-21',
            training: false,
            rest: true,
          ),
        });
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b()),
          calendar: calendar,
        );
        expect(calendar.months, ['2026-11']);

        expect(mark('done', 16), findsOneWidget);
        final check = tester.widget<Icon>(mark('done', 16));
        expect(check.icon, ExomIcons.check);
        expect(check.size, 12);

        expect(mark('pending', 20), findsOneWidget);
        expect(tester.getSize(mark('pending', 20)), const Size(6, 6));
        final palette = tester.element(mark('pending', 20)).exomPalette;
        final dot = tester.widget<DecoratedBox>(
          find.descendant(
            of: mark('pending', 20),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect((dot.decoration as BoxDecoration).color, palette.textSecondary);
        // Today, selected: pending from its own summary.
        expect(mark('pending', 18), findsOneWidget);
        for (final day in [17, 19, 21, 22]) {
          expect(mark('pending', day), findsNothing);
          expect(mark('done', day), findsNothing);
        }

        expect(
          find.bySemanticsLabel('Lunes 16 de noviembre, sesión hecha'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Viernes 20 de noviembre, sesión pendiente'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Miércoles 18 de noviembre, hoy, sesión pendiente',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Martes 17 de noviembre'), findsOneWidget);
        expect(find.bySemanticsLabel('Sábado 21 de noviembre'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('a past day with a session not done is a hollow ring', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b()),
          calendar: _Calendar({
            '2026-11-16': _Calendar.day('2026-11-16'),
            '2026-11-17': _Calendar.day('2026-11-17', done: true),
            '2026-11-20': _Calendar.day('2026-11-20'),
          }),
        );
        expect(mark('missed', 16), findsOneWidget);
        expect(mark('pending', 16), findsNothing);
        expect(tester.getSize(mark('missed', 16)), const Size(6, 6));
        final palette = tester.element(mark('missed', 16)).exomPalette;
        final ring =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: mark('missed', 16),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(ring.shape, BoxShape.circle);
        expect(ring.color, isNull);
        expect(ring.border, isNotNull);
        expect(ring.border!.top.color, palette.textPrimary);

        // Done stays a check; today/future pending stays a filled dot.
        expect(mark('done', 17), findsOneWidget);
        expect(mark('missed', 17), findsNothing);
        expect(mark('pending', 18), findsOneWidget);
        expect(mark('pending', 20), findsOneWidget);
        expect(mark('missed', 18), findsNothing);
        expect(mark('missed', 20), findsNothing);
        // Days without a session carry no mark at all.
        expect(mark('missed', 19), findsNothing);
        expect(mark('pending', 19), findsNothing);

        expect(
          find.bySemanticsLabel('Lunes 16 de noviembre, sesión no hecha'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Viernes 20 de noviembre, sesión pendiente'),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('the ring reads on the selected (dark) day', (tester) async {
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b()),
          calendar: _Calendar({'2026-11-16': _Calendar.day('2026-11-16')}),
        );
        await tester.tap(find.bySemanticsLabel(RegExp('Lunes 16')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(mark('missed', 16), findsOneWidget);
        final palette = tester.element(mark('missed', 16)).exomPalette;
        final ring =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: mark('missed', 16),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(ring.border!.top.color, palette.background);
      });

      testWidgets('English missed label', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b()),
          locale: const Locale('en'),
          calendar: _Calendar({'2026-11-16': _Calendar.day('2026-11-16')}),
        );
        expect(
          find.bySemanticsLabel('Monday November 16, session not done'),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('English labels', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b()),
          locale: const Locale('en'),
          calendar: _Calendar({
            '2026-11-16': _Calendar.day('2026-11-16', done: true),
            '2026-11-20': _Calendar.day('2026-11-20'),
          }),
        );
        expect(
          find.bySemanticsLabel('Monday November 16, session done'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Friday November 20, session pending'),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('today uses the local state over the calendar', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(completed: true)),
          calendar: _Calendar({'2026-11-18': _Calendar.day('2026-11-18')}),
        );
        expect(mark('done', 18), findsOneWidget);
        expect(mark('pending', 18), findsNothing);
        expect(
          find.bySemanticsLabel('Miércoles 18 de noviembre, hoy, sesión hecha'),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('changing day in the week does not ask the calendar again', (
        tester,
      ) async {
        final calendar = _Calendar({
          '2026-11-16': _Calendar.day('2026-11-16', done: true),
        });
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b()),
          calendar: calendar,
        );
        await tester.tap(find.bySemanticsLabel(RegExp('Jueves 19')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(calendar.months, ['2026-11']);
        expect(mark('done', 16), findsOneWidget);
      });

      testWidgets('calendar failure: the strip stays as before', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pumpHome(
          tester,
          repository: _Repository((_) => l4b(completed: true)),
          calendar: _Calendar(const {}, error: Exception('boom')),
        );
        expect(find.byType(ErrorWidget2), findsNothing);
        expect(find.text('PIERNA FUERZA'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'home-week-mark-',
                ),
          ),
          findsNothing,
        );
        // Pre-L4b behaviour: only the selected, finished day has a check.
        expect(
          find.bySemanticsLabel('Miércoles 18 de noviembre, hoy, sesión hecha'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Lunes 16 de noviembre'), findsOneWidget);
        semantics.dispose();
      });
    });

    group('320 dp with large text', () {
      for (final locale in const [Locale('es'), Locale('en')]) {
        for (final scale in const [1.3, 1.6]) {
          testWidgets('${locale.languageCode} at ${scale}x: nothing clipped', (
            tester,
          ) async {
            await _pumpHome(
              tester,
              repository: _Repository(
                (_) => l4b(
                  week: 12,
                  day: 3,
                  totalSets: 22,
                  photo: 'https://cdn.exom.test/hero.jpg',
                  name: 'Pierna y glúteo con cadena posterior',
                ),
              ),
              date: DateTime(2026, 11, 19),
              size: const Size(320, 640),
              textScale: scale,
              locale: locale,
              calendar: _Calendar({
                '2026-11-16': _Calendar.day('2026-11-16', done: true),
                '2026-11-19': _Calendar.day('2026-11-19'),
                '2026-11-20': _Calendar.day('2026-11-20'),
              }),
            );
            expect(tester.takeException(), isNull);

            final expected = locale.languageCode == 'es'
                ? 'Mañana · Jueves 19 de noviembre · semana 12, día 3'
                : 'Tomorrow · Thursday November 19 · week 12, day 3';
            final line = find.text(expected);
            expect(line, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(line);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              tester.widget<Text>(line).overflow,
              isNot(TextOverflow.ellipsis),
            );
            expect(tester.getRect(line).right, lessThanOrEqualTo(320));

            final facts = find.text(
              locale.languageCode == 'es'
                  ? '6 ejercicios · 22 series · 55 min aprox.'
                  : '6 exercises · 22 sets · About 55 min',
            );
            expect(facts, findsOneWidget);
            expect(
              tester.renderObject<RenderParagraph>(facts).didExceedMaxLines,
              isFalse,
            );

            await tester.drag(find.byType(ListView), const Offset(0, -2000));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    });
  });
}

/// A valid 1x1 transparent PNG.
final _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
