// Shared scene builders for the redesign L0 baseline (goldens and the
// accessibility guideline inventory). Test-only: nothing here touches lib/.
//
// Known limit of the primary-button goldens: the labels «COMPLETAR SERIE» and
// «SALTAR» render as boxes because active_exercise_page.dart:928-932 and
// :1234-1240 pass a textStyle without fontFamily, which replaces (does not
// merge) the theme style, so the label falls back to the test default font
// (Ahem). In production on Android it falls back to the system font instead of
// CabinetGrotesk. The fix belongs to lot L3; regenerate the goldens then.
//
// Every scene uses fixed fictitious data. The only clock-dependent code paths
// are noted per scene:
//  - Inicio: HomePage/WeekDaySelector read DateTime.now() directly (no
//    injectable clock), so it cannot be a stable golden; it is still pumped for
//    the accessibility inventory.
//  - Descanso: the rest footer counts down from DateTime.now(). The saved rest
//    ends exactly 90 s after "now", and the scene is captured without advancing
//    real time, so the visible value is 90 for any machine speed below 1 s.
import 'dart:io';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_previous_exercise_performances_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/unmark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

enum RedesignScene {
  inicio('inicio'),
  detalle('detalle'),
  ejercicioActivo('ejercicio_activo'),
  hojaSerie('hoja_serie'),
  descanso('descanso');

  const RedesignScene(this.slug);
  final String slug;
}

const _date = '2026-09-05';
const _trainingId = 'training-1';
const _exerciseKey = 'te-1';

const _bulgarian = TrainingExerciseEntity(
  id: _exerciseKey,
  order: 1,
  sets: 4,
  repsOrDuration: '8',
  targetRir: 2,
  restSeconds: 90,
  exercise: ExerciseEntity(
    id: 'ex-1',
    name: 'Sentadilla búlgara',
    muscleGroups: ['Cuádriceps', 'Glúteo'],
    techniqueText: 'Pie trasero apoyado en el banco, torso erguido.',
  ),
);

const _previous = [
  SetPerformance(setNumber: 1, reps: 8, weightKg: 60),
  SetPerformance(setNumber: 2, reps: 8, weightKg: 60),
  SetPerformance(setNumber: 3, reps: 8, weightKg: 60),
  SetPerformance(setNumber: 4, reps: 8, weightKg: 60),
];

const _fixtureTraining = TrainingEntity(
  id: _trainingId,
  name: 'Pierna fuerza',
  types: ['FUERZA'],
  level: 'INTERMEDIATE',
  estimatedDurationMin: 55,
  tags: [],
  exercises: [
    _bulgarian,
    TrainingExerciseEntity(
      id: 'te-2',
      order: 2,
      sets: 3,
      repsOrDuration: '10',
      targetRir: 2,
      restSeconds: 75,
      exercise: ExerciseEntity(
        id: 'ex-2',
        name: 'Peso muerto rumano',
        muscleGroups: ['Isquios', 'Glúteo'],
      ),
    ),
    TrainingExerciseEntity(
      id: 'te-3',
      order: 3,
      sets: 3,
      repsOrDuration: '12',
      targetRir: 1,
      restSeconds: 60,
      exercise: ExerciseEntity(
        id: 'ex-3',
        name: 'Elevación de gemelos',
        muscleGroups: ['Gemelos'],
      ),
    ),
  ],
);

class _SceneStorage extends LocalStorage {
  _SceneStorage({this.savedWorkout});

  final ActiveWorkoutHiveModel? savedWorkout;
  final _store = _SceneWorkoutStore();

  @override
  String? get sessionStamp => 'owner:1:test';
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => [];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(
    String trainingId,
    String date,
  ) => [];
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => [];
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId,
  ) => null;
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) => false;
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) => null;
  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(
    String trainingId,
    String exerciseId,
    String date,
  ) => null;
  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      ValueNotifier<Box<ActiveWorkoutHiveModel>>(_EmptyBox());
  @override
  List<ActiveWorkoutHiveModel> getForeignActiveWorkouts(String trainingId) =>
      [];
  @override
  bool getRestTimerSoundEnabled() => false;
  @override
  ActiveWorkoutLocalStore bindActiveWorkoutStore() {
    final saved = savedWorkout;
    if (saved != null) _store.seed(saved);
    return _store;
  }
}

