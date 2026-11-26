// L5-E6a «Sesión terminada» (docs/plans/rediseno-app-l5-contrato-v2.md,
// bloque E, and plan decision L5-D22): once the server confirms the session
// completion with the detail open, the detail pushes the milestone «Sesión
// hecha» instead of going straight to Inicio. The milestone has no RPE, no note
// and nothing editable; it only appears after the server confirmation (the same
// conditions that led to Inicio before: execution `confirmed`, no pending
// action, no completion blocker, same session). Queued, offline, failed or
// errored completions keep today's behaviour (no milestone, the detail stays).
// «Volver a Inicio», the close icon and the system back all do today's
// navigation (`router.go(home, extra: HomeCompletionRefresh())`) once; a
// session change with the milestone open closes it without navigating. It
// enters with the existing push transition (M1), a 100 ms fade with reduced
// motion. L5-E6b adds its own animation (group at the end): a touch skips it,
// the exits work from 300 ms and reduced motion is a 150 ms fade.
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart'
    show HomeCompletionRefresh;
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
import 'package:exom_app/features/trainings/presentation/pages/training_milestone_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart'
    show expectTapTargetGuidelines;
import '../../../../core/widgets/expect_no_lime_ink.dart';

const _date = '2026-09-05';
const _execution = 'execution-1';
const _trainingId = 'training-1';
const _owner = 'owner:1:test';

/// The two-exercise session (3 + 4 planned sets) under [name].
TrainingEntity _trainingNamed(String name) => TrainingEntity(
  id: _trainingId,
  name: name,
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  tags: const [],
  exercises: const [
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: 3,
      repsOrDuration: '8',
      restSeconds: 90,
      exercise: ExerciseEntity(
        id: 'ex-1',
        name: 'Sentadilla búlgara',
        muscleGroups: [],
      ),
    ),
    TrainingExerciseEntity(
      id: 'te-2',
      order: 2,
      sets: 4,
      repsOrDuration: '10',
      restSeconds: 60,
      exercise: ExerciseEntity(id: 'ex-2', name: 'Peso muerto', muscleGroups: []),
    ),
  ],
);

/// What the repository does when the completion reaches it.
enum _Outcome {
  /// The server confirms at once (online).
  confirmed,

  /// Accepted locally and queued (offline): the execution is `pending-sync`
  /// with a queued `complete_training` action.
  queued,

  /// The save fails.
  error,
}

/// One `completeTraining` call that reached the repository.
typedef _Completion = ({String? sessionId, int? rpe, String? notes});

class _Storage extends LocalStorage {
  String? stamp = _owner;
  String status = 'pending';
  bool actionQueued = false;
  final Map<String, Map<String, dynamic>> completionDrafts = {};

  @override
  String? get sessionStamp => stamp;
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => actionQueued
      ? [
          {
            'type': 'complete_training',
            'training_id': _trainingId,
            'date': _date,
            'training_session_id': _execution,
            'status': 'queued',
          },
        ]
      : const [];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => [
    {
      'id': _execution,
      'training_id': _trainingId,
      'assignment_date': _date,
      'status': status,
    },
  ];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(
    String trainingId,
    String date,
  ) => getPendingTrainingExecutions();
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => getPendingTrainingExecutions()
      .where(
        (entry) => const ['confirmed', 'completed'].contains(entry['status']),
      )
      .toList();
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) =>
      const ['confirmed', 'completed'].contains(status);
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId,
  ) {
    final draft = completionDrafts[executionId];
    return draft == null ? null : Map<String, dynamic>.from(draft);
  }

  @override
  Future<void> saveTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId, {
    int? rpe,
    String? notes,
  }) async {
    completionDrafts[executionId] = {
      'training_id': trainingId,
      'assignment_date': date,
      'rpe': ?rpe,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
  }

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
  final events = StreamController<void>.broadcast();
  CompletionSyncBlocker? blocker;
  int retries = 0;
  void Function()? onRetry;

  @override
  Stream<void> get changes => events.stream;
  void notify() => events.add(null);
  @override
  CompletionSyncBlocker? completionBlocker(
    String trainingId,
    String date,
    String? sessionId,
  ) => blocker;
  @override
  Future<void> retryAction(String id) async {
    retries++;
    onRetry?.call();
  }
}

