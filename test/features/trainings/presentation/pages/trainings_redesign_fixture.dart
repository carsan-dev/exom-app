// Shared fixture of the L5-A3 «Entrenar: lista e historial» tests and goldens:
// a fake owner-scoped storage with the local pending sessions, a bloc seeded
// with a fixed state (no network, no clock) and a router app that mounts the
// real TrainingsPage with the redesign theme, fonts, locale and text scale.
// Not a test file: it has no `main` and is only imported.
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
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
import 'package:exom_app/features/trainings/presentation/pages/trainings_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Owner-scoped storage double: only what the list screen reads.
class SceneStorage extends LocalStorage {
  SceneStorage(this.pending);

  final List<Map<String, dynamic>> pending;
  String stamp = 'owner-A:1';

  @override
  String? get ownerId => 'owner-A';

  @override
  String? get sessionStamp => stamp;

  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => pending;
}

class _UnusedRepository extends Fake implements TrainingRepository {}

/// Bloc that starts in [seed] and records the events the page sends instead of
/// loading anything.
class SeededTrainingBloc extends TrainingBloc {
  SeededTrainingBloc(TrainingState seed) : this._(_UnusedRepository(), seed);

  SeededTrainingBloc._(TrainingRepository r, TrainingState seed)
    : super(
        getTodayTrainingUseCase: GetTodayTrainingUseCase(r),
        getTrainingsUseCase: GetTrainingsUseCase(r),
        getTrainingUseCase: GetTrainingUseCase(r),
        markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(r),
        unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(r),
        completeTrainingUseCase: CompleteTrainingUseCase(r),
        getCompletedExercisesUseCase: GetCompletedExercisesUseCase(r),
        getPreviousExercisePerformancesUseCase:
            GetPreviousExercisePerformancesUseCase(r),
      ) {
    emit(seed);
  }

  final events = <TrainingEvent>[];

  @override
  void add(TrainingEvent event) => events.add(event);

  /// Moves the bloc to [state], as a real load or refresh would.
  void seed(TrainingState state) => emit(state);
}

/// Day shown by every scene: a past month, so the «next month» arrow is
/// enabled whatever the real clock says.
const String kSceneDate = '2026-10-14';

final TrainingEntity kSceneTraining = TrainingEntity(
  id: 'training-legs',
  name: 'Pierna · Fuerza',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  estimatedDurationMin: 55,
  tags: const [],
  exercises: [
    for (var i = 1; i <= 6; i++)
      TrainingExerciseEntity(
        id: 'te-$i',
        order: i,
        sets: 4,
        repsOrDuration: '8',
        restSeconds: 90,
        exercise: ExerciseEntity(
          id: 'ex-$i',
          name: 'Ejercicio $i',
          muscleGroups: const [],
        ),
      ),
  ],
);

final List<TrainingHistoryEntity> kSceneHistory = [
  TrainingHistoryEntity(
    id: 'history-push',
    name: 'Torso · Empuje',
    types: const ['FUERZA'],
    level: 'INTERMEDIATE',
    estimatedDurationMin: 51,
    date: DateTime(2026, 10, 12),
    isCompleted: true,
  ),
  TrainingHistoryEntity(
    id: 'history-pull',
    name: 'Torso · Tracción',
    types: const ['FUERZA', 'HIPERTROFIA'],
    level: 'INTERMEDIATE',
    estimatedDurationMin: 52,
    date: DateTime(2026, 10, 9),
    isCompleted: false,
  ),
  TrainingHistoryEntity(
    id: 'history-legs',
    name: 'Pierna · Fuerza',
    types: const ['FUERZA'],
    level: 'INTERMEDIATE',
    estimatedDurationMin: 48,
    date: DateTime(2026, 10, 7),
    isCompleted: true,
  ),
];

/// One local session pending completion (the queue entry shape of
/// `LocalStorage.getPendingTrainingExecutions`).
List<Map<String, dynamic>> scenePending() => [
  {
    'id': '8f3c2a71-5d94-4be0-a6c1-0e7b92d4f358',
    'training_id': 'training-legs',
    'training_name': 'Pierna · Fuerza',
    'assignment_date': '2026-10-13',
    'status': 'pending-finalize',
  },
];

TrainingsLoaded sceneLoaded({
  List<TrainingEntity>? today,
  List<TrainingHistoryEntity>? history,
  bool isHistoryLoading = false,
  bool historyFailed = false,
}) => TrainingsLoaded(
  history: history ?? kSceneHistory,
  todayTrainings: today ?? [kSceneTraining],
  selectedDate: kSceneDate,
  historyDate: kSceneDate,
  isHistoryLoading: isHistoryLoading,
  historyFailed: historyFailed,
);

/// URIs opened from the list (the detail route is a stub).
final List<String> openedRoutes = [];

/// Registers [storage] (and [sync] when given) and a bloc seeded with [state],
/// then mounts the real TrainingsPage inside a Scaffold under a GoRouter, on
/// [selectedDate] (`null` is «today», as the shell tab opens it).
Future<SeededTrainingBloc> pumpTrainingsScene(
  WidgetTester tester, {
  required TrainingState state,
  SceneStorage? storage,
  OfflineSyncService? sync,
  String? selectedDate = kSceneDate,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
}) async {
  await loadRedesignFonts();
  await sl.reset();
  openedRoutes.clear();
  final bloc = SeededTrainingBloc(state);
  sl.registerSingleton<LocalStorage>(storage ?? SceneStorage([]));
  if (sync != null) sl.registerSingleton<OfflineSyncService>(sync);
  sl.registerFactory<TrainingBloc>(() => bloc);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final router = GoRouter(
    initialLocation: '/trainings',
    routes: [
      GoRoute(
        path: '/trainings',
        builder: (_, _) =>
            Scaffold(body: TrainingsPage(selectedDate: selectedDate)),
      ),
      GoRoute(
        path: '/trainings/:id',
        builder: (_, routeState) {
          openedRoutes.add(routeState.uri.toString());
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
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
        GlassDecoration.brightness = Theme.of(context).brightness;
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
  return bloc;
}
