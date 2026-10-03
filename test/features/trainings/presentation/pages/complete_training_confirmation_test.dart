import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:dio/dio.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
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
import 'package:exom_app/injection_container.dart';
import '../../../../core/services/offline_sync_service_test.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (error, label, retry) in [
    ('Bad state: progress_receipt_missing', 'Confirmation missing: retry sync', true),
    ('INVALID_EXERCISE', 'Sync blocked: action failed', false),
    ('progress_conflict_review_required', 'Conflict: review required', false),
  ]) {
  testWidgets('selected queued completion exposes $error without false pending state', (tester) async {
    await sl.reset();
    final store = _CompletionStorage(actions: [
      {'id': 'exercise-op', 'type': 'mark_exercise_completed', 'date': '2026-10-01',
        'training_exercise_id': 'te', 'exercise_id': 'e', 'format_version': 2,
        'training_session_id': 'execution', 'status': 'failed',
        'last_error': error, 'expected_revision': 0},
      {'id': 'complete-op', 'type': 'complete_training', 'training_id': 'training',
        'date': '2026-10-01', 'training_session_id': 'execution',
        'format_version': 2, 'status': 'queued', 'predecessor_id': 'exercise-op'},
    ]);
    final sync = OfflineSyncService(respondingClient((options, handler) {
      handler.reject(DioException.connectionError(requestOptions: options, reason: 'offline'));
    }), store, isAuthenticated: () => true);
    final repository = _CompletionRepository();
    sl.registerSingleton<LocalStorage>(store);
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
      locale: const Locale('es'), localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training', selectedDate: '2026-10-01',
        selectedExecutionId: 'execution'),
    ));
    await tester.pumpAndSettle();
    expect(find.text(label), findsOneWidget);
    expect(find.text('Pending sync'), findsNothing);
    final button = find.byKey(const Key('complete-training-button'));
    expect(tester.widget<ElevatedButton>(button).onPressed, retry ? isNotNull : isNull);
    if (retry) {
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(store.actions.first['status'], retry ? 'queued' : 'failed');
    expect(store.actions.first['id'], 'exercise-op');
    expect(store.actions.first['expected_revision'], 0);
    expect(store.actions.last['predecessor_id'], 'exercise-op');
    expect(repository.completions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await sync.dispose();
    await sl.reset();
  });
  }
  TrainingCompletionInput? dialogResult;
  final storage = _DraftStorage();

  Future<void> openDialog(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('es'),
  }) async {
    dialogResult = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              dialogResult = await showDialog<TrainingCompletionInput>(
                context: context,
                builder: (dialogContext) => CompleteTrainingConfirmationDialog(
                  l10n: AppLocalizations.of(dialogContext),
                  storage: storage,
                  trainingId: 'training', date: '2026-09-05',
                  executionId: 'execution', sessionStamp: storage.sessionStamp,
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains RPE in both locales without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final (locale, label, explanation) in [
      (const Locale('es'), 'RPE (obligatorio, 1–10)', 'El RPE indica cuánto esfuerzo sentiste al entrenar: 1 es muy fácil y 10 es tu máximo esfuerzo.'),
      (const Locale('en'), 'RPE (required, 1–10)', 'RPE measures how hard the workout felt to you: 1 is very easy, 10 is your maximum effort.'),
    ]) {
      await openDialog(tester, locale: locale);
      expect(find.text(label), findsOneWidget);
      expect(find.text(explanation), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(
        find.byKey(const Key('confirm-complete-training'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('cancel-complete-training')));
      await tester.pumpAndSettle();
      expect(dialogResult, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cancel closes confirmation without approving completion', (
    tester,
  ) async {
    await openDialog(tester);
    expect(
      find.byKey(const Key('complete-training-confirmation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('cancel-complete-training')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('complete-training-confirmation')),
      findsNothing,
    );
    expect(dialogResult, isNull);
  });

  testWidgets('confirm action is explicit', (tester) async {
    await openDialog(tester);
    expect(find.text('Completar todo'), findsOneWidget);
    expect(find.byKey(const Key('completion-rpe-selected')), findsNothing);
    expect(tester.widget<FilledButton>(
      find.byKey(const Key('confirm-complete-training'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    expect(dialogResult, isNull);
    await tester.tap(find.byKey(const Key('completion-rpe-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
    expect(dialogResult?.rpe, 10);
    expect(dialogResult?.notes, isNull);
  });

  testWidgets('uses the active dark theme', (tester) async {
    await openDialog(tester, brightness: Brightness.dark);

    final context = tester.element(
      find.byKey(const Key('complete-training-confirmation')),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}

class _CompletionStorage extends FakeSyncStorage {
  _CompletionStorage({required super.actions});
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => [];
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  List<Map<String, dynamic>> getTrainingExecutions(String trainingId, String date) => [];
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(String trainingId, String date) => [];
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) => null;
  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(String trainingId, String exerciseId, String date) => null;
  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      ValueNotifier<Box<ActiveWorkoutHiveModel>>(_CompletionBox());
}
class _CompletionBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _CompletionRepository extends Fake implements TrainingRepository {
  int completions = 0;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      TrainingEntity(id: 'training', name: 'Synthetic Thursday',
        types: ['FUERZA'], level: 'INTERMEDIATE', tags: [], exercises: []);
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      const TrainingDayProgress();
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
      List<String> exerciseIds, String beforeDate) async => {};
  @override
  Future<void> completeTraining(String date, {required String trainingId,
      String? sessionId, int? rpe, String? notes}) async { completions++; }
}

class _DraftStorage extends LocalStorage {
  Map<String, dynamic>? draft;

  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
      String trainingId, String date, String executionId) => draft;

  @override
  Future<void> saveTrainingCompletionDraft(
      String trainingId, String date, String executionId,
      {int? rpe, String? notes}) async {
    draft = {'rpe': ?rpe, 'notes': ?notes};
  }
}
