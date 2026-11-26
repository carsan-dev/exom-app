// Shared harness of the active circuit tests (L3 unit 4). Not a test file:
// fakes for the cache (records every write with its key), the native rest
// timer, the TrainingBloc completion path and the feedback queue, and a
// GoRouter so the page can pop back to the detail as in the app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/auth/presentation/validated_session_gate.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;
import 'last_set_video_test_support.dart' show EnqueueCall;

const circuitTrainingId = 'training';
const circuitBlockId = 'block';
const circuitDate = '2026-11-18';

/// Cache key the page uses for an anonymous user (no FirebaseAuth user).
String circuitStateKey({String? sessionId}) =>
    'active_circuit:anonymous:$circuitDate:$circuitTrainingId:$circuitBlockId'
    '${sessionId == null ? '' : ':$sessionId'}';

/// The exact key set written by the released (pre-L3) page.
const preL3CircuitKeys = {
  'training_session_id',
  'round',
  'exercise_index',
  'status',
  'rest_ends_at',
  'ready_to_finish',
  'performances',
  'completion_actions',
  'feedback_ids',
  'feedback_statuses',
};

class CircuitDraftStore implements ActiveWorkoutLocalStore {
  final Map<String, ActiveWorkoutHiveModel> data = {};
  final removed = <String>[];

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      data[exerciseId];

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    data[workout.exerciseId] = workout;
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    removed.add(exerciseId);
    data.remove(exerciseId);
  }
}

class CircuitStorage extends LocalStorage {
  CircuitStorage({this.restored, this.unitSystem = UnitSystem.metric});

  String stamp = 'owner:1:test';
  Map<String, dynamic>? restored;
  final UnitSystem unitSystem;

  /// Every map written to the cache, as written (no copy of nested values is
  /// needed: the page builds a fresh map per write).
  final writes = <Map<String, dynamic>>[];
  final writeKeys = <String>[];
  final removedKeys = <String>[];
  final settings = <String, Object?>{'last_set_video_reminder_enabled': false};
  final drafts = CircuitDraftStore();

  /// L5-E3c: when true, `saveSetting` throws (the «Recordármelo» revert).
  bool failSettingSaves = false;

  Map<String, dynamic> get lastWrite => writes.last;

  /// When set, every cache write is recorded at once (call order, as Hive
  /// keeps it) and then waits for it: an in-flight persist (interleaving
  /// tests).
  Completer<void>? writeGate;

  @override
  String? get sessionStamp => stamp;

  @override
  Map<String, dynamic>? getCachedMap(String key) {
    final value = restored;
    if (value == null) return null;
    // Same shape Hive returns after `_normalize`: decoded JSON maps.
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> cacheData(String key, dynamic value) async {
    writeKeys.add(key);
    writes.add(Map<String, dynamic>.from(value as Map));
    await writeGate?.future;
  }

  @override
  Future<void> removeCachedData(String key) async {
    removedKeys.add(key);
  }

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = settings[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    if (failSettingSaves) throw StateError('settings write failed');
    settings[key] = value;
  }

  @override
  ActiveWorkoutLocalStore bindActiveWorkoutStore() => drafts;

  @override
  bool getRestTimerSoundEnabled() => false;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;

  @override
  Locale? getLocalePreference() => const Locale('es');

  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
}

class RecordingRestTimer implements RestTimerCoordinator {
  @override
  RestTimerSession? activeSession;
  final starts = <RestTimerSession>[];
  int cancels = 0;
  int finishes = 0;

  /// Ordered log: `start:<id>`, `cancel`, `finish`.
  final log = <String>[];

  /// When set, `cancel`/`finish` wait for it (interleaving tests).
  Completer<void>? gate;

  @override
  Future<void> start(RestTimerSession session) async {
    activeSession = session;
    starts.add(session);
    log.add('start:${session.id}');
  }

  @override
  Future<void> finish() async {
    activeSession = null;
    finishes++;
    log.add('finish');
    await gate?.future;
  }

