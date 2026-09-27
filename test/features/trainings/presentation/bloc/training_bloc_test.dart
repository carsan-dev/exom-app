import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/core/api/api_client.dart';
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
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const ['es', 'en']) {
    for (final reply in <String?>[null, 'Reduce el peso']) {
    testWidgets('selected execution retains historical day note ($locale, reply: $reply)', (tester) async {
      await sl.reset();
      final repository = _HistoricalNoteRepository(reply);
      final storage = _PageStorage()..pending = [
        {'id': 'execution-a', 'training_id': 'training-1',
         'assignment_date': '2026-09-05', 'status': 'pending'},
      ];
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
        locale: Locale(locale),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TrainingDetailPage(trainingId: 'training-1',
          selectedDate: '2026-09-05', selectedExecutionId: 'execution-a'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Me molestó la rodilla'), findsOneWidget);
      expect(find.text(locale == 'es'
          ? 'Nota histórica del día · Ejecución no identificada'
          : 'Historical day note · Execution attribution unavailable'), findsOneWidget);
      expect(find.text('Reduce el peso'), reply == null ? findsNothing : findsOneWidget);
      expect(find.text(locale == 'es' ? 'Tu nota' : 'Your note'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await sl.reset();
    });
    }
  }

  test('same-day executions retain only their own confirmed sets and legacy sets remain unattributed', () {
    final progress = parseTrainingDayProgress({
      'training_sessions': [
        {'training_session_id': 'execution-a', 'training_id': 'training-1', 'confirmed': true},
        {'training_session_id': 'execution-b', 'training_id': 'training-1', 'confirmed': true},
      ],
      'exercises_completed': [
        {'training_exercise_id': 'te-1', 'training_session_id': 'execution-a',
          'weight_used': 20, 'sets': [{'set_number': 1, 'reps': 8}]},
        {'training_exercise_id': 'te-1', 'training_session_id': 'execution-b',
          'weight_used': 40, 'sets': [{'set_number': 1, 'reps': 12}]},
        {'training_exercise_id': 'te-2', 'sets': [{'set_number': 1, 'reps': 15}]},
      ],
    });
    expect(progress.forSession('execution-a', 'training-1').performances['te-1']!.single.reps, 8);
    expect(progress.forSession('execution-b', 'training-1').performances['te-1']!.single.reps, 12);
    expect(progress.forSession('execution-b', 'training-1').ids, {'te-1'});
    expect(progress.forSession('execution-b', 'another-training').ids, isEmpty);
    expect(progress.forSession('new-execution', 'training-1').ids, isEmpty);
    expect(progress.forSession(null, 'training-1').ids, isEmpty);
  });
  testWidgets('detail shows selected same-day execution sets, not day aggregate or another execution', (tester) async {
    await sl.reset();
    final repository = _SessionProgressRepository()..requiresVideo = true;
    final storage = _PageStorage()..pending = [
      {'id': 'execution-a', 'training_id': 'training-1', 'assignment_date': '2026-09-05', 'status': 'pending'},
      {'id': 'execution-b', 'training_id': 'training-1', 'assignment_date': '2026-09-05', 'status': 'pending'},
    ];
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
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('8 reps'), findsNothing);
    expect(find.textContaining('12 reps'), findsNothing);
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('execution-b'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 reps'), findsWidgets);
    expect(find.textContaining('8 reps'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  testWidgets('required last-set videos allow confirmation only for the selected execution', (tester) async {
    await sl.reset();
    final repository = _DelayedCompletionRepository()..requiresVideo = true;
    final storage = _PageStorage()..pending = [
      {'id': 'execution-a', 'training_id': 'training-1', 'assignment_date': '2026-09-05'},
      {'id': 'execution-b', 'training_id': 'training-1', 'assignment_date': '2026-09-05'},
    ];
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
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    ));
    await tester.pumpAndSettle();
    storage.feedback = [
      for (final exerciseId in ['te-1', 'te-2'])
        {'id': 'other-$exerciseId', 'training_id': 'training-1',
          'training_exercise_id': exerciseId, 'assignment_date': '2026-09-05',
          'training_session_id': 'execution-a', 'feedback_kind': 'LAST_SET',
          'media_type': 'VIDEO', 'status': 'completed'},
    ];
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('execution-b'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
    storage.feedback = [
      for (final exerciseId in ['te-1', 'te-2'])
        {'id': 'video-$exerciseId', 'training_id': 'training-1',
          'training_exercise_id': exerciseId, 'assignment_date': '2026-09-05',
          'training_session_id': 'execution-b', 'feedback_kind': 'LAST_SET',
          'media_type': 'VIDEO', 'status': 'queued'},
    ];
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    await tester.tap(find.byKey(const Key('completion-rpe-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(repository.completedSessionId, 'execution-b');
    expect(repository.completedRpe, 10);
    expect(repository.completedNotes, isNull);
    repository.release.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  testWidgets('completion dialog starts with RPE unselected and sends exact note and RPE', (tester) async {
    await sl.reset();
    final repository = _DelayedCompletionRepository();
    final storage = _PageStorage();
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
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('completion-rpe-1')), findsOneWidget);
    expect(find.byKey(const Key('completion-rpe-selected')), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    expect(repository.calls, 0);
    await tester.tap(find.byKey(const Key('completion-rpe-1')));
    await tester.enterText(find.byKey(const Key('completion-note')), ' Hard session ');
    await tester.tap(find.byKey(const Key('cancel-complete-training')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('completion-rpe-selected')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(repository.completedRpe, 1);
    expect(repository.completedNotes, 'Hard session');
    repository.release.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });
  testWidgets('queued offline completion shows pending sync and never asks for RPE again', (tester) async {
    await sl.reset();
    final repository = _DelayedCompletionRepository();
    final storage = _PageStorage();
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
    Widget page() => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-rpe-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    storage.queued = true;
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pending sync'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('complete-training-button'))).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Pending sync'), findsOneWidget);
    expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'real completion flow cancels without dispatch and confirms once ($brightness)',
      (tester) async {
        await sl.reset();
        final repository = _DelayedCompletionRepository();
        sl.registerFactory<TrainingBloc>(
          () => TrainingBloc(
            getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
            getTrainingsUseCase: GetTrainingsUseCase(repository),
            getTrainingUseCase: GetTrainingUseCase(repository),
            markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(
              repository,
            ),
            unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(
              repository,
            ),
            completeTrainingUseCase: CompleteTrainingUseCase(repository),
            getCompletedExercisesUseCase: GetCompletedExercisesUseCase(
              repository,
            ),
            getPreviousExercisePerformancesUseCase:
                GetPreviousExercisePerformancesUseCase(repository),
          ),
        );
        sl.registerSingleton<LocalStorage>(_PageStorage());
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            locale: const Locale('es'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TrainingDetailPage(
              trainingId: 'training-1',
              selectedDate: '2026-09-05',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('complete-training-button')));
        await tester.pumpAndSettle();
        expect(repository.calls, 0);
        await tester.tap(find.byKey(const Key('cancel-complete-training')));
        await tester.pumpAndSettle();
        expect(repository.calls, 0);
        await tester.tap(find.byKey(const Key('complete-training-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('completion-rpe-10')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('confirm-complete-training')));
        await tester.pumpAndSettle();
        expect(repository.calls, 1);
        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('complete-training-button')),
        );
        expect(button.onPressed, isNull);
        repository.release.complete();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await sl.reset();
      },
    );
  }
  testWidgets('completion resumes the selected same-day execution', (tester) async {
    await sl.reset();
    final repository = _DelayedCompletionRepository();
    final storage = _PageStorage()..pending = [
      {'id': 'execution-a', 'training_id': 'training-1',
       'assignment_date': '2026-09-05', 'status': 'pending'},
      {'id': 'execution-b', 'training_id': 'training-1',
       'assignment_date': '2026-09-05', 'status': 'pending'},
    ];
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerFactory<TrainingBloc>(() => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase:
          GetPreviousExercisePerformancesUseCase(repository),
    ));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.text('Entrenamiento 1 · 2026-09-05'), findsNWidgets(2));
    await tester.tap(find.text('execution-b'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-rpe-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(repository.completedSessionId, 'execution-b');
    repository.release.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  testWidgets('account switch while execution picker is open cannot dispatch A draft as B', (tester) async {
    await sl.reset();
    final repository = _DelayedCompletionRepository();
    final storage = _PageStorage()..pending = [
      {'id': 'draft-a', 'training_id': 'training-1',
       'assignment_date': '2026-09-05', 'status': 'pending'},
    ];
    storage.stamp = 'A:1:test';
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerFactory<TrainingBloc>(() => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase:
          GetPreviousExercisePerformancesUseCase(repository),
    ));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(find.text('draft-a'), findsOneWidget);
    storage.stamp = 'B:2:test';
    await tester.tap(find.text('draft-a'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(storage.completed, isNull);
    expect(storage.pending.single['id'], 'draft-a');
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  testWidgets('account switch during completion keeps A draft and does not apply to B', (tester) async {
    await sl.reset();
    final repository = _DelayedCompletionRepository();
    final storage = _PageStorage()..stamp = 'A:1:test';
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerFactory<TrainingBloc>(() => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase:
          GetPreviousExercisePerformancesUseCase(repository),
    ));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrainingDetailPage(trainingId: 'training-1', selectedDate: '2026-09-05'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-rpe-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(repository.completedSessionId, 'execution-test');
    storage.stamp = 'B:2:test';
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(storage.completed, isNull);
    await tester.tap(find.byKey(const Key('complete-training-button')));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });

  test('A completion delivered after switching to B rejects without sending A sets', () async {
    await sl.reset();
    final storage = _PageStorage()..stamp = 'A:1:test';
    sl.registerSingleton<LocalStorage>(storage);
    final repository = _DelayedMarkRepository();
    final bloc = TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase: GetPreviousExercisePerformancesUseCase(repository),
    );
    final loaded = bloc.stream.firstWhere((state) => state is TrainingDetailLoaded);
    bloc.add(const TrainingDetailLoadRequested('training-1', date: '2026-09-05'));
    await loaded;
    final completion = Completer<void>();
    final rejected = expectLater(completion.future, throwsA(isA<LocalSessionChanged>()));
    storage.stamp = 'B:2:test';
    bloc.add(MarkExerciseCompleted(
      trainingExerciseId: 'te-1', exerciseId: 'ex-1', completed: true,
      sessionStamp: 'A:1:test', sets: const [SetPerformance(setNumber: 1, reps: 12)],
      completion: completion,
    ));
    await pumpEventQueue();
    expect(repository.calls, 0);
    expect(completion.isCompleted, isTrue, reason: 'stale operation must settle');
    await rejected;
    final unstamped = Completer<void>();
    final unstampedRejected = expectLater(
      unstamped.future, throwsA(isA<LocalSessionChanged>()));
    bloc.add(MarkExerciseCompleted(
      trainingExerciseId: 'te-1', exerciseId: 'ex-1', completed: true,
      sets: const [SetPerformance(setNumber: 1, reps: 12)],
      completion: unstamped,
    ));
    await unstampedRejected;
    expect(repository.calls, 0);
    await bloc.close();
    await sl.reset();
  });

  test('A response after switching to B cannot apply completion or clear A draft', () async {
    await sl.reset();
    final storage = _PageStorage()..stamp = 'A:1:test';
    storage.drafts['execution-a'] = {'sets': 12};
    sl.registerSingleton<LocalStorage>(storage);
    final repository = _DelayedMarkRepository();
    final bloc = TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase: GetPreviousExercisePerformancesUseCase(repository),
    );
    final loaded = bloc.stream.firstWhere((state) => state is TrainingDetailLoaded);
    bloc.add(const TrainingDetailLoadRequested('training-1', date: '2026-09-05'));
    await loaded;
    final completion = Completer<void>();
    final rejected = expectLater(completion.future, throwsA(isA<LocalSessionChanged>()));
    bloc.add(MarkExerciseCompleted(
      trainingExerciseId: 'te-1', exerciseId: 'ex-1', completed: true,
      sessionStamp: 'A:1:test', sets: const [SetPerformance(setNumber: 1, reps: 12)],
      completion: completion,
    ));
    await repository.started.future;
    storage.stamp = 'B:2:test';
    repository.release.complete();
    await pumpEventQueue();
    expect(completion.isCompleted, isTrue, reason: 'stale response must settle');
    await rejected;
    expect(storage.drafts['execution-a']?['sets'], 12);
    await bloc.close();
    await sl.reset();
  });

  test('unstamped completion rejects before repository write', () async {
    await sl.reset();
    final storage = _PageStorage()..stamp = 'B:2:test';
    sl.registerSingleton<LocalStorage>(storage);
    final repository = _FailingCompletionRepository();
    final bloc = TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase: GetPreviousExercisePerformancesUseCase(repository),
    );
    addTearDown(() async { await bloc.close(); await sl.reset(); });
    final loaded = bloc.stream.firstWhere((state) => state is TrainingDetailLoaded);
    bloc.add(const TrainingDetailLoadRequested('training-1', date: '2026-09-05'));
    await loaded;
    final completion = Completer<void>();
    final rejected = expectLater(completion.future, throwsA(isA<LocalSessionChanged>()));
    bloc.add(CompleteTrainingRequested(completion: completion));
    await pumpEventQueue();
    expect(repository.completedDate, isNull);
    expect(completion.isCompleted, isTrue);
    await rejected;
  });

  test('A completion delivered to B rejects before repository write', () async {
    await sl.reset();
    final storage = _PageStorage()..stamp = 'A:1:test';
    sl.registerSingleton<LocalStorage>(storage);
    final repository = _FailingCompletionRepository();
    final bloc = TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase: GetPreviousExercisePerformancesUseCase(repository),
    );
    addTearDown(() async { await bloc.close(); await sl.reset(); });
    final loaded = bloc.stream.firstWhere((state) => state is TrainingDetailLoaded);
    bloc.add(const TrainingDetailLoadRequested('training-1', date: '2026-09-05'));
    await loaded;
    final completion = Completer<void>();
    final rejected = expectLater(completion.future, throwsA(isA<LocalSessionChanged>()));
    storage.stamp = 'B:2:test';
    bloc.add(CompleteTrainingRequested(sessionStamp: 'A:1:test', completion: completion));
    await rejected;
    expect(repository.completedDate, isNull);
    expect((bloc.state as TrainingDetailLoaded).isCompleting, isFalse);
  });

  test('A completion response after B switch cannot update B state', () async {
    await sl.reset();
    final storage = _PageStorage()..stamp = 'A:1:test';
    sl.registerSingleton<LocalStorage>(storage);
    final repository = _DelayedCompletionRepository();
    final bloc = TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase: GetPreviousExercisePerformancesUseCase(repository),
    );
    addTearDown(() async { await bloc.close(); await sl.reset(); });
    final loaded = bloc.stream.firstWhere((state) => state is TrainingDetailLoaded);
    bloc.add(const TrainingDetailLoadRequested('training-1', date: '2026-09-05'));
    await loaded;
    final completion = Completer<void>();
    final rejected = expectLater(completion.future, throwsA(isA<LocalSessionChanged>()));
    bloc.add(CompleteTrainingRequested(sessionStamp: 'A:1:test', completion: completion));
    await repository.started.future;
    storage.stamp = 'B:2:test';
    repository.release.complete();
    await rejected;
    expect((bloc.state as TrainingDetailLoaded).isCompleting, isTrue,
        reason: 'stale response must not mutate current state');
  });

  test('concurrent complete commands share one in-flight operation', () async {
    await sl.reset();
    sl.registerSingleton<LocalStorage>(_PageStorage());
    final repository = _DelayedCompletionRepository();
    final bloc = TrainingBloc(
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
    );
    final loaded = bloc.stream.firstWhere(
      (state) => state is TrainingDetailLoaded,
    );
    bloc.add(
      const TrainingDetailLoadRequested('training-1', date: '2026-09-05'),
    );
    await loaded;
    bloc.add(const CompleteTrainingRequested(sessionStamp: 'isolated'));
    await repository.started.future;
    bloc.add(const CompleteTrainingRequested(sessionStamp: 'isolated'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 1);
    repository.release.complete();
    await bloc.close();
    await sl.reset();
  });
  test(
    'completion keeps selected date and exposes backend rejection',
    () async {
      await sl.reset();
      sl.registerSingleton<LocalStorage>(_PageStorage());
      addTearDown(sl.reset);
      final repository = _FailingCompletionRepository();
      final bloc = TrainingBloc(
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
      );
      addTearDown(bloc.close);

      final loaded = bloc.stream.firstWhere(
        (state) => state is TrainingDetailLoaded,
      );
      bloc.add(
        const TrainingDetailLoadRequested('training-1', date: '2026-09-05'),
      );
      await loaded;

      final failed = bloc.stream.firstWhere(
        (state) => state is TrainingDetailLoaded && state.errorMessage != null,
      );
      bloc.add(const CompleteTrainingRequested(sessionStamp: 'isolated'));
      final state = await failed as TrainingDetailLoaded;

      expect(repository.completedDate, '2026-09-05');
      expect(state.selectedDate, '2026-09-05');
      expect(state.errorMessage, 'Entrenamiento no asignado para esa fecha');
    },
  );
}

class _FailingCompletionRepository implements TrainingRepository {
  String? completedDate;

  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? sessionId,
    int? rpe,
    String? notes,
  }) async {
    completedDate = date;
    throw const ApiException(
      statusCode: 403,
      message: 'Entrenamiento no asignado para esa fecha',
    );
  }

  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      const TrainingDayProgress();

  @override
  Future<List<TrainingEntity>> getDayTrainings({String? date}) async =>
      const [];

  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => <String, List<SetPerformance>>{};

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      const TrainingEntity(
        id: 'training-1',
        name: 'Entrenamiento 1',
        types: ['FUERZA'],
        level: 'INTERMEDIATE',
        tags: [],
        exercises: [],
      );

  @override
  Future<List<TrainingHistoryEntity>> getTrainings({String? date}) async =>
      const [];

  @override
  Future<TrainingEntity?> getTodayTraining({String? date}) async => null;

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
  Future<void> unmarkExerciseCompleted(
    String trainingExerciseId,
    String date, {String? sessionId}
  ) async {}
}

class _HistoricalNoteRepository extends _FailingCompletionRepository {
  _HistoricalNoteRepository(this.reply);
  final String? reply;

  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      TrainingDayProgress(note: 'Me molestó la rodilla', adminReplyText: reply);
}

class _DelayedMarkRepository extends _FailingCompletionRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  int calls = 0;

  @override
  Future<void> markExerciseCompleted(
    String trainingExerciseId, String exerciseId, String date, {
    double? weightUsed, List<SetPerformance>? sets,
    String? lastSetFeedbackClientUploadId, String? trainingId,
    String? sessionId, String? operationId,
  }) async {
    calls++;
    started.complete();
    await release.future;
  }
}

class _DelayedCompletionRepository extends _FailingCompletionRepository {
  bool requiresVideo = false;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      requiresVideo ? const TrainingEntity(
        id: 'training-1', name: 'Entrenamiento 1', types: ['FUERZA'],
        level: 'INTERMEDIATE', tags: [], requiresLastSetVideo: true,
        exercises: [
          TrainingExerciseEntity(id: 'te-1', order: 1, sets: 1,
            repsOrDuration: '10', restSeconds: 30,
            exercise: ExerciseEntity(id: 'ex-1', name: 'Exercise 1', muscleGroups: [])),
          TrainingExerciseEntity(id: 'te-2', order: 2, sets: 1,
            repsOrDuration: '10', restSeconds: 30,
            exercise: ExerciseEntity(id: 'ex-2', name: 'Exercise 2', muscleGroups: [])),
        ],
      ) : super.getTraining(id, date: date);
  final started = Completer<void>();
  final release = Completer<void>();
  int calls = 0;
  String? completedSessionId;
  String? completedNotes;
  int? completedRpe;
  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? sessionId,
    String? notes,
    int? rpe,
  }) async {
    completedSessionId = sessionId;
    completedNotes = notes;
    completedRpe = rpe;
    calls++;
    if (!started.isCompleted) started.complete();
    await release.future;
  }
}

class _SessionProgressRepository extends _DelayedCompletionRepository {
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      parseTrainingDayProgress({
        'training_sessions': [
          {'training_session_id': 'execution-a', 'training_id': 'training-1'},
          {'training_session_id': 'execution-b', 'training_id': 'training-1'},
        ],
        'exercises_completed': [
          {'training_exercise_id': 'te-1', 'training_session_id': 'execution-a',
           'sets': [{'set_number': 1, 'reps': 8}]},
          {'training_exercise_id': 'te-1', 'training_session_id': 'execution-b',
           'sets': [{'set_number': 1, 'reps': 12}]},
        ],
      });
}

class _PageStorage extends LocalStorage {
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) => null;
  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(String trainingId, String exerciseId, String date) => null;
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  String stamp = 'isolated';
  @override
  String? get sessionStamp => stamp;
  List<Map<String, dynamic>> pending = [];
  final drafts = <String, Map<String, dynamic>>{};
  String? completed;
  bool queued = false;
  List<Map<String, dynamic>> feedback = [];
  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() => feedback;
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(String trainingId, String date, String executionId) => drafts[executionId];
  @override
  Future<void> saveTrainingCompletionDraft(String trainingId, String date, String executionId, {int? rpe, String? notes}) async {
    drafts[executionId] = {'rpe': ?rpe, if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim()};
  }
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) => completed != null;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => queued ? [{
    'type': 'complete_training', 'training_id': 'training-1', 'date': '2026-09-05',
    'training_session_id': 'execution-test', 'status': 'queued',
  }] : [];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(String trainingId, String date) => pending;
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(String trainingId, String date) =>
      completed == null ? [] : pending
          .where((entry) => entry['id'] == completed &&
              entry['training_id'] == trainingId &&
              entry['assignment_date'] == date)
          .map((entry) => {...entry, 'status': 'completed'})
          .toList();
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => pending;
  @override
  Future<String> createTrainingExecution(String trainingId, String date, {String? trainingName}) async => 'execution-test';
  @override
  Future<void> completeTrainingExecution(String id) async { completed = id; }

  final notifier = ValueNotifier<Box<ActiveWorkoutHiveModel>>(
    _EmptyWorkoutBox(),
  );
  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() => notifier;
}

class _EmptyWorkoutBox extends Fake implements Box<ActiveWorkoutHiveModel> {}
