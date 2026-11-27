// FB1: a failed mandatory last-set video no longer blocks «Completar
// entreno» without explanation. The detail names the exercises whose video is
// missing, failed or pending, shows each video's state on its row and offers
// «Volver a grabar» for a failed one.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import 'last_set_video_test_support.dart' show mockVideoPicker;

const _date = '2026-09-05';
const _execution = 'execution-1';
const _trainingId = 'training-1';
const _stamp = 'owner:1:test';

TrainingExerciseEntity _exercise(int order, String name) =>
    TrainingExerciseEntity(
      id: 'te-$order',
      order: order,
      sets: 3,
      repsOrDuration: '8',
      restSeconds: 90,
      exercise: ExerciseEntity(id: 'ex-$order', name: name, muscleGroups: []),
    );

TrainingExerciseEntity _member(int order, String name, int position) =>
    TrainingExerciseEntity(
      id: 'te-$order',
      order: order,
      sets: 3,
      repsOrDuration: '10',
      restSeconds: 30,
      blockId: 'block-1',
      positionInBlock: position,
      blockName: 'Circuito core',
      blockRounds: 2,
      restBetweenRoundsSeconds: 45,
      exercise: ExerciseEntity(id: 'ex-$order', name: name, muscleGroups: []),
    );

final _training = TrainingEntity(
  id: _trainingId,
  name: 'Pierna',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  tags: const [],
  requiresLastSetVideo: true,
  exercises: [
    _exercise(1, 'Sentadilla búlgara'),
    _exercise(2, 'Peso muerto rumano'),
  ],
);

final _circuit = TrainingEntity(
  id: _trainingId,
  name: 'Core',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  tags: const [],
  requiresLastSetVideo: true,
  exercises: [_member(1, 'Crunch', 0), _member(2, 'Plancha', 1)],
);

Map<String, dynamic> _video(String id, String trainingExercise, String status,
        {String? error, int? http}) => {
      'id': id,
      'training_id': _trainingId,
      'assignment_date': _date,
      'training_session_id': _execution,
      'training_exercise_id': trainingExercise,
      'feedback_kind': 'LAST_SET',
      'media_type': 'VIDEO',
      'status': status,
      'last_error': ?error,
      'last_http_status': ?http,
    };

class _Storage extends LocalStorage {
  String stamp = _stamp;
  List<Map<String, dynamic>> feedback = [];
  List<Map<String, dynamic>> actions = [];

  @override
  String? get sessionStamp => stamp;
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [...actions];
  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() =>
      [for (final row in feedback) Map<String, dynamic>.from(row)];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(
    String trainingId,
    String date,
  ) => getPendingTrainingExecutions();
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => const [
    {
      'id': _execution,
      'training_id': _trainingId,
      'assignment_date': _date,
      'status': 'pending',
    },
  ];
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) => false;
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId,
  ) => null;
  @override
  Future<void> saveTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId, {
    int? rpe,
    String? notes,
  }) async {}
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
}

class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _Sync extends OfflineSyncService {
  _Sync(LocalStorage storage) : super(ApiClient(useAuth: false), storage);
  final controller = StreamController<void>.broadcast();
  CompletionSyncBlockerKind? kind;

  /// COLA r3: the wait reason of each queued action, by id (the rule itself
  /// is covered by `progress_feedback_wait_test.dart`).
  final waits = <String, ProgressFeedbackWait>{};
  @override
  ProgressFeedbackWait? feedbackWaitOf(Map<String, dynamic> action) =>
      waits[action['id']];
  @override
  Stream<void> get changes => controller.stream;
  @override
  CompletionSyncBlocker? completionBlocker(
    String trainingId,
    String date,
    String? sessionId,
  ) => kind == null ? null : CompletionSyncBlocker(kind!);
}

typedef _Replace = ({String id, String path, String? expectedSession});

class _Queue extends Fake implements FeedbackUploadQueueService {
  _Queue(this.storage);
  final _Storage storage;
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  final replaced = <_Replace>[];
  Completer<void>? gate;

  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => storage.feedback;
  @override
  Future<String> replaceFailed(
    String id, {
    required File file,
    required String contentType,
    String? notes,
    String? expectedSession,
  }) async {
    replaced.add((id: id, path: file.path, expectedSession: expectedSession));
    await gate?.future;
    final index = storage.feedback.indexWhere((row) => row['id'] == id);
    final fresh = '$id-new';
    storage.feedback[index] = {
      ...storage.feedback[index],
      'status': 'superseded',
      'replaced_by': fresh,
      'dismissed': true,
    };
    storage.feedback.add({
      ...storage.feedback[index],
      'id': fresh,
      'status': 'queued',
      'replaces_feedback_id': id,
    }..remove('replaced_by')..remove('dismissed')..remove('last_error'));
    events.add(FeedbackUploadNotice(fresh, FeedbackUploadNoticeKind.queued));
    return fresh;
  }
}