/// Only the notice stream: the detail listens to it to re-check a completion.
class _FeedbackQueue extends Fake implements FeedbackUploadQueueService {
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
}

class _Repository extends Fake implements TrainingRepository {
  _Repository(this.storage, this.training);

  final _Storage storage;
  final TrainingEntity training;
  _Outcome outcome = _Outcome.confirmed;
  final List<_Completion> completions = [];

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      training;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      const TrainingDayProgress(
        sessions: {
          _execution: TrainingDayProgress(ids: {'te-1', 'te-2'}),
        },
        sessionTrainings: {_execution: _trainingId},
      );
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => const {};
  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? sessionId,
    int? rpe,
    String? notes,
  }) async {
    completions.add((sessionId: sessionId, rpe: rpe, notes: notes));
    switch (outcome) {
      case _Outcome.confirmed:
        storage
          ..status = 'confirmed'
          ..actionQueued = false;
      case _Outcome.queued:
        storage
          ..status = 'pending-sync'
          ..actionQueued = true;
      case _Outcome.error:
        throw StateError('save failed');
    }
  }
}

class _Harness {
  _Harness(this.storage, this.repository, this.sync);
  final _Storage storage;
  final _Repository repository;
  final _Sync sync;
  int homeVisits = 0;
  Object? homeExtra;
}

Future<_Harness> _mount(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  bool reducedMotion = false,
  Locale locale = const Locale('es'),
  String trainingName = 'Pierna fuerza',
  void Function(_Storage storage, _Sync sync)? seed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage();
  final sync = _Sync(storage);
  seed?.call(storage, sync);
  final repository = _Repository(storage, _trainingNamed(trainingName));
  final harness = _Harness(storage, repository, sync);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(sync);
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
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) {
          harness.homeVisits++;
          harness.homeExtra = state.extra;
          return const Scaffold(body: Text('home-destination'));
        },
      ),
      GoRoute(
        path: '/detail',
        builder: (_, _) => const TrainingDetailPage(
          trainingId: _trainingId,
          selectedDate: _date,
          selectedExecutionId: _execution,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await sync.events.close();
    await sl.reset();
  });
  return harness;
}

final _completeButton = find.byKey(const Key('complete-training-button'));
final _sheet = find.byKey(const Key('complete-training-confirmation'));
final _confirm = find.byKey(const Key('confirm-complete-training'));
final _milestone = find.byKey(const Key('training-milestone'));
final _continue = find.byKey(const Key('training-milestone-continue'));
final _close = find.byKey(const Key('training-milestone-close'));

Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Opens the closing sheet, picks RPE 8 and confirms (E2b flow, unchanged).
Future<void> _completeWithRpe(WidgetTester tester, {bool settle = true}) async {
  await _tapIn(tester, _completeButton);
  await tester.pumpAndSettle();
  expect(_sheet, findsOneWidget);
  await _tapIn(tester, find.byKey(const Key('completion-rpe-8')));
  await tester.tap(_confirm);
  if (settle) await tester.pumpAndSettle();
}

/// The milestone after a server-confirmed completion of the two-exercise
/// session, for the goldens (`test/golden/l5_e6a_hito_sesion_golden_test.dart`)
/// and the overflow sweep (`test/l10n/long_string_overflow_test.dart`).
Future<void> pumpMilestone(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  String trainingName = 'Pierna fuerza',
}) async {
  await _mount(
    tester,
    brightness: brightness,
    size: size,
    textScaler: textScaler,
    locale: locale,
    trainingName: trainingName,
  );
  await _completeWithRpe(tester);
  expect(_milestone, findsOneWidget);
}

