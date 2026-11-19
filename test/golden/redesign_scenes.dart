// Shared scene builders for the redesign L0 baseline (goldens and the
// accessibility guideline inventory). Test-only: nothing here touches lib/.
//
// L0 found the labels «COMPLETAR SERIE» and «SALTAR» rendered as boxes (a
// textStyle without fontFamily). L3 unit 3 replaced both buttons with the
// ExomPrimaryButton / ExomSecondaryButton / ExomQuietButton components, which
// set the DM Sans family explicitly; the goldens were regenerated then.
//
// Every scene uses fixed fictitious data. The only clock-dependent code paths
// are noted per scene:
//  - Inicio and Inicio descanso: since L3 (decision D10) HomePage takes an
//    injectable clock; the scenes fix it to Wednesday 18 Nov 2026 and load the
//    HomeBloc for that date, so they are stable goldens.
//  - Descanso: the rest footer counts down from DateTime.now(). The saved rest
//    ends exactly 90 s after "now", and the scene is captured without advancing
//    real time, so the visible value is 90 for any machine speed below 1 s.
//  - Descanso circuito (L3 unit 4): same rule with a round rest that ends 60 s
//    after "now" («1:00»).
import 'dart:io';

import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
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
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

enum RedesignScene {
  inicio('inicio'),
  inicioDescanso('inicio_descanso'),
  detalle('detalle'),
  detalleEnCurso('detalle_en_curso'),
  detalleHecho('detalle_hecho'),
  ejercicioActivo('ejercicio_activo'),
  hojaSerie('hoja_serie'),
  descanso('descanso'),

  /// L3 unit 3: the set sheet after saving «62,5,5» (D3 field error).
  hojaSerieError('hoja_serie_error'),

  /// L3 unit 3: the rest after one «+30 s» (D7).
  descansoMas30('descanso_mas_30'),

  /// L3 unit 4: active circuit, second exercise of round 2.
  circuitoActivo('circuito_activo'),

  /// L3 unit 4: the shared set sheet opened from the circuit.
  hojaCircuito('hoja_circuito'),

  /// L3 unit 4: round rest after round 1.
  descansoCircuito('descanso_circuito'),

  /// L3 unit 4: every round logged, «Terminar circuito».
  circuitoListo('circuito_listo');

  const RedesignScene(this.slug);
  final String slug;
}

const _date = '2026-09-05';

/// Fixed clock of the Inicio scenes: Wednesday 18 November 2026, 09:00.
final inicioSceneNow = DateTime(2026, 11, 18, 9);

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

/// Execution of the in-progress / done detail scenes (L3).
const _sceneExecution = 'execution-1';

/// Detail «en curso» (L3): te-1 completed and acknowledged (no queue action),
/// te-2 completed with its completion still queued, te-3 with one set saved
/// only on this phone.
final _inProgressActions = <Map<String, dynamic>>[
  {
    'id': 'op-te-2',
    'type': 'mark_exercise_completed',
    'date': _date,
    'training_exercise_id': 'te-2',
    'exercise_id': 'ex-2',
    'training_id': _trainingId,
    'training_session_id': _sceneExecution,
    'status': 'queued',
  },
];

class _SceneStorage extends LocalStorage {
  _SceneStorage({
    this.savedWorkout,
    this.pendingActions = const [],
    this.executions = const [],
    this.drafts = const {},
  });

  final ActiveWorkoutHiveModel? savedWorkout;
  final List<Map<String, dynamic>> pendingActions;
  final List<Map<String, dynamic>> executions;
  final Map<String, ActiveWorkoutHiveModel> drafts;
  final _store = _SceneWorkoutStore();

  /// L3 unit 4: state of the active circuit scenes (active_circuit keys
  /// only; every other key keeps the base behaviour).
  Map<String, dynamic>? circuitState;

  @override
  Map<String, dynamic>? getCachedMap(String key) =>
      key.startsWith('active_circuit:') ? circuitState : super.getCachedMap(key);

  @override
  Future<void> cacheData(String key, dynamic value) async {
    if (key.startsWith('active_circuit:')) {
      circuitState = Map<String, dynamic>.from(value as Map);
      return;
    }
    await super.cacheData(key, value);
  }

