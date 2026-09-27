import 'dart:async';

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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

const _date = '2026-09-05';
const _session = 'execution-one';
const _otherSession = 'execution-a';

class _Storage extends LocalStorage {
  String stamp = 'owner:1:test';
  String status = 'pending-sync';
  String? actionStatus = 'queued';
  List<Map<String, dynamic>>? conflictActions;
  List<Map<String, dynamic>>? executions;
  final Map<String, Map<String, dynamic>> completionDrafts = {};
  @override
  String? get sessionStamp => stamp;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => conflictActions ?? (actionStatus == null ? [] : [
    {'type': 'complete_training', 'training_id': 'training-1', 'date': _date,
      'training_session_id': _session, 'status': actionStatus},
  ]);
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => executions ?? [
    {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': status},
  ];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(String trainingId, String date) =>
      getPendingTrainingExecutions();
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(String trainingId, String date) =>
      getPendingTrainingExecutions().where((entry) =>
        entry['training_id'] == trainingId && entry['assignment_date'] == date &&
        const ['confirmed', 'completed'].contains(entry['status'])).toList();
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(String trainingId, String date, String executionId) {
    final draft = completionDrafts[executionId];
    if (draft != null) {
      return draft['training_id'] == trainingId && draft['assignment_date'] == date
          ? Map<String, dynamic>.from(draft) : null;
    }
    return executions?.any((execution) => execution['id'] == executionId && execution['status'] == 'pending') == true
        ? null : {'rpe': 7, 'notes': 'Saved locally'};
  }
  @override
  Future<void> saveTrainingCompletionDraft(String trainingId, String date,
      String executionId, {int? rpe, String? notes}) async {
    completionDrafts[executionId] = {
      'training_id': trainingId,
      'assignment_date': date,
      'rpe': ?rpe,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
  }
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) =>
      const ['completed', 'confirmed'].contains(status);
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) => null;
  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(String trainingId, String exerciseId, String date) => null;
  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      ValueNotifier<Box<ActiveWorkoutHiveModel>>(_EmptyBox());
}
// Match the production routable view: completed and in-flight executions
// remain in the owner registry but cannot be selected for further writes.
class _FilteredStorage extends _Storage {
  int creations = 0;

  @override
  List<Map<String, dynamic>> getTrainingExecutions(String trainingId, String date) =>
      getPendingTrainingExecutions().where((entry) =>
        entry['training_id'] == trainingId && entry['assignment_date'] == date &&
        !const ['pending-sync', 'confirmed', 'completed'].contains(entry['status'])).toList();

  @override
  Future<String> createTrainingExecution(String trainingId, String date,
      {String? trainingName}) async {
    creations++;
    return 'execution-two';
  }
}
class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _Sync extends OfflineSyncService {
  _Sync(_Storage storage) : super(ApiClient(useAuth: false), storage);
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => events.stream.map((event) => event);
  void notify() => events.add(null);
  Future<void> closeEvents() => events.close();
}

class _Repository extends Fake implements TrainingRepository {
  int completions = 0;
  bool requireSets = false;
  bool includeProgress = true;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      TrainingEntity(id: 'training-1', name: 'Training', types: const ['FUERZA'],
        level: 'INTERMEDIATE', tags: const [], exercises: requireSets ? const [
          TrainingExerciseEntity(id: 'te-1', order: 1, sets: 1,
            repsOrDuration: '10', restSeconds: 30,
            exercise: ExerciseEntity(id: 'ex-1', name: 'Exercise', muscleGroups: [])),
        ] : const []);
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      requireSets && includeProgress ? const TrainingDayProgress(
        sessions: {_session: TrainingDayProgress(
          ids: {'te-1'}, performances: {'te-1': [SetPerformance(setNumber: 1, reps: 10)]})},
        sessionTrainings: {_session: 'training-1'},
      ) : const TrainingDayProgress();
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
      List<String> exerciseIds, String beforeDate) async => {};
  @override
  Future<void> completeTraining(String date, {required String trainingId,
      String? sessionId, int? rpe, String? notes}) async { completions++; }
}