void main() {
  group('only a server-confirmed completion shows the milestone', () {
    testWidgets('confirmed with the detail open: milestone, not Inicio', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _completeWithRpe(tester);

      expect(_milestone, findsOneWidget);
      expect(harness.homeVisits, 0, reason: 'Inicio only after «Volver»');
      expect(_sheet, findsNothing);
      // Same CompleteTrainingRequested as today (E2b): one call, RPE and note.
      expect(harness.repository.completions, [
        (sessionId: _execution, rpe: 8, notes: null),
      ]);
    });

    testWidgets('queued offline: no milestone; the replay confirmation with '
        'the detail open shows it', (tester) async {
      final harness = await _mount(tester);
      harness.repository.outcome = _Outcome.queued;
      await _completeWithRpe(tester);

      expect(_milestone, findsNothing);
      expect(harness.homeVisits, 0);
      expect(_completeButton, findsOneWidget, reason: 'stays in the detail');

      // Still queued: another sync event changes nothing.
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(_milestone, findsNothing);

      // The queue replays and the server confirms.
      harness.storage
        ..status = 'confirmed'
        ..actionQueued = false;
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(_milestone, findsOneWidget);
      expect(harness.homeVisits, 0);
      expect(harness.repository.completions, hasLength(1));
    });

    testWidgets('a feedback upload notice that finds the completion confirmed '
        'opens the milestone', (tester) async {
      final queue = _FeedbackQueue();
      addTearDown(queue.events.close);
      final harness = await _mount(
        tester,
        seed: (_, _) => sl.registerSingleton<FeedbackUploadQueueService>(queue),
      );
      harness.repository.outcome = _Outcome.queued;
      await _completeWithRpe(tester);
      expect(_milestone, findsNothing);

      // The server confirmed while only the feedback queue reported.
      harness.storage
        ..status = 'confirmed'
        ..actionQueued = false;
      queue.events.add(
        const FeedbackUploadNotice('f', FeedbackUploadNoticeKind.completed),
      );
      await tester.pumpAndSettle();
      expect(_milestone, findsOneWidget);
      expect(harness.homeVisits, 0);
      // Another notice does not stack a second milestone.
      queue.events.add(
        const FeedbackUploadNotice('f', FeedbackUploadNoticeKind.completed),
      );
      await tester.pumpAndSettle();
      expect(_milestone, findsOneWidget);
      expect(harness.repository.completions, hasLength(1));
    });

    testWidgets('a confirmation with a completion blocker shows nothing', (
      tester,
    ) async {
      final harness = await _mount(tester);
      harness.repository.outcome = _Outcome.queued;
      await _completeWithRpe(tester);
      harness.storage
        ..status = 'confirmed'
        ..actionQueued = false;
      harness.sync.blocker = const CompletionSyncBlocker(
        CompletionSyncBlockerKind.feedbackWaiting,
      );
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(_milestone, findsNothing);
      expect(harness.homeVisits, 0);
    });

    testWidgets('a save error shows no milestone and keeps the detail', (
      tester,
    ) async {
      final harness = await _mount(tester);
      harness.repository.outcome = _Outcome.error;
      await _completeWithRpe(tester);
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(_milestone, findsNothing);
      expect(harness.homeVisits, 0);
      expect(_completeButton, findsOneWidget);
    });

    testWidgets('failed, then retry: milestone only once the server '
        'confirms', (tester) async {
      final harness = await _mount(
        tester,
        seed: (storage, sync) {
          storage
            ..status = 'failed'
            ..completionDrafts[_execution] = {
              'training_id': _trainingId,
              'assignment_date': _date,
              'rpe': 7,
            };
          sync
            ..blocker = const CompletionSyncBlocker(
              CompletionSyncBlockerKind.failed,
              retryActionId: 'retry-action',
            )
            ..onRetry = () {
              storage
                ..status = 'pending-sync'
                ..actionQueued = true;
              sync
                ..blocker = null
                ..notify();
            };
        },
      );
      await _tapIn(tester, _completeButton);
      await tester.pumpAndSettle();
      expect(harness.sync.retries, 1);
      expect(_sheet, findsNothing, reason: 'a retry never reopens the sheet');
      expect(_milestone, findsNothing, reason: 'queued again, not confirmed');

      harness.storage
        ..status = 'confirmed'
        ..actionQueued = false;
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(_milestone, findsOneWidget);
      expect(harness.repository.completions, isEmpty);
    });

    testWidgets('another account confirming does not open it', (tester) async {
      final harness = await _mount(tester);
      harness.repository.outcome = _Outcome.queued;
      await _completeWithRpe(tester);
      harness.storage
        ..stamp = 'other:2:test'
        ..status = 'confirmed'
        ..actionQueued = false;
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(_milestone, findsNothing);
      expect(harness.homeVisits, 0);
    });
  });

  group('milestone content', () {
    testWidgets('celebration and summary: no RPE, no note, nothing editable', (
      tester,
    ) async {
      await _mount(tester);
      await _completeWithRpe(tester);
      expect(_milestone, findsOneWidget);

      Finder inMilestone(Finder matching) =>
          find.descendant(of: _milestone, matching: matching);
      expect(inMilestone(find.text('SESIÓN HECHA.')), findsOneWidget);
      expect(inMilestone(find.text('PIERNA FUERZA.')), findsOneWidget);
      // One header in the original case for assistive technology.
      expect(
        inMilestone(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.header == true &&
                widget.properties.label == 'Sesión hecha. Pierna fuerza.',
          ),
        ),
        findsOneWidget,
      );
      // Exercises and planned sets of the session (3 + 4), data the detail
      // already shows; no duration and no best set (D15).
      expect(inMilestone(find.text('ejercicios')), findsOneWidget);
      expect(inMilestone(find.text('series')), findsOneWidget);
      expect(inMilestone(find.text('2')), findsOneWidget);
      expect(inMilestone(find.text('7')), findsOneWidget);
      // Server state: «Confirmada» (D19).
      final status = tester.widget<ExomSyncStatus>(
        inMilestone(find.byType(ExomSyncStatus)),
      );
      expect(status.state, ExomSyncState.confirmada);
      // L5-D22: neither RPE nor note, not even read-only; nothing editable.
      expect(inMilestone(find.textContaining('RPE')), findsNothing);
      expect(inMilestone(find.textContaining('8')), findsNothing);
      expect(inMilestone(find.byType(EditableText)), findsNothing);
      expect(inMilestone(find.byType(TextField)), findsNothing);
      expect(inMilestone(find.byKey(const Key('completion-rpe-8'))),
          findsNothing);
      expect(inMilestone(find.text('VOLVER A INICIO')), findsOneWidget);
      // ExomIcons only.
      final close = tester.widget<Icon>(
        find.descendant(of: _close, matching: find.byType(Icon)),
      );
      expect(close.icon, ExomIcons.close);
    });

    for (final brightness in Brightness.values) {
      testWidgets('D19 and CC 4, ${brightness.name}', (tester) async {
        await _mount(tester, brightness: brightness);
        await _completeWithRpe(tester);
        expect(_milestone, findsOneWidget);
        final palette = (brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light)
            .extension<ExomThemePalette>()!;
        final statusText = tester.widget<Text>(
          find.descendant(
            of: find.byType(ExomSyncStatus),
            matching: find.text('Confirmada'),
          ),
        );
        expect(statusText.style?.color, palette.textPrimary,
            reason: '«Confirmada» in the text colour, never lime');
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectTapTargetGuidelines(tester);
        if (brightness == Brightness.light) {
          expectNoLimeInk(tester, root: _milestone, brightness: brightness);
        }
      });
    }

    testWidgets('at 2.0x (Android nonlinear) on 320 dp everything is '
        'reachable', (tester) async {
      final harness = await _mount(
        tester,
        size: const Size(320, 640),
        textScaler: const AndroidNonlinearTextScaler(2.0),
      );
      await _completeWithRpe(tester);
      expect(_milestone, findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final finder in [
        find.text('SESIÓN HECHA.'),
        find.text('series'),
        find.byType(ExomSyncStatus),
        _continue,
      ]) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(finder.hitTestable(), findsOneWidget);
      }
      await tester.tap(_continue);
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
    });
  });

  group('milestone route announcement', () {
    testWidgets('the headline names the route for TalkBack', (tester) async {
      await _mount(tester);
      await _completeWithRpe(tester);
      final headline = find.descendant(
        of: _milestone,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.header == true &&
              widget.properties.label == 'Sesión hecha. Pierna fuerza.',
        ),
      );
      expect(headline, findsOneWidget);
      final properties = tester.widget<Semantics>(headline).properties;
      expect(properties.namesRoute, isTrue);
      expect(properties.header, isTrue);
    });
  });

  group('leaving the milestone', () {
    testWidgets('«Volver a Inicio» goes to Inicio once with the refresh, '
        'even on a double tap', (tester) async {
      final harness = await _mount(tester);
      await _completeWithRpe(tester);
      await tester.tap(_continue);
      await tester.tap(_continue, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
      expect(harness.homeExtra, isA<HomeCompletionRefresh>());
      // What the server confirmed, so Inicio can paint it at once.
      final refresh = harness.homeExtra! as HomeCompletionRefresh;
      expect(refresh.trainingId, _trainingId);
      expect(refresh.date, _date);
      expect(refresh.sessionStamp, _owner);
      expect(_milestone, findsNothing);
      expect(find.byType(TrainingDetailPage), findsNothing);
      expect(find.text('home-destination'), findsOneWidget);
      // A late sync event does not navigate again.
      harness.sync.notify();
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
      expect(harness.repository.completions, hasLength(1));
    });

    testWidgets('system back then a tap on «Volver a Inicio»: one navigation', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _completeWithRpe(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(_continue, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
      expect(harness.homeExtra, isA<HomeCompletionRefresh>());
      expect(_milestone, findsNothing);
      expect(harness.repository.completions, hasLength(1));
    });

    testWidgets('the close icon does the same navigation', (tester) async {
      final harness = await _mount(tester);
      await _completeWithRpe(tester);
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
      expect(harness.homeExtra, isA<HomeCompletionRefresh>());
      expect(_milestone, findsNothing);
    });

    testWidgets('system back goes to Inicio once, never back to the sheet '
        'or the detail', (tester) async {
      final harness = await _mount(tester);
      await _completeWithRpe(tester);
      expect(_milestone, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
      expect(harness.homeExtra, isA<HomeCompletionRefresh>());
      expect(_milestone, findsNothing);
      expect(_sheet, findsNothing);
      expect(find.byType(TrainingDetailPage), findsNothing);
      expect(harness.repository.completions, hasLength(1));
    });

    for (final action in ['continue', 'back']) {
      testWidgets('a session change with the milestone open closes it '
          'without navigating ($action)', (tester) async {
        final harness = await _mount(tester);
        await _completeWithRpe(tester);
        expect(_milestone, findsOneWidget);
        harness.storage.stamp = 'other:2:test';
        if (action == 'continue') {
          await tester.tap(_continue);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(_milestone, findsNothing);
        expect(harness.homeVisits, 0);
        expect(harness.repository.completions, hasLength(1));
      });
    }

    testWidgets('reduced motion: the existing reduced push fade, and the '
        'action works from 300 ms', (tester) async {
      final harness = await _mount(tester, reducedMotion: true);
      await _completeWithRpe(tester, settle: false);
      // Let the sheet close and the completion resolve, frame by frame, until
      // the milestone is pushed.
      for (var i = 0; i < 60 && _milestone.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_milestone, findsOneWidget);
      await tester.pump(ExomMotion.reducedScreen);
      // Fully opaque and not offset after the reduced fade, while the route
      // itself is still running (M1 fixed duration).
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: _milestone, matching: find.byType(FadeTransition)),
      );
      for (final fade in fades) {
        expect(fade.opacity.value, 1);
      }
      final slides = tester.widgetList<SlideTransition>(
        find.ancestor(of: _milestone, matching: find.byType(SlideTransition)),
      );
      for (final slide in slides) {
        expect(slide.position.value, Offset.zero);
      }
      // L5-E6b: the exits work from 300 ms after the milestone opens, with
      // reduced motion too; a tap before only jumps to the final pose.
      await tester.tap(_continue);
      await tester.pump();
      expect(harness.homeVisits, 0);
      await tester.pump(ExomMotion.milestoneInteractiveAfter);
      await tester.tap(_continue);
      await tester.pumpAndSettle();
      expect(harness.homeVisits, 1);
    });
  });

  group('TrainingMilestonePage alone', () {
    /// Pushes the milestone over a launcher page and returns how many times
    /// it asked to continue.
    Future<List<int>> pumpAlone(
      WidgetTester tester, {
      required bool Function() isSameSession,
    }) async {
      final continues = [0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TrainingMilestonePage(
                      trainingName: 'Pierna fuerza',
                      exercises: 2,
                      sets: 7,
                      isSameSession: isSameSession,
                      onContinue: () => continues[0]++,
                    ),
                  ),
                ),
                child: const Text('launcher'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('launcher'));
      await tester.pumpAndSettle();
      expect(_milestone, findsOneWidget);
      return continues;
    }

    for (final action in ['continue', 'close', 'back']) {
      testWidgets('repeated $action asks to continue once', (tester) async {
        final continues = await pumpAlone(tester, isSameSession: () => true);
        for (var i = 0; i < 3; i++) {
          switch (action) {
            case 'continue':
              await tester.tap(_continue);
            case 'close':
              await tester.tap(_close);
            default:
              await tester.binding.handlePopRoute();
          }
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(continues.single, 1);
        // It does not pop itself: the caller's navigation replaces it.
        expect(_milestone, findsOneWidget);
      });
    }

    testWidgets('another session: closes without asking to continue', (
      tester,
    ) async {
      final continues = await pumpAlone(tester, isSameSession: () => false);
      await tester.tap(_continue);
      await tester.pumpAndSettle();
      expect(continues.single, 0);
      expect(_milestone, findsNothing);
      expect(find.text('launcher'), findsOneWidget);
    });
  });

  group('milestone animation (L5-E6b)', () {
    /// The milestone as the home page (no route transition), so its own
    /// animation starts at the first frame. Returns how many times it asked to
    /// continue.
    Future<List<int>> pumpAnimated(
      WidgetTester tester, {
      bool reducedMotion = false,
      bool tickers = true,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final continues = [0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: TickerMode(enabled: tickers, child: child!),
          ),
          home: TrainingMilestonePage(
            trainingName: 'Pierna fuerza',
            exercises: 2,
            sets: 7,
            isSameSession: () => true,
            onContinue: () => continues[0]++,
          ),
        ),
      );
      // The frame that starts the clock of the milestone's tickers.
      await tester.pump();
      return continues;
    }

    Finder inMilestone(Finder matching) =>
        find.descendant(of: _milestone, matching: matching);

    /// Final pose: the figures at their value and the headline as one plain
    /// text per line (no letter copies left).
    void expectFinal(WidgetTester tester) {
      expect(inMilestone(find.text('2')), findsOneWidget);
      expect(inMilestone(find.text('7')), findsOneWidget);
      expect(inMilestone(find.text('SESIÓN HECHA.')), findsOneWidget);
      expect(inMilestone(find.text('PIERNA FUERZA.')), findsOneWidget);
    }

    testWidgets('the whole animation lasts at most 900 ms', (tester) async {
      expect(
        ExomMotionSpec.standard.milestoneTotal,
        lessThanOrEqualTo(const Duration(milliseconds: 900)),
      );
      await pumpAnimated(tester);
      await tester.pump(const Duration(milliseconds: 450));
      // Still moving half way: the figures are counting and the first line
      // is drawn once per letter (12 visible letters in «SESIÓN HECHA.»).
      expect(inMilestone(find.text('7')), findsNothing);
      expect(inMilestone(find.text('SESIÓN HECHA.')), findsNWidgets(12));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 450));
      // Final pose at 900 ms; the ticker stops on the next frame.
      expectFinal(tester);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap anywhere jumps to the final state', (tester) async {
      final continues = await pumpAnimated(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(inMilestone(find.text('7')), findsNothing);
      // An empty spot of the body, away from every control.
      await tester.tapAt(const Offset(200, 600));
      await tester.pump();
      expectFinal(tester);
      // It stays there: nothing resumes.
      await tester.pump(const Duration(milliseconds: 100));
      expectFinal(tester);
      expect(continues.single, 0, reason: 'the skip never navigates');
    });

    testWidgets('«Volver a Inicio» works from 300 ms; before, a tap only '
        'jumps to the end', (tester) async {
      final continues = await pumpAnimated(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 0, reason: 'ignored before 300 ms');
      expectFinal(tester);
      // The close icon and the system back are exits too: also held.
      await tester.tap(_close);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 50));
      expect(continues.single, 0);
      // 300 ms after the milestone opened (the skip does not shorten it).
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 1);
    });

    testWidgets('reduced motion: a 150 ms fade to the final values', (
      tester,
    ) async {
      final continues = await pumpAnimated(tester, reducedMotion: true);
      final fade = inMilestone(
        find.byKey(const Key('training-milestone-reduced-fade')),
      );
      expect(fade, findsOneWidget);
      // Figures at their value from the first frame; no sweep, no letters.
      expect(inMilestone(find.text('7')), findsOneWidget);
      expect(inMilestone(find.text('SESIÓN HECHA.')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 75));
      final half = tester.widget<FadeTransition>(fade).opacity.value;
      expect(half, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 75));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      expectFinal(tester);
      // The exits keep the same 300 ms guard as the full animation.
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 0);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 1, reason: 'usable from 300 ms');
    });

    testWidgets('a tap at 350 ms navigates', (tester) async {
      final continues = await pumpAnimated(tester);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 1);
    });

    testWidgets('a tap at 100 ms and another at 400 ms navigate once', (
      tester,
    ) async {
      final continues = await pumpAnimated(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 0, reason: 'the early tap only skips');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 1);
      // A repeated tap on the same exit never navigates twice.
      await tester.tap(_continue);
      await tester.pump();
      expect(continues.single, 1);
    });

    group('with the platform «remove animations» setting', () {
      // `SemanticsBinding.disableAnimations` makes Flutter scale a controller
      // with the normal behaviour by 0.05; the gate and the fade must keep
      // their real duration.
      Future<List<int>> pumpPlatformReduced(WidgetTester tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        return pumpAnimated(tester, reducedMotion: true);
      }

      testWidgets('the 300 ms guard holds: 100 ms no, 300 ms yes', (
        tester,
      ) async {
        final continues = await pumpPlatformReduced(tester);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(_continue);
        await tester.pump();
        expect(continues.single, 0, reason: 'ignored at 100 ms');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(_continue);
        await tester.pump();
        expect(continues.single, 1, reason: 'usable at 300 ms');
      });

      testWidgets('the fade lasts 150 ms', (tester) async {
        await pumpPlatformReduced(tester);
        final fade = inMilestone(
          find.byKey(const Key('training-milestone-reduced-fade')),
        );
        await tester.pump(const Duration(milliseconds: 75));
        expect(
          tester.widget<FadeTransition>(fade).opacity.value,
          inExclusiveRange(0, 1),
          reason: 'still fading half way',
        );
        await tester.pump(const Duration(milliseconds: 75));
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      });
    });

    testWidgets('TickerMode off holds the animation; disposing mid-way is '
        'clean', (tester) async {
      await pumpAnimated(tester, tickers: false);
      await tester.pump(const Duration(seconds: 1));
      expect(
        inMilestone(find.text('7')),
        findsNothing,
        reason: 'muted ticker: nothing advances',
      );
      await pumpAnimated(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