  @override
  Future<void> cancel() async {
    activeSession = null;
    cancels++;
    log.add('cancel');
    await gate?.future;
  }
}

/// Records every event; completes `MarkExerciseCompleted.completion` with
/// success unless [failWhen] returns true for that event. Like the real
/// TrainingBloc (`_onMarkExerciseCompleted` only acts on
/// TrainingDetailLoaded), a completion is ignored and never completed while
/// [state] is not loaded.
class RecordingTrainingBloc extends Fake implements TrainingBloc {
  final events = <TrainingEvent>[];
  bool Function(MarkExerciseCompleted event)? failWhen;

  @override
  TrainingState state = TrainingDetailLoaded(
    const TrainingEntity(
      id: circuitTrainingId,
      name: 'Pierna fuerza',
      types: ['FUERZA'],
      level: 'INTERMEDIATE',
      tags: [],
      exercises: [],
    ),
    selectedDate: circuitDate,
  );

  List<MarkExerciseCompleted> get completions =>
      events.whereType<MarkExerciseCompleted>().toList();

  /// `context.read` starts the provider's listener lazily.
  @override
  Stream<TrainingState> get stream => const Stream<TrainingState>.empty();

  @override
  void add(TrainingEvent event) {
    events.add(event);
    if (event is MarkExerciseCompleted) {
      if (state is! TrainingDetailLoaded) return;
      if (failWhen?.call(event) ?? false) {
        event.completion?.completeError(StateError('offline sync failed'));
      } else {
        event.completion?.complete();
      }
    }
  }
}

class CircuitQueue extends Fake implements FeedbackUploadQueueService {
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  final statuses = <String, String>{};

  /// L5-E3c: every `enqueue` with all the fields the page passes.
  final calls = <EnqueueCall>[];

  /// L5-E3c r3: thrown once by the next `enqueue` (nothing is recorded).
  Object? failNextEnqueue;

  @override
  Future<String> enqueue({
    required File file,
    String? expectedSession,
    required String contentType,
    required String mediaType,
    String? notes,
    String? exerciseId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
    String? sessionId,
  }) async {
    final failure = failNextEnqueue;
    if (failure != null) {
      failNextEnqueue = null;
      throw failure;
    }
    calls.add((
      path: file.path,
      expectedSession: expectedSession,
      contentType: contentType,
      mediaType: mediaType,
      notes: notes,
      exerciseId: exerciseId,
      feedbackKind: feedbackKind,
      trainingId: trainingId,
      trainingExerciseId: trainingExerciseId,
      assignmentDate: assignmentDate,
      sessionId: sessionId,
    ));
    return 'fb-${calls.length}';
  }

  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;