void main() {
  for (final status in ['pending-sync', 'confirmed']) {
    testWidgets('$status execution requires explicit New when opening an exercise', (tester) async {
      await sl.reset();
      final storage = _FilteredStorage()..status = status..actionStatus = null;
      final repository = _Repository()..requireSets = true;
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
      final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) =>
        const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date))]);
      await tester.pumpWidget(MaterialApp.router(
        locale: const Locale('es'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();
      final openExercise = status == 'confirmed'
          ? find.text('Editar datos')
          : find.text(AppLocalizations.of(
              tester.element(find.byType(TrainingDetailPage))).startExerciseButton);
      await tester.scrollUntilVisible(openExercise, 200,
        scrollable: find.descendant(of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Scrollable)).first);
      await tester.tap(openExercise);
      await tester.pumpAndSettle();
      expect(find.text('Select training execution'), findsOneWidget);
      expect(find.text(_session), findsNothing,
        reason: 'in-flight or confirmed execution must not be offered for writes');
      expect(storage.creations, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.creations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await sl.reset();
    });
  }

  testWidgets('confirmed execution requires New even from Complete all', (tester) async {
    await sl.reset();
    final storage = _FilteredStorage()..status = 'confirmed'..actionStatus = null;
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
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('complete-training-button'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Select training execution'), findsOneWidget);
    expect(storage.creations, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.creations, 0);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New execution'));
    await tester.pumpAndSettle();
    expect(storage.creations, 1);
    expect(storage.getPendingTrainingExecutions().single['id'], _session);
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });
  testWidgets('cold detail displays sole confirmed execution without selecting it for writes', (tester) async {
    await sl.reset();
    final storage = _FilteredStorage()..status = 'confirmed'..actionStatus = null;
    final repository = _Repository()..requireSets = true;
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
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date),
    ));
    await tester.pumpAndSettle();
    final label = AppLocalizations.of(tester.element(find.byType(TrainingDetailPage))).completedExercisesLabel;
    expect(find.text('1/1 $label'), findsOneWidget);
    expect(repository.completions, 0);
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.text('Select training execution'), findsOneWidget);
    expect(storage.creations, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  testWidgets('Today detail restores sole queued execution progress without an explicit id', (tester) async {
    await sl.reset();
    final storage = _Storage()
      ..status = 'pending-finalize'
      ..conflictActions = [
        {'type': 'mark_exercise_completed', 'training_id': 'training-1',
          'date': _date, 'training_session_id': _session, 'status': 'queued'},
      ];
    final repository = _Repository()..requireSets = true;
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
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1/1 ${AppLocalizations.of(tester.element(find.byType(TrainingDetailPage))).completedExercisesLabel}'), findsOneWidget);
    expect(repository.completions, 0, reason: 'hydration must not finalize the execution');
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.text(_session), findsOneWidget,
      reason: 'display-only hydration must not bypass explicit execution selection');
    expect(repository.completions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  testWidgets('Cold detail displays sole pending-sync completion progress without selecting it', (tester) async {
    await sl.reset();
    final storage = _Storage();
    final repository = _Repository()..requireSets = true;
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
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date),
    ));
    await tester.pumpAndSettle();
    final label = AppLocalizations.of(tester.element(find.byType(TrainingDetailPage))).completedExercisesLabel;
    expect(find.text('1/1 $label'), findsOneWidget);
    expect(repository.completions, 0);
    expect(find.text('Pending sync'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('complete-training-button'))).onPressed, isNull);
    expect(repository.completions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  for (final scenario in <String, List<Map<String, dynamic>>>{
    'two matching executions': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending-finalize'},
      {'id': _otherSession, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending'},
    ],
    'confirmed plus pending': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'confirmed'},
      {'id': _otherSession, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending'},
    ],
    'confirmed foreign training': [
      {'id': _session, 'training_id': 'training-2', 'assignment_date': _date, 'status': 'confirmed'},
    ],
    'confirmed foreign date': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': '2026-09-06', 'status': 'confirmed'},
    ],
    'confirmed missing session progress': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'confirmed'},
    ],
    'foreign training': [
      {'id': _session, 'training_id': 'training-2', 'assignment_date': _date, 'status': 'pending-finalize'},
    ],
    'foreign date': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': '2026-09-06', 'status': 'pending-finalize'},
    ],
    'pending sync': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending-sync'},
    ],
    'conflict': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'conflict'},
    ],
    'two pending-sync executions with completion action': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending-sync'},
      {'id': _otherSession, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending-sync'},
    ],
    'pending-sync execution with unbound completion action': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending-sync'},
    ],
    'pending-sync execution with foreign completion action': [
      {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending-sync'},
    ],
  }.entries) {
    testWidgets('Today detail does not infer progress from ${scenario.key}', (tester) async {
      await sl.reset();
      final storage = _Storage()..executions = scenario.value..actionStatus = null;
      if (scenario.key.contains('with completion action')) {
        storage.conflictActions = [
          {'type': 'complete_training', 'training_id': 'training-1', 'date': _date,
            'training_session_id': _session, 'status': 'queued'},
        ];
      } else if (scenario.key.contains('unbound completion action') ||
          scenario.key.contains('foreign completion action')) {
        storage.conflictActions = [
          {'type': 'complete_training', 'training_id': 'training-1', 'date': _date,
            if (scenario.key.contains('foreign')) 'training_session_id': _otherSession,
            'status': 'queued'},
        ];
      }
      final repository = _Repository()..requireSets = true
        ..includeProgress = scenario.key != 'confirmed missing session progress';
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
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date),
      ));
      await tester.pumpAndSettle();
      final label = AppLocalizations.of(tester.element(find.byType(TrainingDetailPage))).completedExercisesLabel;
      expect(find.text('0/1 $label'), findsOneWidget);
      expect(repository.completions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await sl.reset();
    });
  }

  for (final legacy in [false, true]) {
    testWidgets('another execution conflict does not block selected pending execution (legacy: $legacy)', (tester) async {
      await sl.reset();
      final storage = _Storage()
        ..actionStatus = null
        ..executions = [
          {'id': _otherSession, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'conflict'},
          {'id': _session, 'training_id': 'training-1', 'assignment_date': _date, 'status': 'pending'},
        ]
        ..conflictActions = [
          {'type': 'complete_training', 'training_id': 'training-1', 'date': _date,
            if (!legacy) 'training_session_id': _otherSession,
            'status': 'failed', 'last_error': 'progress_conflict_review_required'},
        ];
      final repository = _Repository()..requireSets = true;
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
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date,
          selectedExecutionId: _session),
      ));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('complete-training-button'));
      expect(find.text('Conflict: review required'), findsNothing);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
      await tester.tap(find.byKey(const Key('completion-rpe-7')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-complete-training')));
      await tester.pumpAndSettle();
      expect(repository.completions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await sl.reset();
    });
  }
  for (final outcome in ['ack', 'legacy ack', 'failed']) {
    testWidgets('mounted detail reacts to pending sync -> $outcome without re-prompting RPE', (tester) async {
      await sl.reset();
      final storage = _Storage();
      final sync = _Sync(storage);
      final repository = _Repository();
      sl.registerSingleton<LocalStorage>(storage);
      sl.registerSingleton<OfflineSyncService>(sync);
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
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: _date,
          selectedExecutionId: _session),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pending sync'), findsOneWidget);
      expect(sync.events.hasListener, isTrue);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('complete-training-button'))).onPressed, isNull);
      storage.actionStatus = null;
      storage.status = outcome == 'ack' ? 'confirmed' : outcome == 'legacy ack' ? 'completed' : 'failed';
      storage.stamp = 'another-owner:2:test';
      sync.notify();
      await tester.pumpAndSettle();
      expect(find.text('Pending sync'), findsOneWidget,
        reason: 'events from a different session cannot refresh this page');
      storage.stamp = 'owner:1:test';
      sync.notify();
      await tester.pumpAndSettle();
      expect(find.text('Pending sync'), findsNothing);
      if (outcome != 'failed') {
        expect(tester.widget<ElevatedButton>(find.byKey(const Key('complete-training-button'))).onPressed, isNull);
        expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
        expect(repository.completions, 0);
      } else {
        expect(find.text('Retry completion'), findsOneWidget);
        await tester.tap(find.byKey(const Key('complete-training-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
        expect(repository.completions, 1);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(sync.events.hasListener, isFalse);
      sync.notify();
      await tester.pump();
      await sync.closeEvents();
      await sl.reset();
    });
  }
}