class _Repository extends Fake implements TrainingRepository {
  _Repository(this.training, this.completed);
  final TrainingEntity training;
  final Set<String> completed;
  int completions = 0;

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      training;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      TrainingDayProgress(
        sessions: {_execution: TrainingDayProgress(ids: completed)},
        sessionTrainings: const {_execution: _trainingId},
      );
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => {};
  @override
  Future<void> completeTraining(String date, {required String trainingId,
      String? sessionId, int? rpe, String? notes}) async {
    completions++;
  }
}

class _Harness {
  _Harness(this.storage, this.sync, this.queue, this.repository, this.pushed,
      this.router);
  final _Storage storage;
  final _Sync sync;
  final _Queue queue;
  final _Repository repository;
  final List<String> pushed;
  final GoRouter router;
}

/// FB1 r4: the message another screen shows (D2: it must not wait behind the
/// detail's missing-video message).
const _homeNotice = 'Aviso de otra pantalla';

Future<_Harness> _mount(
  WidgetTester tester, {
  TrainingEntity? training,
  Set<String> completed = const {'te-1', 'te-2'},
  List<Map<String, dynamic>> feedback = const [],
  Locale locale = const Locale('es'),
  double width = 390,
  double height = 1400,
  double bottomInset = 0,
  TextScaler? textScaler,
  ThemeData? theme,
  String initialLocation = '/detail',
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  // FB1 r4 (D3): the gesture bar's inset (logical = physical at ratio 1.0).
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);
  await sl.reset();
  final storage = _Storage()..feedback = [...feedback];
  final sync = _Sync(storage);
  final queue = _Queue(storage);
  final repository = _Repository(training ?? _training, completed);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(sync);
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  sl.registerFactory<TrainingBloc>(
    () => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase:
          UnmarkExerciseCompletedUseCase(repository),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase:
          GetPreviousExercisePerformancesUseCase(repository),
    ),
  );
  final pushed = <String>[];
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('home-notice'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(_homeNotice))),
              child: const Text('home'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/detail-other',
        builder: (_, _) => const TrainingDetailPage(
          trainingId: 'training-2',
          selectedDate: _date,
        ),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, _) => const TrainingDetailPage(
          trainingId: _trainingId,
          selectedDate: _date,
          selectedExecutionId: _execution,
        ),
      ),
      GoRoute(
        path: '/trainings/:training/exercises/:exercise',
        builder: (_, state) {
          pushed.add('exercise:${state.pathParameters['exercise']}');
          return const Scaffold(body: Text('active-exercise-route'));
        },
      ),
      GoRoute(
        path: '/trainings/:training/circuits/:block',
        builder: (_, state) {
          pushed.add('circuit:${state.pathParameters['block']}');
          return const Scaffold(body: Text('active-circuit-route'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(sl.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(storage, sync, queue, repository, pushed, router);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(TrainingDetailPage)));

final _complete = find.byKey(const Key('complete-training-button'));

Future<void> _tapComplete(WidgetTester tester) async {
  await tester.ensureVisible(_complete);
  await tester.tap(_complete);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a failed video does not block «Completar entreno»: the '
      'completion is queued like one still uploading', (tester) async {
    final harness = await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
      _video('fb-2', 'te-2', 'completed'),
    ]);
    await _tapComplete(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('confirm-complete-training')), findsOneWidget);
    await tester.tap(find.byKey(const Key('completion-rpe-8')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(harness.repository.completions, 1);
  });

  testWidgets('a video never attached still blocks, naming the exercise and '
      'offering to open it', (tester) async {
    final harness = await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'queued'),
    ]);
    final l10n = _l10n(tester);
    await _tapComplete(tester);
    expect(find.byKey(const Key('confirm-complete-training')), findsNothing);
    expect(harness.repository.completions, 0);
    expect(find.text(l10n.trainingLastSetVideoMissingFor('Peso muerto rumano')),
      findsOneWidget);
    expect(find.textContaining('te-2'), findsNothing);
    await tester.tap(find.text(l10n.trainingLastSetVideoOpenExercise));
    await tester.pumpAndSettle();
    expect(harness.pushed, ['exercise:te-2']);
  });

  testWidgets('a missing circuit video names every member and opens the '
      'circuit', (tester) async {
    final harness = await _mount(tester, training: _circuit);
    final l10n = _l10n(tester);
    await _tapComplete(tester);
    expect(find.text(l10n.trainingLastSetVideoMissingFor('Crunch, Plancha')),
      findsOneWidget);
    await tester.tap(find.text(l10n.trainingLastSetVideoOpenExercise));
    await tester.pumpAndSettle();
    expect(harness.pushed, ['circuit:block-1']);
  });

  testWidgets('each row shows its video state with a readable reason',
      (tester) async {
    await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
      _video('fb-2', 'te-2', 'uploading'),
    ]);
    final l10n = _l10n(tester);
    expect(find.text(l10n.lastSetVideoFailed(l10n.lastSetVideoReasonFileMissing)),
      findsOneWidget);
    expect(find.text(l10n.lastSetVideoSending), findsOneWidget);
    expect(find.byKey(const Key('rerecord-video-te-1')), findsOneWidget);
    expect(find.byKey(const Key('rerecord-video-te-2')), findsNothing);
    final size = tester.getSize(find.byKey(const Key('rerecord-video-te-1')));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the other row states and reasons are named too', (tester) async {
    await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'completed'),
      _video('fb-2', 'te-2', 'failed', error: 'REQUEST_TOO_LARGE', http: 413),
    ]);
    final l10n = _l10n(tester);
    expect(find.text(l10n.lastSetVideoSent), findsOneWidget);
    expect(find.text(l10n.lastSetVideoFailed(l10n.lastSetVideoReasonTooLarge)),
      findsOneWidget);
  });

  testWidgets('«Volver a grabar» replaces the failed video once, for this '
      'session', (tester) async {
    final harness = await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
      _video('fb-2', 'te-2', 'completed'),
    ]);
    final l10n = _l10n(tester);
    mockVideoPicker(tester, (_) async => '/tmp/again.mp4');
    final button = find.byKey(const Key('rerecord-video-te-1'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false); // double tap: one sheet
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('last-set-video-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('last-set-video-record')));
    await tester.pumpAndSettle();
    harness.queue.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('last-set-video-use')));
    await tester.pump();
    await tester.tap(button, warnIfMissed: false); // while it is saved
    await tester.pump();
    harness.queue.gate!.complete();
    await tester.pumpAndSettle();
    expect(harness.queue.replaced, hasLength(1));
    expect(harness.queue.replaced.single.id, 'fb-1');
    expect(harness.queue.replaced.single.path, '/tmp/again.mp4');
    expect(harness.queue.replaced.single.expectedSession, _stamp);
    expect(find.byKey(const Key('rerecord-video-te-1')), findsNothing);
    expect(find.text(l10n.lastSetVideoPending), findsOneWidget);
  });

  testWidgets('«Volver a grabar» does nothing once the account changed',
      (tester) async {
    final harness = await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
      _video('fb-2', 'te-2', 'completed'),
    ]);
    mockVideoPicker(tester, (_) async => '/tmp/again.mp4');
    final button = find.byKey(const Key('rerecord-video-te-1'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('last-set-video-record')));
    await tester.pumpAndSettle();
    harness.storage.stamp = 'other:2:test';
    await tester.tap(find.byKey(const Key('last-set-video-use')));
    await tester.pumpAndSettle();
    expect(harness.queue.replaced, isEmpty);
  });

  testWidgets('a circuit row names the member whose video failed and offers '
      'to record it again', (tester) async {
    await _mount(tester, training: _circuit, feedback: [
      _video('fb-1', 'te-1', 'completed'),
      _video('fb-2', 'te-2', 'failed', error: 'file_missing'),
    ]);
    final l10n = _l10n(tester);
    expect(
      find.text(l10n.lastSetVideoMemberFailed(
          'Plancha', l10n.lastSetVideoReasonFileMissing)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rerecord-video-te-2')), findsOneWidget);
    expect(find.byKey(const Key('rerecord-video-te-1')), findsNothing);
  });

  testWidgets('a queued completion waiting on videos names them', (tester) async {
    final harness = await _mount(tester, feedback: [
      _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
      _video('fb-2', 'te-2', 'queued'),
    ]);
    harness.sync.kind = CompletionSyncBlockerKind.feedbackFailed;
    harness.sync.controller.add(null);
    await tester.pumpAndSettle();
    final l10n = _l10n(tester);
    expect(find.text(l10n.trainingFeedbackFailedFor('Sentadilla búlgara')),
      findsOneWidget);
    harness.storage.feedback[0] = _video('fb-1', 'te-1', 'completed');
    harness.sync.kind = CompletionSyncBlockerKind.feedbackWaiting;
    harness.sync.controller.add(null);
    await tester.pumpAndSettle();
    expect(find.text(l10n.trainingFeedbackWaitingFor('Peso muerto rumano')),
      findsOneWidget);
  });

  // FB1 r3: at the default text size the circuit row and the missing-video
  // message keep their r2 layout (member lines in the body's column, the
  // Material SnackBar action).
  testWidgets('at 1.0× a failed member line stays in the circuit row body',
      (tester) async {
    await _mount(tester, training: _circuit, width: 320, feedback: [
      _video('fb-1', 'te-1', 'completed'),
      _video('fb-2', 'te-2', 'failed', error: 'file_missing'),
    ]);
    final l10n = _l10n(tester);
    final line = find.text(l10n.lastSetVideoMemberFailed(
        'Plancha', l10n.lastSetVideoReasonFileMissing));
    await tester.ensureVisible(line);
    await tester.pumpAndSettle();
    final name = tester.getRect(find.text('Circuito core'));
    expect(tester.getRect(line).left, greaterThanOrEqualTo(name.left));
    expect(find.text('2/2'), findsWidgets);
  });

  testWidgets('at 1.0× the missing-video message keeps the SnackBar action',
      (tester) async {
    await _mount(tester);
    await _tapComplete(tester);
    expect(find.byType(SnackBarAction), findsOneWidget);
  });

  // FB1 r4 (D1): the theme's SnackBar (raised surface) has no action colour,
  // so Material's default (inversePrimary, meant for an inverse SnackBar) was
  // 1.10:1 in light and 1.22:1 in dark. The action must read at 4.5:1 on the
  // SnackBar's real background, in both themes and both layouts.
  group('«Ir al ejercicio» contrast', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('$name at $scale×: at least 4.5:1', (tester) async {
          await _mount(tester, theme: theme,
            width: scale == 1.0 ? 390 : 320,
            textScaler:
                scale == 1.0 ? null : AndroidNonlinearTextScaler(scale));
          final l10n = _l10n(tester);
          await _tapComplete(tester);
          final action = find.text(l10n.trainingLastSetVideoOpenExercise);
          expect(action, findsOneWidget);
          final text = tester.renderObject<RenderParagraph>(action).text
              .style!.color!;
          final background = tester.widget<Material>(find.descendant(
            of: find.byType(SnackBar), matching: find.byType(Material)).first)
              .color!;
          expect(text.a, 1.0);
          expect(background.a, 1.0);
          expect(contrast(text, background), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  // FB1 r4 (D2): the missing-video message belongs to the detail. It went with
  // the user to the next screen and to other trainings, and as a persistent
  // SnackBar it held every later message in the app-wide queue.
  group('the missing-video message stays on its detail', () {
    testWidgets('it can still be acted on while the detail is shown, and it '
        'is gone once another route covers the detail and after coming back',
        (tester) async {
      final harness = await _mount(tester, feedback: [
        _video('fb-1', 'te-1', 'queued'),
      ]);
      final l10n = _l10n(tester);
      final message =
          find.text(l10n.trainingLastSetVideoMissingFor('Peso muerto rumano'));
      await _tapComplete(tester);
      expect(message, findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(message, findsOneWidget);
      unawaited(harness.router.push('/trainings/$_trainingId/exercises/te-1'));
      await tester.pumpAndSettle();
      expect(find.text('active-exercise-route'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingDetailPage), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('it is gone after leaving the detail, does not show on '
        "another training and does not hold back another screen's message",
        (tester) async {
      final harness = await _mount(tester, initialLocation: '/home',
        feedback: [_video('fb-1', 'te-1', 'queued')]);
      unawaited(harness.router.push('/detail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      // O7: the pinned footer ignores taps until the pushed detail has
      // entered (240 ms) plus 400 ms after the push. Wait longer than that
      // on its own, whatever time the pumps above advanced, so the tap
      // below is a deliberate one.
      const footerArmedAfterPush = Duration(milliseconds: 700);
      await tester.pump(footerArmedAfterPush);
      final l10n = _l10n(tester);
      final message =
          find.text(l10n.trainingLastSetVideoMissingFor('Peso muerto rumano'));
      await _tapComplete(tester);
      expect(message, findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingDetailPage), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      unawaited(harness.router.push('/detail-other'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(TrainingDetailPage), findsOneWidget);
      expect(message, findsNothing);
      harness.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-notice')));
      await tester.pumpAndSettle();
      expect(find.text(_homeNotice), findsOneWidget);
    });

    testWidgets('asking twice leaves a single message, which a tap on its '
        'action closes', (tester) async {
      final harness = await _mount(tester, feedback: [
        _video('fb-1', 'te-1', 'queued'),
      ]);
      final l10n = _l10n(tester);
      await _tapComplete(tester);
      await _tapComplete(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.tap(find.text(l10n.trainingLastSetVideoOpenExercise));
      await tester.pumpAndSettle();
      expect(harness.pushed, ['exercise:te-2']);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  // FB1 r4 (D3): at 2.0× on 320 dp the footer reaches its height cap and
  // scrolls; its bottom padding (with the gesture bar's inset) scrolled with
  // it, so the footer's visible area reached under the gesture bar and the
  // button could rest there. The footer's scroll area must end above the
  // inset, and the button, once scrolled to, must sit whole inside it.
  group('the footer keeps clear of the bottom inset', () {
    const height = 711.0;
    const inset = 48.0;
    for (final scale in const [1.0, 2.0]) {
      testWidgets('at $scale× on 320 dp with two failed videos named',
          (tester) async {
        final harness = await _mount(tester, width: 320, height: height,
          bottomInset: inset,
          textScaler:
              scale == 1.0 ? null : AndroidNonlinearTextScaler(scale),
          feedback: [
            _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
            _video('fb-2', 'te-2', 'failed', error: 'file_missing'),
          ]);
        harness.sync.kind = CompletionSyncBlockerKind.feedbackFailed;
        harness.sync.controller.add(null);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final l10n = _l10n(tester);
        expect(find.text(l10n.trainingFeedbackFailedFor(
            'Sentadilla búlgara, Peso muerto rumano')), findsOneWidget);
        final footer = tester.getRect(find.descendant(
          of: find.byType(ExomPinnedFooter),
          matching: find.byType(Scrollable)));
        expect(footer.bottom, lessThanOrEqualTo(height - inset));
        await tester.ensureVisible(_complete);
        await tester.pumpAndSettle();
        final button = tester.getRect(_complete);
        expect(button.top, greaterThanOrEqualTo(footer.top));
        expect(button.bottom, lessThanOrEqualTo(height - inset));
        if (scale == 1.0) {
          // At the default size the footer is unchanged: 12 under the button,
          // then the inset.
          expect(button.bottom, closeTo(height - inset - 12, 0.5));
        }
      });
    }
  });

  // FB1 r2 (review F7): the new rows and messages at the largest text size
  // Android offers (2.0, nonlinear) on the narrowest supported width; r3 adds
  // 1.6× to the circuit row and the missing-video message.
  group('large text at 320 dp', () {
    const scaler = AndroidNonlinearTextScaler(2.0);
    const longFirst = 'Sentadilla búlgara con mancuernas y pausa isométrica';
    const longSecond = 'Peso muerto rumano a una pierna con banda elástica';
    final longTraining = TrainingEntity(
      id: _trainingId,
      name: 'Pierna',
      types: const ['FUERZA'],
      level: 'INTERMEDIATE',
      tags: const [],
      requiresLastSetVideo: true,
      exercises: [_exercise(1, longFirst), _exercise(2, longSecond)],
    );
    final longCircuit = TrainingEntity(
      id: _trainingId,
      name: 'Core',
      types: const ['FUERZA'],
      level: 'INTERMEDIATE',
      tags: const [],
      requiresLastSetVideo: true,
      exercises: [_member(1, longFirst, 0), _member(2, longSecond, 1)],
    );

    void expectInside(WidgetTester tester, Finder finder) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('${locale.languageCode}: failed row with its reason and '
          '«Volver a grabar»', (tester) async {
        await _mount(tester, training: longTraining, locale: locale,
          width: 320, textScaler: scaler, feedback: [
            _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
            _video('fb-2', 'te-2', 'failed', error: 'X', http: 415),
          ]);
        expect(tester.takeException(), isNull);
        final l10n = _l10n(tester);
        // The list builds lazily: each row is checked once scrolled to.
        final rows = {
          'rerecord-video-te-1':
              l10n.lastSetVideoFailed(l10n.lastSetVideoReasonFileMissing),
          'rerecord-video-te-2':
              l10n.lastSetVideoFailed(l10n.lastSetVideoReasonUnsupported),
        };
        for (final MapEntry(key: key, value: text) in rows.entries) {
          final button = find.byKey(Key(key));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectInside(tester, button);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          final line = find.text(text);
          expect(line, findsOneWidget);
          expectInside(tester, line);
        }
      });

      testWidgets('${locale.languageCode}: pending and sending rows',
          (tester) async {
        await _mount(tester, training: longTraining, locale: locale,
          width: 320, textScaler: scaler, feedback: [
            _video('fb-1', 'te-1', 'queued'),
            _video('fb-2', 'te-2', 'uploading'),
          ]);
        final l10n = _l10n(tester);
        for (final text in [l10n.lastSetVideoPending, l10n.lastSetVideoSending]) {
          final line = find.text(text);
          await tester.scrollUntilVisible(line, 200,
            scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectInside(tester, line);
        }
      });

      // FB1-R2-O1 (r3): with large text the circuit row's body takes all the
      // width left by the index numeral and the thumbnail, and each failed
      // member's line goes under the row's header at full width, wrapping.
      for (final scale in const [1.6, 2.0]) {
        testWidgets('${locale.languageCode} at $scale×: circuit with two '
            'failed members', (tester) async {
          await _mount(tester, training: longCircuit, locale: locale,
            width: 320, textScaler: AndroidNonlinearTextScaler(scale),
            feedback: [
              _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
              _video('fb-2', 'te-2', 'failed', error: 'X', http: 413),
            ]);
          expect(tester.takeException(), isNull);
          final l10n = _l10n(tester);
          final name = find.text('Circuito core');
          await tester.ensureVisible(name);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // The body reaches the row's end padding (320 - 12).
          final body = tester.getRect(find.ancestor(
            of: name, matching: find.byType(Expanded)).first);
          expect(body.right, closeTo(308, 0.5));
          expectInside(tester, name);
          final numeral = tester.getRect(find.text('01').first);
          final lines = {
            'rerecord-video-te-1': l10n.lastSetVideoMemberFailed(
                longFirst, l10n.lastSetVideoReasonFileMissing),
            'rerecord-video-te-2': l10n.lastSetVideoMemberFailed(
                longSecond, l10n.lastSetVideoReasonTooLarge),
          };
          for (final MapEntry(key: key, value: text) in lines.entries) {
            final line = find.text(text);
            expect(line, findsOneWidget);
            await tester.ensureVisible(line);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expectInside(tester, line);
            // Under the header, not in the body's column.
            expect(tester.getRect(line).left, lessThan(numeral.right));
            final button = find.byKey(Key(key));
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expectInside(tester, button);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          }
        });

        // FB1-R2-O2 (r3): with large text the action goes under the message,
        // aligned to its start, with a 48 dp target; the message wraps.
        testWidgets('${locale.languageCode} at $scale×: missing-video message '
            'naming both exercises, with «Ir al ejercicio»', (tester) async {
          final harness = await _mount(tester, training: longTraining,
            locale: locale, width: 320,
            textScaler: AndroidNonlinearTextScaler(scale));
          final l10n = _l10n(tester);
          await _tapComplete(tester);
          expect(tester.takeException(), isNull);
          final message = find.text(l10n.trainingLastSetVideoMissingFor(
              '$longFirst, $longSecond'));
          expect(message, findsOneWidget);
          expectInside(tester, message);
          final action = find.text(l10n.trainingLastSetVideoOpenExercise);
          expect(action, findsOneWidget);
          expectInside(tester, action);
          final button = find.ancestor(of: action,
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
          expect(button, findsOneWidget);
          final buttonRect = tester.getRect(button);
          final messageRect = tester.getRect(message);
          expect(buttonRect.top, greaterThanOrEqualTo(messageRect.bottom));
          expect(buttonRect.left, lessThanOrEqualTo(messageRect.left));
          expect(buttonRect.height, greaterThanOrEqualTo(48));
          expect(buttonRect.width, greaterThanOrEqualTo(48));
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(harness.pushed, ['exercise:te-1']);
        });
      }

      testWidgets('${locale.languageCode}: queued completion naming the '
          'videos it waits for', (tester) async {
        final harness = await _mount(tester, training: longTraining,
          locale: locale, width: 320, textScaler: scaler, feedback: [
            _video('fb-1', 'te-1', 'failed', error: 'file_missing'),
            _video('fb-2', 'te-2', 'failed', error: 'file_missing'),
          ]);
        harness.sync.kind = CompletionSyncBlockerKind.feedbackFailed;
        harness.sync.controller.add(null);
        await tester.pumpAndSettle();
        final l10n = _l10n(tester);
        final line = find.text(l10n.trainingFeedbackFailedFor(
            '$longFirst, $longSecond'));
        expect(line, findsOneWidget);
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectInside(tester, line);
      });
    }
  });

  // COLA r3 (decision of 26-11): the detail also says why its queued progress
  // waits for a video, with the text «Subidas pendientes» shows, under the
  // pending status of the session completion. One line for the training:
  // its own video, then behind another exercise, then behind the day.
  group('wait reason of the queued progress', () {
    Map<String, dynamic> action(String id, String type,
            {String training = _trainingId,
            String session = _execution,
            String? exercise}) => {
          'id': id,
          'type': type,
          'training_id': training,
          'date': _date,
          'training_session_id': session,
          'training_exercise_id': ?exercise,
          'status': 'queued',
          'attempts': 0,
          'format_version': 2,
        };
    final waitLine = find.byKey(const Key('training-completion-wait'));

    Future<_Harness> mountWaiting(WidgetTester tester,
        Map<String, ProgressFeedbackWait> waits,
        {Locale locale = const Locale('es'),
        double width = 390,
        TextScaler? textScaler,
        TrainingEntity? training}) async {
      final harness = await _mount(tester, locale: locale, width: width,
          textScaler: textScaler, training: training);
      harness.storage.actions = [
        action('mark-1', 'mark_exercise_completed', exercise: 'te-1'),
        action('mark-2', 'mark_exercise_completed', exercise: 'te-2'),
        action('complete-1', 'complete_training'),
      ];
      harness.sync.waits.addAll(waits);
      harness.sync.kind = CompletionSyncBlockerKind.feedbackWaiting;
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('held by its own video', (tester) async {
      await mountWaiting(tester, {
        'mark-1': ProgressFeedbackWait.ownVideo,
        'mark-2': ProgressFeedbackWait.behindVideo,
        'complete-1': ProgressFeedbackWait.behindVideo,
      });
      final l10n = _l10n(tester);
      expect(waitLine, findsOneWidget);
      expect(find.descendant(matchRoot: true, of: waitLine,
          matching: find.text(l10n.pendingSyncWaitsOwnVideo)), findsOneWidget);
      expect(find.descendant(matchRoot: true, of: waitLine,
          matching: find.text(l10n.pendingSyncWaitsBehindVideo)), findsNothing);
    });

    testWidgets('behind another exercise of this training', (tester) async {
      await mountWaiting(tester, {
        'mark-2': ProgressFeedbackWait.behindDayVideo,
        'complete-1': ProgressFeedbackWait.behindVideo,
      });
      final l10n = _l10n(tester);
      expect(waitLine, findsOneWidget);
      expect(find.descendant(matchRoot: true, of: waitLine,
          matching: find.text(l10n.pendingSyncWaitsBehindVideo)), findsOneWidget);
      expect(find.descendant(matchRoot: true, of: waitLine,
          matching: find.text(l10n.pendingSyncWaitsBehindDayVideo)), findsNothing);
    });

    testWidgets('behind other activity of the day', (tester) async {
      await mountWaiting(tester, {
        'complete-1': ProgressFeedbackWait.behindDayVideo,
      });
      expect(waitLine, findsOneWidget);
      expect(find.text(_l10n(tester).pendingSyncWaitsBehindDayVideo),
          findsOneWidget);
    });

    testWidgets('nothing held: no line; it follows the queue', (tester) async {
      final harness = await mountWaiting(tester, {});
      final l10n = _l10n(tester);
      expect(find.text(l10n.trainingFeedbackWaiting), findsOneWidget);
      expect(waitLine, findsNothing);
      // Held work of another training or execution is not this one's wait.
      harness.storage.actions = [
        ...harness.storage.actions,
        action('other-training', 'mark_exercise_completed',
            training: 'training-2', exercise: 'te-9'),
        action('other-session', 'mark_exercise_completed',
            session: 'execution-2', exercise: 'te-1'),
      ];
      harness.sync.waits.addAll({
        'other-training': ProgressFeedbackWait.ownVideo,
        'other-session': ProgressFeedbackWait.ownVideo,
      });
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      expect(waitLine, findsNothing);
      // A queue change that holds this training's work shows it at once.
      harness.sync.waits['mark-2'] = ProgressFeedbackWait.ownVideo;
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.text(l10n.pendingSyncWaitsOwnVideo), findsOneWidget);
      // And it goes once the video is through.
      harness.sync.waits.remove('mark-2');
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      expect(waitLine, findsNothing);
    });

    testWidgets('the same line under «pendiente de sincronizar» of a queued '
        'completion', (tester) async {
      final harness = await mountWaiting(tester, {
        'complete-1': ProgressFeedbackWait.behindVideo,
      });
      harness.sync.kind = null;
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);
      expect(find.text(l10n.trainingDetailCompletionSavedPending),
          findsOneWidget);
      expect(find.text(l10n.pendingSyncWaitsBehindVideo), findsOneWidget);
      final style = tester.widget<Text>(waitLine).style!;
      expect(style.fontSize, 14);
      expect(style.fontFamily, AppTheme.bodyFontFamily);
      expect(style.color, tester.element(waitLine).exomPalette.textSecondary);
    });

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('${locale.languageCode} at 2.0× on 320 dp: the line fits',
          (tester) async {
        await mountWaiting(tester, {
          'complete-1': ProgressFeedbackWait.behindDayVideo,
        }, locale: locale, width: 320,
            textScaler: const AndroidNonlinearTextScaler(2.0));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(waitLine);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(_l10n(tester).pendingSyncWaitsBehindDayVideo),
            findsOneWidget);
        final rect = tester.getRect(waitLine);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        await tester.ensureVisible(_complete);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  // COLA r4: the row of a held exercise also says why its progress waits,
  // under its «Pendiente de sincronizar». When the pending completion's
  // footer already gives the same text, the row does not repeat it.
  group('wait reason on the exercise row', () {
    Map<String, dynamic> action(String id, String type, {String? exercise}) => {
          'id': id,
          'type': type,
          'training_id': _trainingId,
          'date': _date,
          'training_session_id': _execution,
          'training_exercise_id': ?exercise,
          'status': 'queued',
          'attempts': 0,
          'format_version': 2,
        };
    Finder rowWait(String exercise) =>
        find.byKey(Key('training-exercise-wait-$exercise'));
    final footerWait = find.byKey(const Key('training-completion-wait'));

    Future<_Harness> mountRows(WidgetTester tester,
        Map<String, ProgressFeedbackWait> waits,
        {bool completion = false,
        Locale locale = const Locale('es'),
        double width = 390,
        TextScaler? textScaler,
        TrainingEntity? training}) async {
      final harness = await _mount(tester, locale: locale, width: width,
          textScaler: textScaler, training: training);
      harness.storage.actions = [
        action('mark-1', 'mark_exercise_completed', exercise: 'te-1'),
        action('mark-2', 'mark_exercise_completed', exercise: 'te-2'),
        if (completion) action('complete-1', 'complete_training'),
      ];
      harness.sync.waits.addAll(waits);
      if (completion) {
        harness.sync.kind = CompletionSyncBlockerKind.feedbackWaiting;
      }
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('each held row says its own wait', (tester) async {
      await mountRows(tester, {
        'mark-1': ProgressFeedbackWait.ownVideo,
        'mark-2': ProgressFeedbackWait.behindVideo,
      });
      final l10n = _l10n(tester);
      expect(footerWait, findsNothing);
      expect(find.descendant(matchRoot: true, of: rowWait('te-1'),
          matching: find.text(l10n.pendingSyncWaitsOwnVideo)), findsOneWidget);
      expect(find.descendant(matchRoot: true, of: rowWait('te-2'),
          matching: find.text(l10n.pendingSyncWaitsBehindVideo)),
          findsOneWidget);
      expect(find.text(l10n.syncStatusPending), findsNWidgets(2));
      final style = tester.widget<Text>(rowWait('te-1')).style!;
      expect(style.fontSize, 14);
      expect(style.fontFamily, AppTheme.bodyFontFamily);
      expect(style.color,
          tester.element(rowWait('te-1')).exomPalette.textSecondary);
    });

    testWidgets('behind other activity of the day', (tester) async {
      await mountRows(tester, {'mark-2': ProgressFeedbackWait.behindDayVideo});
      expect(rowWait('te-1'), findsNothing);
      expect(find.descendant(matchRoot: true, of: rowWait('te-2'),
          matching: find.text(_l10n(tester).pendingSyncWaitsBehindDayVideo)),
          findsOneWidget);
    });

    testWidgets('nothing held: no line; it follows the queue', (tester) async {
      final harness = await mountRows(tester, {});
      final l10n = _l10n(tester);
      expect(find.text(l10n.syncStatusPending), findsNWidgets(2));
      expect(rowWait('te-1'), findsNothing);
      expect(rowWait('te-2'), findsNothing);
      harness.sync.waits['mark-1'] = ProgressFeedbackWait.ownVideo;
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      expect(rowWait('te-1'), findsOneWidget);
      harness.sync.waits.clear();
      harness.sync.controller.add(null);
      await tester.pumpAndSettle();
      expect(rowWait('te-1'), findsNothing);
    });

    testWidgets('a row does not repeat the footer\'s wait', (tester) async {
      await mountRows(tester, {
        'mark-1': ProgressFeedbackWait.ownVideo,
        'mark-2': ProgressFeedbackWait.behindVideo,
        'complete-1': ProgressFeedbackWait.behindVideo,
      }, completion: true);
      final l10n = _l10n(tester);
      expect(find.descendant(matchRoot: true, of: footerWait,
          matching: find.text(l10n.pendingSyncWaitsOwnVideo)), findsOneWidget);
      expect(rowWait('te-1'), findsNothing);
      expect(find.text(l10n.pendingSyncWaitsOwnVideo), findsOneWidget);
      expect(find.descendant(matchRoot: true, of: rowWait('te-2'),
          matching: find.text(l10n.pendingSyncWaitsBehindVideo)),
          findsOneWidget);
    });

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('${locale.languageCode} at 2.0× on 320 dp: the row line '
          'fits', (tester) async {
        await mountRows(tester, {
          'mark-1': ProgressFeedbackWait.ownVideo,
          'mark-2': ProgressFeedbackWait.behindDayVideo,
        }, locale: locale, width: 320,
            textScaler: const AndroidNonlinearTextScaler(2.0));
        expect(tester.takeException(), isNull);
        for (final exercise in const ['te-1', 'te-2']) {
          await tester.ensureVisible(rowWait(exercise));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(rowWait(exercise));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
      });
    }
  });
}