  @override
  String? get sessionStamp => 'owner:1:test';
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [...pendingActions];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => [...executions];
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
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      drafts[exerciseId];
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

class _SceneAuth extends Fake implements FirebaseAuthService {
  @override
  User? get currentUser => null;
}

class _SceneFeedbackQueue extends Fake implements FeedbackUploadQueueService {
  @override
  Stream<FeedbackUploadNotice> get notices => const Stream.empty();
  @override
  String? statusOf(String id) => null;
}

/// L3 unit 4 circuit: three members, three rounds, 60 s between rounds.
const _circuitBlock = 'block-1';

const _circuitExercises = [
  TrainingExerciseEntity(
    id: 'tc-1',
    order: 4,
    sets: 3,
    repsOrDuration: '12',
    measureType: ExerciseMeasureType.reps,
    targetValue: 12,
    targetRir: 2,
    restSeconds: 30,
    blockId: _circuitBlock,
    exercise: ExerciseEntity(
      id: 'exc-1',
      name: 'Burpees',
      muscleGroups: [],
      techniqueText: 'Pecho al suelo y salto con palmada arriba.',
    ),
  ),
  TrainingExerciseEntity(
    id: 'tc-2',
    order: 5,
    sets: 3,
    repsOrDuration: '15',
    measureType: ExerciseMeasureType.reps,
    targetValue: 15,
    targetRir: 1,
    restSeconds: 30,
    blockId: _circuitBlock,
    exercise: ExerciseEntity(
      id: 'exc-2',
      name: 'Sentadilla goblet',
      muscleGroups: [],
      techniqueText: 'Mancuerna pegada al pecho, codos por dentro.',
    ),
  ),
  TrainingExerciseEntity(
    id: 'tc-3',
    order: 6,
    sets: 3,
    repsOrDuration: '10',
    measureType: ExerciseMeasureType.reps,
    targetValue: 10,
    restSeconds: 0,
    blockId: _circuitBlock,
    exercise: ExerciseEntity(
      id: 'exc-3',
      name: 'Remo con mancuerna',
      muscleGroups: [],
    ),
  ),
];

Map<String, dynamic> _circuitSceneState(RedesignScene scene) {
  const round1 = <String, Map<String, Object>>{
    'tc-1': {'set_number': 1, 'reps': 12},
    'tc-2': {'set_number': 1, 'reps': 15, 'weight_kg': 16.0, 'rir': 1},
    'tc-3': {'set_number': 1, 'reps': 10, 'weight_kg': 20.0},
  };
  return switch (scene) {
    RedesignScene.descansoCircuito => {
      'training_session_id': null,
      'round': 1,
      'exercise_index': 2,
      'status': 'roundResting',
      'rest_ends_at': DateTime.now()
          .add(const Duration(seconds: 60))
          .toIso8601String(),
      'ready_to_finish': false,
      'performances': {
        for (final entry in round1.entries) entry.key: [entry.value],
      },
    },
    RedesignScene.circuitoListo => {
      'training_session_id': null,
      'round': 3,
      'exercise_index': 2,
      'status': 'executing',
      'rest_ends_at': null,
      'ready_to_finish': true,
      'performances': {
        for (final entry in round1.entries)
          entry.key: [
            for (var round = 1; round <= 3; round++)
              {...entry.value, 'set_number': round},
          ],
      },
    },
    _ => {
      'training_session_id': null,
      'round': 2,
      'exercise_index': 1,
      'status': 'executing',
      'rest_ends_at': null,
      'ready_to_finish': false,
      'performances': {
        'tc-1': [
          round1['tc-1']!,
          {'set_number': 2, 'reps': 11},
        ],
        'tc-2': [round1['tc-2']!],
        'tc-3': [round1['tc-3']!],
      },
    },
  };
}

class _SceneTrainingRepository extends Fake implements TrainingRepository {
  _SceneTrainingRepository({this.completedIds = const {}});

  /// Exercises completed in [_sceneExecution] (L3 detail scenes).
  final Set<String> completedIds;

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      _fixtureTraining;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async {
    if (completedIds.isEmpty) return const TrainingDayProgress();
    final session = TrainingDayProgress(
      ids: completedIds,
      weights: {
        for (final id in completedIds) id: id == _exerciseKey ? 62.5 : 70,
      },
      performances: {
        for (final id in completedIds)
          id: [
            for (var set = 1; set <= (id == _exerciseKey ? 4 : 3); set++)
              SetPerformance(
                setNumber: set,
                reps: id == _exerciseKey ? 8 : 10,
                weightKg: id == _exerciseKey ? 62.5 : 70,
              ),
          ],
      },
    );
    return TrainingDayProgress(
      sessions: {_sceneExecution: session},
      sessionTrainings: const {_sceneExecution: _trainingId},
    );
  }
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => {_exerciseKey: _previous, 'ex-1': _previous};
}

class _SceneHomeRepository implements HomeRepository {
  _SceneHomeRepository({required this.restDay});