class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _SceneWorkoutStore implements ActiveWorkoutLocalStore {
  final Map<String, ActiveWorkoutHiveModel> _data = {};
  void seed(ActiveWorkoutHiveModel workout) => _data[workout.exerciseId] = workout;
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      _data[exerciseId];
  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    _data[workout.exerciseId] = workout;
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    _data.remove(exerciseId);
  }
}

class _SceneRestCoordinator implements RestTimerCoordinator {
  @override
  RestTimerSession? activeSession;
  @override
  Future<void> start(RestTimerSession session) async => activeSession = session;
  @override
  Future<void> finish() async => activeSession = null;
  @override
  Future<void> cancel() async => activeSession = null;
}

class _SceneTrainingRepository extends Fake implements TrainingRepository {
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      _fixtureTraining;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      const TrainingDayProgress();
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => {_exerciseKey: _previous, 'ex-1': _previous};
}

class _SceneHomeRepository implements HomeRepository {
  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) async => const HomeSummaryEntity(
    trainingId: _trainingId,
    trainingName: 'Pierna fuerza',
    trainingTypes: ['FUERZA'],
    trainingDurationMin: 55,
    remainingTrainingDurationMin: 55,
    trainings: [
      HomeTrainingItemEntity(
        id: _trainingId,
        name: 'Pierna fuerza',
        completed: false,
      ),
    ],
    exercisesCompleted: 0,
    totalExercises: 3,
    dietName: 'Definición',
    nextMealName: 'Comida: arroz con pollo',
    totalCalories: 2200,
    remainingCalories: 1500,
    mealsCompleted: 2,
    totalMeals: 5,
    streakDays: 4,
    clientName: 'Lucía',
    lastWeightKg: 62.5,
    lastSleepHours: 7.5,
  );
}

class _ScenePreferencesStorage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.light;
  @override
  Locale? getLocalePreference() => const Locale('es');
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

/// Teardown callbacks registered by [pumpRedesignScene] for resources that the
/// caller must release after the widget tree is disposed.
class SceneHandle {
  SceneHandle._(this._cleanup);
  final Future<void> Function() _cleanup;
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _cleanup();
  }
}

Widget _app(ThemeData theme, double textScale, Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    darkTheme: theme,
    themeMode: theme.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      // Mirrors lib/main.dart: static GlassDecoration factories read the
      // active brightness. Without this the light scenes painted the dark
      // tokens (hidden while they were translucent; opaque since L1).
      GlassDecoration.brightness = Theme.of(context).brightness;
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: home,
  );
}

TrainingBloc _trainingBloc(TrainingRepository repository) => TrainingBloc(
  getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
  getTrainingsUseCase: GetTrainingsUseCase(repository),
  getTrainingUseCase: GetTrainingUseCase(repository),
  markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
  unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
  completeTrainingUseCase: CompleteTrainingUseCase(repository),
  getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
  getPreviousExercisePerformancesUseCase:
      GetPreviousExercisePerformancesUseCase(repository),
);

class _FakeTrainingBloc extends Fake implements TrainingBloc {}

bool _fontsLoaded = false;

/// Loads the bundled font families used by AppTheme (L1: DMSans by default,
/// BarlowCondensed for display/headline slots; CabinetGrotesk is still bundled
/// and kept loaded) and the SDK Material Icons so layouts are realistic instead
/// of Ahem boxes. Reads files from disk; pubspec.yaml is the source of the
/// family names. If the SDK icon font cannot be located the icons stay as Ahem
/// boxes.
Future<void> loadRedesignFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  const families = <String, String>{
    'CabinetGrotesk': 'CabinetGrotesk-',
    'DMSans': 'dm-sans-',
    'BarlowCondensed': 'barlow-condensed-',
  };
  final files = Directory('assets/fonts').listSync().whereType<File>().toList();
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (name.startsWith(family.value) && name.endsWith('.ttf')) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }
  final icons = _findMaterialIcons();
  if (icons != null) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