  @override
  String? statusOf(String id) => statuses[id];
}

class CircuitAuth extends Fake implements FirebaseAuthService {
  @override
  User? get currentUser => null;
}

class CircuitHarness {
  CircuitHarness(this.storage, this.native, this.bloc, this.queue);
  final CircuitStorage storage;
  final RecordingRestTimer native;
  final RecordingTrainingBloc bloc;
  final CircuitQueue queue;
}

TrainingExerciseEntity circuitExercise(
  String id,
  String name, {
  int? targetValue = 12,
  int? targetRir,
  int restSeconds = 0,
  ExerciseMeasureType? measureType = ExerciseMeasureType.reps,
  bool requestSetTracking = false,
  String? repsOrDuration,
}) => TrainingExerciseEntity(
  id: id,
  order: 0,
  sets: 1,
  repsOrDuration: repsOrDuration ?? '${targetValue ?? ''}',
  measureType: measureType,
  targetValue: targetValue,
  targetRir: targetRir,
  restSeconds: restSeconds,
  requestSetTracking: requestSetTracking,
  blockId: circuitBlockId,
  exercise: ExerciseEntity(id: 'ex-$id', name: name, muscleGroups: const []),
);

ThemeData circuitTheme(Brightness brightness) =>
    brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;

Future<CircuitHarness> pumpCircuit(
  WidgetTester tester, {
  required List<TrainingExerciseEntity> exercises,
  int rounds = 2,
  int restBetweenRounds = 0,
  Map<String, dynamic>? restored,
  Map<String, List<SetPerformance>> previous = const {},
  bool requiresLastSetVideo = false,
  String? sessionId,
  UnitSystem unitSystem = UnitSystem.metric,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  // L5-E5: the overflow sweep uses the Android non-linear scaler and English;
  // [textScaler] replaces the linear [textScale] when given.
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  Brightness brightness = Brightness.dark,
  String blockName = 'Circuito metabólico',
  bool Function(MarkExerciseCompleted event)? failWhen,
  Map<String, String> queueStatuses = const {},
  // L5-E3b (E4-O4): with [themeMode] the app follows it between both themes.
  ValueListenable<ThemeMode>? themeMode,
  // L5-E3c: `last_set_video_reminder_enabled` before the first frame.
  bool lastSetVideoReminder = false,
}) async {
  await sl.reset();
  final storage = CircuitStorage(restored: restored, unitSystem: unitSystem);
  storage.settings['last_set_video_reminder_enabled'] = lastSetVideoReminder;
  final native = RecordingRestTimer();
  final bloc = RecordingTrainingBloc()..failWhen = failWhen;
  final queue = CircuitQueue()..statuses.addAll(queueStatuses);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<RestTimerCoordinator>(native);
  sl.registerSingleton<ExecutionTimerCoordinator>(ExecutionTimerCoordinator());
  sl.registerSingleton<FirebaseAuthService>(CircuitAuth());
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  // Read by the timed interval's ActiveExerciseBloc (unchanged widget).
  sl.registerSingleton<ValidatedSessionGate>(ValidatedSessionGate(() => null));
  addTearDown(sl.reset);
  addTearDown(queue.events.close);
  final preferences = AppPreferencesCubit(storage);
  addTearDown(preferences.close);

  final router = GoRouter(
    initialLocation: '/circuit',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('detail')),
        routes: [
          GoRoute(
            path: 'circuit',
            builder: (_, _) => ActiveCircuitPage(
              trainingId: circuitTrainingId,
              blockId: circuitBlockId,
              args: ActiveCircuitPageArgs(
                trainingBloc: bloc,
                sessionId: sessionId,
                trainingName: 'Pierna fuerza',
                trainingTypes: const ['FUERZA'],
                accentColorHex: null,
                trainingLevel: 'INTERMEDIATE',
                blockId: circuitBlockId,
                blockName: blockName,
                rounds: rounds,
                restBetweenRoundsSeconds: restBetweenRounds,
                exercises: exercises,
                previousPerformances: previous,
                requiresLastSetVideo: requiresLastSetVideo,
                assignmentDate: circuitDate,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final fixedMode = ValueNotifier(ThemeMode.system);
  addTearDown(fixedMode.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode ?? fixedMode,
        builder: (context, mode, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: themeMode == null
            ? circuitTheme(brightness)
            : circuitTheme(Brightness.light),
        darkTheme: themeMode == null ? null : circuitTheme(Brightness.dark),
        themeMode: mode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) {
          GlassDecoration.brightness = Theme.of(context).brightness;
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: textScaler ?? TextScaler.linear(textScale)),
            child: child!,
          );
        },
      ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
  return CircuitHarness(storage, native, bloc, queue);
}

AppLocalizations circuitL10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ActiveCircuitPage)));

/// Fixed frames instead of pumpAndSettle: the rest rule and busy buttons
/// animate continuously by design.
Future<void> settleFrames(WidgetTester tester, [int frames = 4]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Seeds a released-app state map (shape of `_persistState` at b033b6a).
Map<String, dynamic> preL3State({
  String? sessionId,
  int round = 1,
  int exerciseIndex = 0,
  String status = 'executing',
  DateTime? restEndsAt,
  bool readyToFinish = false,
  Map<String, Object?> performances = const {},
  Map<String, Object?> completionActions = const {},
  Map<String, String> feedbackIds = const {},
  Map<String, String> feedbackStatuses = const {},
}) => {
  'training_session_id': sessionId,
  'round': round,
  'exercise_index': exerciseIndex,
  'status': status,
  'rest_ends_at': restEndsAt?.toIso8601String(),
  'ready_to_finish': readyToFinish,
  'performances': performances,
  'completion_actions': completionActions,
  'feedback_ids': feedbackIds,
  'feedback_statuses': feedbackStatuses,
};
