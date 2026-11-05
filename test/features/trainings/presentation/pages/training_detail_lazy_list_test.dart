import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
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

const _date = '2026-09-05';
const _execution = 'execution-1';

class _Storage extends LocalStorage {
  int workoutLookups = 0;
  List<Map<String, dynamic>> executions = const [];

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
  ) => executions;
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => executions;
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) {
    workoutLookups++;
    return null;
  }

  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(
    String trainingId,
    String exerciseId,
    String date,
  ) {
    workoutLookups++;
    return null;
  }

  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      ValueNotifier<Box<ActiveWorkoutHiveModel>>(_EmptyBox());
}

class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _Sync extends OfflineSyncService {
  _Sync(LocalStorage storage) : super(ApiClient(useAuth: false), storage);
  @override
  Stream<void> get changes => const Stream<void>.empty();
  @override
  List<Map<String, dynamic>> get pendingActions => const [];
}

/// Counts how often the circuit grouping logic reads block membership.
class _CountingExercise extends TrainingExerciseEntity {
  _CountingExercise({
    required super.id,
    required super.order,
    required super.exercise,
    super.blockId,
    super.positionInBlock,
  }) : super(
         sets: 3,
         repsOrDuration: '10',
         restSeconds: 30,
         blockName: blockId == null ? null : 'Circuit $blockId',
         blockRounds: blockId == null ? null : 2,
       );

  static int blockReads = 0;

  @override
  String? get blockId {
    blockReads++;
    return super.blockId;
  }
}

/// 40 single exercises followed by 20 circuits of 3 exercises = 100 exercises
/// (40 singles + 60 circuit members).
TrainingEntity _bigTraining() {
  final exercises = <TrainingExerciseEntity>[];
  var order = 1;
  for (var single = 0; single < 40; single++) {
    exercises.add(
      _CountingExercise(
        id: 'te-$order',
        order: order,
        exercise: ExerciseEntity(
          id: 'ex-$order',
          name: 'Single exercise $order',
          muscleGroups: const [],
          thumbnailUrl: 'https://img.exom.test/$order.jpg',
        ),
      ),
    );
    order++;
  }
  for (var circuit = 0; circuit < 20; circuit++) {
    for (var position = 0; position < 3; position++) {
      exercises.add(
        _CountingExercise(
          id: 'te-$order',
          order: order,
          blockId: 'block-$circuit',
          positionInBlock: position,
          exercise: ExerciseEntity(
            id: 'ex-$order',
            name: 'Circuit exercise $order',
            muscleGroups: const [],
          ),
        ),
      );
      order++;
    }
  }
  return TrainingEntity(
    id: 'training-1',
    name: 'Big training',
    types: const ['FUERZA'],
    level: 'INTERMEDIATE',
    tags: const [],
    exercises: exercises,
  );
}

class _Repository extends Fake implements TrainingRepository {
  _Repository(this.training);
  TrainingEntity training;
  bool withExecution = false;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      training;
  @override
  Future<void> markExerciseCompleted(
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
    List<SetPerformance>? sets,
    String? lastSetFeedbackClientUploadId,
    String? trainingId,
    String? sessionId,
    String? operationId,
  }) async {}
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      withExecution
      ? const TrainingDayProgress(
          sessions: {_execution: TrainingDayProgress()},
          sessionTrainings: {_execution: 'training-1'},
        )
      : const TrainingDayProgress();
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => {};
}

int _count(String typeName) => find
    .byWidgetPredicate((w) => w.runtimeType.toString() == typeName)
    .evaluate()
    .length;