  /// Day with a diet and no training (sketch «Día sin asignación»).
  final bool restDay;

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) async => restDay
      ? const HomeSummaryEntity(
          dietId: 'diet-1',
          dietName: 'Definición',
          nextMealId: 'meal-1',
          nextMealName: 'Desayuno: avena con yogur',
          totalCalories: 2150,
          remainingCalories: 2150,
          mealsCompleted: 0,
          totalMeals: 4,
          streakDays: 12,
          clientName: 'Lucía',
          lastWeightKg: 62.5,
          lastSleepHours: 7.5,
        )
      : const HomeSummaryEntity(
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
          dietId: 'diet-1',
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

/// Only the state is read by the active exercise («Ejercicio 1 de 3»).
class _FakeTrainingBloc extends Fake implements TrainingBloc {
  @override
  TrainingState get state =>
      const TrainingDetailLoaded(_fixtureTraining, selectedDate: _date);
}

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
  final restSeed =
      scene == RedesignScene.descanso || scene == RedesignScene.descansoMas30
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
  final detailProgress = switch (scene) {
    RedesignScene.detalleEnCurso => const {_exerciseKey, 'te-2'},
    RedesignScene.detalleHecho => const {_exerciseKey, 'te-2', 'te-3'},
    _ => const <String>{},
  };
  final storage = _SceneStorage(
    savedWorkout: restSeed,
    pendingActions: scene == RedesignScene.detalleEnCurso
        ? _inProgressActions
        : const [],
    executions: detailProgress.isEmpty
        ? const []
        : const [
            {
              'id': _sceneExecution,
              'training_id': _trainingId,
              'assignment_date': _date,
              'status': 'pending',
            },
          ],
    drafts: scene == RedesignScene.detalleEnCurso
        ? {
            'te-3:$_date:$_sceneExecution': ActiveWorkoutHiveModel(
              trainingId: _trainingId,
              exerciseId: 'te-3:$_date:$_sceneExecution',
              currentSet: 2,
              completedSets: 1,
              lastWeightKg: 20,
              completedSetData: const [
                {'set_number': 1, 'reps': 12, 'weight_kg': 20.0},
              ],
            ),
          }
        : const {},
  );
  final circuitScene = switch (scene) {
    RedesignScene.circuitoActivo ||
    RedesignScene.hojaCircuito ||
    RedesignScene.descansoCircuito ||
    RedesignScene.circuitoListo => true,
    _ => false,
  };
  if (circuitScene) {
    storage.circuitState = _circuitSceneState(scene);
    sl.registerSingleton<FirebaseAuthService>(_SceneAuth());
    sl.registerSingleton<FeedbackUploadQueueService>(_SceneFeedbackQueue());
  }
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<RestTimerCoordinator>(_SceneRestCoordinator());
  sl.registerSingleton<ExecutionTimerCoordinator>(ExecutionTimerCoordinator());

  switch (scene) {
    case RedesignScene.inicio || RedesignScene.inicioDescanso:
      final preferences = AppPreferencesCubit(_ScenePreferencesStorage());
      final bloc = HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(
          _SceneHomeRepository(restDay: scene == RedesignScene.inicioDescanso),
        ),
      )..add(HomeLoadRequested(date: inicioSceneNow));
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
            child: Scaffold(body: HomePage(now: () => inicioSceneNow)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    case RedesignScene.detalle ||
        RedesignScene.detalleEnCurso ||
        RedesignScene.detalleHecho:
      final repository = _SceneTrainingRepository(
        completedIds: detailProgress,
      );
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
        RedesignScene.hojaSerieError ||
        RedesignScene.descanso ||
        RedesignScene.descansoMas30:
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
      if (scene == RedesignScene.hojaSerie ||
          scene == RedesignScene.hojaSerieError) {
        // L3: «Registrar serie» is an ExomPrimaryButton inside the
        // `footer-executing` footer (was `find.byType(ElevatedButton).last`).
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('footer-executing')),
            matching: find.byType(ExomPrimaryButton),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      if (scene == RedesignScene.hojaSerieError) {
        await tester.enterText(
          find.byKey(const Key('set-sheet-weight-field')),
          '62,5,5',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('set-sheet-save')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (scene == RedesignScene.descansoMas30) {
        await tester.tap(find.byKey(const Key('active-exercise-rest-extend')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    case RedesignScene.circuitoActivo ||
        RedesignScene.hojaCircuito ||
        RedesignScene.descansoCircuito ||
        RedesignScene.circuitoListo:
      await tester.pumpWidget(
        _app(
          theme,
          textScale,
          ActiveCircuitPage(
            trainingId: _trainingId,
            blockId: _circuitBlock,
            args: ActiveCircuitPageArgs(
              trainingBloc: _FakeTrainingBloc(),
              trainingName: 'Pierna fuerza',
              trainingTypes: const ['FUERZA'],
              accentColorHex: null,
              trainingLevel: 'INTERMEDIATE',
              blockId: _circuitBlock,
              blockName: 'Circuito metabólico',
              rounds: 3,
              restBetweenRoundsSeconds: 60,
              exercises: _circuitExercises,
              previousPerformances: const {
                'tc-2': [
                  SetPerformance(setNumber: 1, reps: 15, weightKg: 14),
                  SetPerformance(setNumber: 2, reps: 14, weightKg: 14),
                ],
              },
              assignmentDate: _date,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      if (scene == RedesignScene.hojaCircuito) {
        // The circuit primary is an ExomPrimaryButton inside the
        // circuit-executing-footer key, like the active exercise's.
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('circuit-executing-footer')),
            matching: find.byType(ExomPrimaryButton),
          ),
        );
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
