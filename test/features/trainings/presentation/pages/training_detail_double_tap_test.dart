// O7: a second tap on Inicio's «Empezar sesión», landing while the training
// detail route is still entering or has just appeared, must not run the
// detail's pinned footer actions («Siguiente» opened the exercise and left a
// local session with 0 sets). A later, intentional tap still works.
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
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
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

const _date = '2026-11-28';
const _trainingId = 'training-1';

final _training = TrainingEntity(
  id: _trainingId,
  name: 'O5 ANY 2',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  estimatedDurationMin: 15,
  tags: const [],
  exercises: const [
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: 1,
      repsOrDuration: '10',
      targetRir: 2,
      restSeconds: 10,
      exercise: ExerciseEntity(id: 'ex-1', name: 'O5 Remo', muscleGroups: []),
    ),
  ],
);

/// No execution yet: «Siguiente» creates a new local one, as on the device.
class _Storage extends LocalStorage {
  int creations = 0;

  @override
  String? get sessionStamp => 'owner:1:test';
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => const [];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => const [];
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) => false;
  @override
  Future<String> createTrainingExecution(
    String trainingId,
    String date, {
    String? trainingName,
  }) async {
    creations++;
    return 'execution-new';
  }

  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId,
  ) => null;
  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() => const [];
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
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => const Locale('es');
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _Sync extends OfflineSyncService {
  _Sync(LocalStorage storage) : super(ApiClient(useAuth: false), storage);
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => controller.stream;
  @override
  CompletionSyncBlocker? completionBlocker(
    String trainingId,
    String date,
    String? sessionId,
  ) => null;
}

class _Repository extends Fake implements TrainingRepository {
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      _training;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      const TrainingDayProgress();
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => const {};
}

final _nextButton = find.byKey(const Key('training-next-button'));
final _completeButton = find.byKey(const Key('complete-training-button'));

/// Inicio stand-in: its pinned lime action covers the bottom of the screen,
/// where the detail's «Siguiente» appears, and pushes the detail as Inicio
/// does (`/trainings/:id?date=`).
Future<_Storage> _mountHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage();
  final repository = _Repository();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(_Sync(storage));
  sl.registerFactory<TrainingBloc>(
    () => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(
        repository,
      ),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase:
          GetPreviousExercisePerformancesUseCase(repository),
    ),
  );
  final preferences = AppPreferencesCubit(storage);
  addTearDown(preferences.close);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: SizedBox.expand(
            child: GestureDetector(
              key: const Key('home-start-session'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/trainings/$_trainingId?date=$_date'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/trainings/:id',
        builder: (_, state) => TrainingDetailPage(
          trainingId: state.pathParameters['id']!,
          selectedDate: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/trainings/:training/exercises/:exercise',
        builder: (_, _) => const Scaffold(body: Text('active-exercise-route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

/// Taps «Empezar sesión» and pumps frames for [elapsed] (in 20 ms steps, so
/// the route transition and the detail load run as on a device).
Future<void> _startSessionAndWait(WidgetTester tester, Duration elapsed) async {
  await tester.tap(find.byKey(const Key('home-start-session')));
  const step = Duration(milliseconds: 20);
  for (var waited = Duration.zero; waited < elapsed; waited += step) {
    await tester.pump(step);
  }
}

void main() {
  tearDown(sl.reset);

  testWidgets(
    'a second tap 0,5 s after «Empezar sesión» does not open the next '
    'exercise nor create a local session',
    (tester) async {
      final storage = await _mountHome(tester);
      await _startSessionAndWait(tester, const Duration(milliseconds: 500));

      // The detail is loaded and its «Siguiente» sits under the finger.
      expect(_nextButton.hitTestable(), findsOneWidget);
      await tester.tapAt(tester.getCenter(_nextButton));
      await tester.pumpAndSettle();

      expect(storage.creations, 0);
      expect(find.text('active-exercise-route'), findsNothing);
      expect(find.byType(TrainingDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'a tap landing on «Completar todo» while the detail enters is ignored too',
    (tester) async {
      final storage = await _mountHome(tester);
      await _startSessionAndWait(tester, const Duration(milliseconds: 300));

      expect(_completeButton.hitTestable(), findsOneWidget);
      await tester.tapAt(tester.getCenter(_completeButton));
      await tester.pumpAndSettle();

      expect(storage.creations, 0);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'an intentional tap on «Siguiente» once the detail has settled opens the '
    'exercise as before',
    (tester) async {
      final storage = await _mountHome(tester);
      await _startSessionAndWait(tester, const Duration(milliseconds: 1200));

      await tester.tap(_nextButton);
      await tester.pumpAndSettle();

      expect(storage.creations, 1);
      expect(find.text('active-exercise-route'), findsOneWidget);
    },
  );

  testWidgets(
    'a tap ignored during the entry does not block the next intentional tap',
    (tester) async {
      final storage = await _mountHome(tester);
      await _startSessionAndWait(tester, const Duration(milliseconds: 500));
      await tester.tapAt(tester.getCenter(_nextButton));
      await tester.pump(const Duration(seconds: 1));
      expect(storage.creations, 0);

      await tester.tap(_nextButton);
      await tester.pumpAndSettle();

      expect(storage.creations, 1);
      expect(find.text('active-exercise-route'), findsOneWidget);
    },
  );
}