Future<({_Storage storage, _Repository repository})> _mount(
  WidgetTester tester, {
  bool withExecution = false,
}) async {
  await sl.reset();
  final storage = _Storage();
  final repository = _Repository(_bigTraining())
    ..withExecution = withExecution;
  if (withExecution) {
    storage.executions = [
      {
        'id': _execution,
        'training_id': 'training-1',
        'assignment_date': _date,
        'status': 'pending',
      },
    ];
  }
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
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/detail',
        builder: (_, _) => TrainingDetailPage(
          trainingId: 'training-1',
          selectedDate: _date,
          selectedExecutionId: withExecution ? _execution : null,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  _CountingExercise.blockReads = 0;
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return (storage: storage, repository: repository);
}

void main() {
  tearDown(sl.reset);

  testWidgets('MEASURE 100 exercises in a fixed viewport', (tester) async {
    final storage = (await _mount(tester)).storage;
    final exerciseCards = _count('_ExerciseCard');
    final circuitCards = _count('_CircuitCard');
    final images = find.byType(CachedNetworkImage).evaluate().length;
    // ignore: avoid_print
    print(
      'DETAIL_MOUNTED exerciseCards=$exerciseCards circuitCards=$circuitCards '
      'cachedImages=$images workoutLookups=${storage.workoutLookups} '
      'blockIdReads=${_CountingExercise.blockReads}',
    );
    expect(exerciseCards + circuitCards, lessThan(25));
    expect(images, lessThan(15));
    expect(storage.workoutLookups, lessThan(25));
    expect(_CountingExercise.blockReads, lessThan(400));
  });

  testWidgets('scrolling to the end mounts the last exercise lazily', (
    tester,
  ) async {
    await _mount(tester);
    expect(find.text('Circuit block-19'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Circuit block-19'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    expect(find.text('Circuit block-19'), findsOneWidget);
    expect(find.text('Single exercise 1'), findsNothing);
  });

  TrainingBloc blocOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first).read<TrainingBloc>();

  void markCompleted(TrainingBloc bloc, int order) {
    bloc.add(
      MarkExerciseCompleted(
        trainingExerciseId: 'te-$order',
        exerciseId: 'ex-$order',
        completed: true,
        sessionId: _execution,
        sessionStamp: 'owner:1:test',
      ),
    );
  }

  testWidgets('progress update checks the visible row', (tester) async {
    await _mount(tester, withExecution: true);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    markCompleted(blocOf(tester), 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('progress update keeps the scroll position', (tester) async {
    await _mount(tester, withExecution: true);
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
    double offset() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    final before = offset();
    expect(before, greaterThan(0));
    final label = tester
        .widget<Text>(find.textContaining('Single exercise').first)
        .data!;
    final order = int.parse(label.split(' ').last);
    markCompleted(blocOf(tester), order);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(offset(), before);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('a new training revision regroups circuits', (tester) async {
    final fixture = await _mount(tester);
    fixture.repository.training = const TrainingEntity(
      id: 'training-1',
      name: 'Revised',
      types: ['FUERZA'],
      level: 'INTERMEDIATE',
      tags: [],
      exercises: [
        TrainingExerciseEntity(
          id: 'r-1',
          order: 1,
          sets: 3,
          repsOrDuration: '10',
          restSeconds: 30,
          blockId: 'X',
          positionInBlock: 1,
          blockName: 'Circuit X',
          blockRounds: 2,
          exercise: ExerciseEntity(id: 'rx-1', name: 'R1', muscleGroups: []),
        ),
        TrainingExerciseEntity(
          id: 'r-2',
          order: 2,
          sets: 3,
          repsOrDuration: '10',
          restSeconds: 30,
          blockId: 'X',
          positionInBlock: 0,
          blockName: 'Circuit X',
          blockRounds: 2,
          exercise: ExerciseEntity(id: 'rx-2', name: 'R2', muscleGroups: []),
        ),
        TrainingExerciseEntity(
          id: 'r-3',
          order: 3,
          sets: 3,
          repsOrDuration: '10',
          restSeconds: 30,
          exercise: ExerciseEntity(id: 'rx-3', name: 'R3', muscleGroups: []),
        ),
        TrainingExerciseEntity(
          id: 'r-4',
          order: 4,
          sets: 3,
          repsOrDuration: '10',
          restSeconds: 30,
          blockId: 'Y',
          blockName: 'Circuit Y',
          blockRounds: 2,
          exercise: ExerciseEntity(id: 'rx-4', name: 'R4', muscleGroups: []),
        ),
      ],
    );
    blocOf(tester).add(
      const TrainingDetailLoadRequested('training-1', date: _date),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_count('_CircuitCard'), 2);
    expect(_count('_ExerciseCard'), 1);
    expect(find.text('Circuit X'), findsOneWidget);
    expect(find.text('Circuit Y'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('R3'), findsOneWidget);
    expect(find.text('Circuit block-0'), findsNothing);
  });
}
