// Redesign L3, unit 1: Inicio in direction A «Sesión de hoy».
//
// Every test runs HomePage with the injectable clock (decision D10) fixed to
// Wednesday 18 Nov 2026 and a real HomeBloc over a fake repository, inside a
// GoRouter so navigation and reload-on-return are observed end to end.
import 'dart:async';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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
}) async {
  await initializeDateFormatting('es');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final preferences = AppPreferencesCubit(_PreferencesStorage());
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
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
    return decoration is BoxDecoration &&
        decoration.color == AppColors.primary;
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
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
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
      expect(find.text('Hoy no tienes entrenamiento asignado.'), findsOneWidget);
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

    testWidgets('week strip: labels, selection and day change', (
      tester,
    ) async {
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
              (widget.properties.label?.contains('$day de noviembre') ??
                  false),
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
              (widget.properties.label?.contains('$day de noviembre') ??
                  false),
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

      await tester.fling(find.text('PIERNA FUERZA'), const Offset(0, 400), 1000);
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

      await tester.fling(find.text('PIERNA FUERZA'), const Offset(0, 400), 1000);
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

      await tester.fling(find.text('PIERNA FUERZA'), const Offset(0, 400), 1000);
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
          theme: brightness == Brightness.dark
              ? AppTheme.dark
              : AppTheme.light,
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
}
