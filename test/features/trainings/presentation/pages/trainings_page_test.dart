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
import 'package:exom_app/features/trainings/presentation/pages/trainings_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class _PendingStorage extends LocalStorage {
  String stamp = 'A:1:test';
  @override
  String? get sessionStamp => stamp;

  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => [
    {'id': 'one', 'training_id': 'same', 'training_name': 'Strength',
     'assignment_date': '2026-08-12', 'status': 'pending-finalize'},
    {'id': 'two', 'training_id': 'same', 'training_name': 'Strength',
     'assignment_date': '2026-08-12', 'status': 'pending-finalize'},
    {'id': 'three', 'training_id': 'other', 'training_name': 'Mobility',
     'assignment_date': '2026-09-05', 'status': 'pending-finalize'},
    {'id': 'four', 'training_id': 'sync', 'training_name': 'Recovery',
     'assignment_date': '2026-09-06', 'status': 'pending-sync'},
  ];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(String trainingId, String date) =>
      getPendingTrainingExecutions().where((entry) =>
          entry['training_id'] == trainingId && entry['assignment_date'] == date).toList();
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [];
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(String trainingId, String date, String executionId) => null;
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) => false;
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(String trainingId, String exerciseId, String date) => null;
  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      ValueNotifier<Box<ActiveWorkoutHiveModel>>(_EmptyBox());
}

class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _Repository extends Fake implements TrainingRepository {
  final requests = <String>[];
  @override
  Future<List<TrainingHistoryEntity>> getTrainings({String? date}) async => [];
  @override
  Future<TrainingEntity?> getTodayTraining({String? date}) async => null;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async {
    requests.add('$id:$date');
    return TrainingEntity(id: id, name: id, types: const ['FUERZA'],
        level: 'INTERMEDIATE', tags: const [], exercises: const []);
  }
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async => const TrainingDayProgress();
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
      List<String> exerciseIds, String beforeDate) async => {};
}

void main() {
  testWidgets('global pending list distinguishes executions and does not offer RPE for sync',
      (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PendingTrainingExecutions(
        storage: _PendingStorage(),
        onSelect: (entry, action) => selected.add('${entry['id']}:$action'),
      )),
    ));
    expect(find.text('Tienes un entrenamiento pendiente de finalizar'), findsOneWidget);
    expect(find.textContaining('Strength · 2026-08-12'), findsNWidgets(2));
    expect(find.textContaining('Mobility · 2026-09-05'), findsOneWidget);
    expect(find.textContaining('Recovery · 2026-09-06'), findsOneWidget);
    expect(find.textContaining('Pendiente de sincronización'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pending-continue-one')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pending-finalize-two')));
    expect(selected, ['one:continue', 'two:finalize']);
    expect(find.byKey(const Key('pending-finalize-four')), findsNothing);
    expect(find.byKey(const Key('pending-continue-four')), findsNothing);
  });

  testWidgets('pending selections route exact execution/date/training and reject a stale owner', (tester) async {
    await sl.reset();
    final storage = _PendingStorage();
    final repository = _Repository();
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerFactory<TrainingBloc>(() => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase: GetPreviousExercisePerformancesUseCase(repository),
    ));
    // Mirror the existing GoRouter training paths and detail query mapping.
    final router = GoRouter(initialLocation: '/trainings', routes: [
      GoRoute(path: '/trainings', builder: (_, state) => Scaffold(
          body: TrainingsPage(selectedDate: state.uri.queryParameters['date']))),
      GoRoute(path: '/trainings/:id', builder: (_, state) => TrainingDetailPage(
        trainingId: state.pathParameters['id']!,
        selectedDate: state.uri.queryParameters['date'],
        selectedExecutionId: state.uri.queryParameters['execution'],
        finalizeSelected: state.uri.queryParameters['action'] == 'finalize',
      )),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pending-finalize-four')), findsNothing,
        reason: 'pending sync must not offer an RPE route');
    await tester.tap(find.byKey(const Key('pending-continue-one')));
    await tester.pumpAndSettle();
    var detail = tester.widget<TrainingDetailPage>(find.byType(TrainingDetailPage));
    expect((detail.trainingId, detail.selectedDate, detail.selectedExecutionId, detail.finalizeSelected),
        ('same', '2026-08-12', 'one', false));
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pending-finalize-two')));
    await tester.pumpAndSettle();
    detail = tester.widget<TrainingDetailPage>(find.byType(TrainingDetailPage));
    expect((detail.trainingId, detail.selectedDate, detail.selectedExecutionId, detail.finalizeSelected),
        ('same', '2026-08-12', 'two', true));
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('complete-training-confirmation')))).pop();
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('pending-continue-three')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pending-continue-three')));
    await tester.pumpAndSettle();
    detail = tester.widget<TrainingDetailPage>(find.byType(TrainingDetailPage));
    expect((detail.trainingId, detail.selectedDate, detail.selectedExecutionId, detail.finalizeSelected),
        ('other', '2026-09-05', 'three', false));
    router.pop();
    await tester.pumpAndSettle();
    storage.stamp = 'B:2:test';
    await tester.ensureVisible(find.byKey(const Key('pending-continue-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pending-continue-one')));
    await tester.pumpAndSettle();
    expect(find.byType(TrainingDetailPage), findsNothing);
    expect(repository.requests, ['same:2026-08-12', 'same:2026-08-12', 'other:2026-09-05']);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await sl.reset();
  });
}