File? _findMaterialIcons() {
  final candidates = <Directory>[];
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) candidates.add(Directory(root));
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    candidates.add(dir);
    dir = dir.parent;
  }
  for (final candidate in candidates) {
    final fonts = Directory(
      '${candidate.path}/bin/cache/artifacts/material_fonts',
    );
    if (!fonts.existsSync()) continue;
    for (final file in fonts.listSync().whereType<File>()) {
      if (file.path.toLowerCase().endsWith('materialicons-regular.otf')) {
        return file;
      }
    }
  }
  return null;
}

/// Pumps [scene] on a 390x844 surface at devicePixelRatio 1.0.
Future<SceneHandle> pumpRedesignScene(
  WidgetTester tester,
  RedesignScene scene, {
  required ThemeData theme,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  await loadRedesignFonts();
  await initializeDateFormatting('es');
  await sl.reset();

  // Limit: the countdown shows 90 only if under 1 s of real time passes between
  // this seed and the build. Fake-async pumps do not advance DateTime.now, and
  // L0 allows no hook in lib/ to inject a clock.
  final restSeed = scene == RedesignScene.descanso
      ? ActiveWorkoutHiveModel(
          trainingId: _trainingId,
          exerciseId: '$_exerciseKey:$_date',
          currentSet: 2,
          completedSets: 1,
          restEndsAt: DateTime.now().add(const Duration(seconds: 90)),
          lastWeightKg: 60,
          completedSetData: const [
            {'set_number': 1, 'reps': 8, 'weight_kg': 60.0, 'rir': 2},
          ],
        )
      : null;
  final storage = _SceneStorage(savedWorkout: restSeed);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<RestTimerCoordinator>(_SceneRestCoordinator());
  sl.registerSingleton<ExecutionTimerCoordinator>(ExecutionTimerCoordinator());

  switch (scene) {
    case RedesignScene.inicio:
      final preferences = AppPreferencesCubit(_ScenePreferencesStorage());
      final bloc = HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(_SceneHomeRepository()),
      )..add(const HomeLoadRequested());
      // Closed by the test framework teardown: awaiting close() inside the
      // fake-async test body never completes for these blocs.
      addTearDown(bloc.close);
      addTearDown(preferences.close);
      await tester.pumpWidget(
        _app(
          theme,
          textScale,
          MultiBlocProvider(
            providers: [
              BlocProvider<AppPreferencesCubit>.value(value: preferences),
              BlocProvider<HomeBloc>.value(value: bloc),
            ],
            child: const Scaffold(body: HomePage()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    case RedesignScene.detalle:
      final repository = _SceneTrainingRepository();
      sl.registerFactory<TrainingBloc>(() => _trainingBloc(repository));
      await tester.pumpWidget(
        _app(
          theme,
          textScale,
          const TrainingDetailPage(
            trainingId: _trainingId,
            selectedDate: _date,
          ),
        ),
      );
      await tester.pumpAndSettle();
    case RedesignScene.ejercicioActivo ||
        RedesignScene.hojaSerie ||
        RedesignScene.descanso:
      await tester.pumpWidget(
        _app(
          theme,
          textScale,
          ActiveExercisePage(
            trainingId: _trainingId,
            exerciseId: _exerciseKey,
            args: ActiveExercisePageArgs(
              trainingBloc: _FakeTrainingBloc(),
              trainingExercise: _bulgarian,
              trainingName: 'Pierna fuerza',
              trainingTypes: const ['FUERZA'],
              accentColorHex: null,
              trainingLevel: 'INTERMEDIATE',
              initialWeightKg: 60,
              previousPerformances: _previous,
              assignmentDate: _date,
            ),
          ),
        ),
      );
      // Page bootstrap runs after the first frame and awaits the bloc.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      if (scene == RedesignScene.hojaSerie) {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
  }

  return SceneHandle._(() async {
    await sl.reset();
  });
}

ThemeData redesignTheme(Brightness brightness) =>
    brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
