import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';

enum ActiveExerciseStatus { executing, resting, finalResting, done }

abstract class ActiveExerciseEvent {
  const ActiveExerciseEvent();
}

class StartExercise extends ActiveExerciseEvent {
  final String trainingId;
  final String exerciseId;
  final String? sessionId;

  final String? assignmentDate;
  const StartExercise({
    required this.trainingId,
    required this.exerciseId,
    this.sessionId,
    this.assignmentDate,
  });
}

class ToggleExecutionTimer extends ActiveExerciseEvent {
  const ToggleExecutionTimer();
}

class ResetExecutionTimer extends ActiveExerciseEvent {
  const ResetExecutionTimer();
}

class CompleteSet extends ActiveExerciseEvent {
  final int? reps;
  final int? seconds;
  final double? weightKg;
  final int? rir;
  final String? lastSetFeedbackClientUploadId;

  const CompleteSet({
    this.reps,
    this.seconds,
    this.weightKg,
    this.rir,
    this.lastSetFeedbackClientUploadId,
  });
}

class AttachLastSetFeedback extends ActiveExerciseEvent {
  final String clientUploadId;

  const AttachLastSetFeedback(this.clientUploadId);
}

class SkipRest extends ActiveExerciseEvent {
  const SkipRest();
}

/// The rest reached its end. [restEndsAt] identifies which rest ended: when
/// set and different from the current one (the rest was extended meanwhile),
/// the event is stale and ignored. `const FinishRest()` keeps the original,
/// unconditional semantics.
class FinishRest extends ActiveExerciseEvent {
  final DateTime? restEndsAt;

  const FinishRest({this.restEndsAt});
}

/// «+30 s» (decision D7): moves the current rest's end [seconds] later, only
/// while it has not ended yet, capped at now + [maxAhead].
class ExtendRest extends ActiveExerciseEvent {
  final int seconds;

  static const Duration maxAhead = Duration(minutes: 30);

  const ExtendRest([this.seconds = 30]);
}

class AbandonExercise extends ActiveExerciseEvent {
  const AbandonExercise();
}

class ActiveExerciseState {
  /// Stable value; the page maps it to localized text.
  static const otherExecutionMessage =
      'Existing workout belongs to another execution';

  static const _unset = Object();

  final int timedElapsedMs;
  final DateTime? timedStartedAt;
  final int? timedTotalSeconds;
  final TimedPrescription? timedPrescription;
  int elapsedAt(DateTime now) =>
      (timedElapsedMs +
              (timedStartedAt == null
                  ? 0
                  : now.difference(timedStartedAt!).inMilliseconds))
          .clamp(0, (timedTotalSeconds ?? 0) * 1000);
  final String? sessionId;
  final int currentSet;
  final int totalSets;
  final int completedSets;
  final String repsOrDuration;
  final double? weightKg;
  final List<SetPerformance> setPerformances;
  final int restSeconds;
  final ActiveExerciseStatus status;
  final DateTime? restEndsAt;
  final String? errorMessage;
  final String? lastSetFeedbackClientUploadId;
  final String? completionOperationId;

  /// When the last set was logged (C-O1), in milliseconds as the draft keeps
  /// it. It dates the completion, not the end of the rest that follows.
  final DateTime? lastSetLoggedAt;

  const ActiveExerciseState({
    this.timedElapsedMs = 0,
    this.timedStartedAt,
    this.timedTotalSeconds,
    this.timedPrescription,
    this.sessionId,
    required this.currentSet,
    required this.totalSets,
    required this.completedSets,
    required this.repsOrDuration,
    required this.weightKg,
    required this.setPerformances,
    required this.restSeconds,
    required this.status,
    required this.restEndsAt,
    this.errorMessage,
    this.lastSetFeedbackClientUploadId,
    this.completionOperationId,
    this.lastSetLoggedAt,
  });

  factory ActiveExerciseState.initial(
    TrainingExerciseEntity trainingExercise, {
    double? initialWeightKg,
  }) {
    return ActiveExerciseState(
      timedTotalSeconds:
          trainingExercise.measureType == ExerciseMeasureType.seconds
          ? trainingExercise.targetValue
          : null,
      timedPrescription: trainingExercise.timedPrescription,
      currentSet: 1,
      totalSets: trainingExercise.sets,
      completedSets: 0,
      repsOrDuration: trainingExercise.repsOrDuration,
      weightKg: initialWeightKg,
      setPerformances: const [],
      restSeconds: trainingExercise.restSeconds < 0
          ? 0
          : trainingExercise.restSeconds,
      status: ActiveExerciseStatus.executing,
      restEndsAt: null,
    );
  }

  /// Sets counted in [completedSets] whose stored entry is not registered
  /// (RIR-only sets of drafts from earlier versions, see
  /// [isRegisteredSetJson]). They are not done: each one is pending again,
  /// in order, before the sets after [completedSets] (unless a completion
  /// identity already froze the content, see `_restoreState`).
  Set<int> get unregisteredSets => unregisteredSetNumbers(
    completedSets,
    setPerformances.map((set) => set.toJson()),
  );

  /// Sets really done: [completedSets] without [unregisteredSets].
  int get registeredSets => completedSets - unregisteredSets.length;

  /// Stored RIR of [currentSet] when it is a pending unregistered set; the
  /// sheet preselects it instead of the target.
  int? get currentUnregisteredRir {
    if (!unregisteredSets.contains(currentSet)) return null;
    for (final set in setPerformances.reversed) {
      if (set.setNumber == currentSet) return set.rir;
    }
    return null;
  }

  /// Cursor written to the draft. While unregistered sets are pending it
  /// keeps the meaning it had for earlier versions (the set after
  /// [completedSets]), so restoring never rewrites the draft.
  int get persistedCurrentSet => unregisteredSets.isEmpty
      ? currentSet
      : (completedSets + 1).clamp(1, totalSets);

  bool get isExecuting => status == ActiveExerciseStatus.executing;
  bool get isResting =>
      status == ActiveExerciseStatus.resting ||
      status == ActiveExerciseStatus.finalResting;
  bool get isFinalResting => status == ActiveExerciseStatus.finalResting;
  bool get isDone => status == ActiveExerciseStatus.done;

  ActiveExerciseState copyWith({
    int? timedElapsedMs,
    Object? timedStartedAt = _unset,
    int? currentSet,
    int? totalSets,
    String? sessionId,
    int? completedSets,
    String? repsOrDuration,
    Object? weightKg = _unset,
    List<SetPerformance>? setPerformances,
    int? restSeconds,
    ActiveExerciseStatus? status,
    Object? restEndsAt = _unset,
    Object? errorMessage = _unset,
    Object? lastSetFeedbackClientUploadId = _unset,
    String? completionOperationId,
    DateTime? lastSetLoggedAt,
  }) {
    return ActiveExerciseState(
      timedElapsedMs: timedElapsedMs ?? this.timedElapsedMs,
      timedStartedAt: identical(timedStartedAt, _unset)
          ? this.timedStartedAt
          : timedStartedAt as DateTime?,
      timedTotalSeconds: timedTotalSeconds,
      timedPrescription: timedPrescription,
      sessionId: sessionId ?? this.sessionId,
      currentSet: currentSet ?? this.currentSet,
      totalSets: totalSets ?? this.totalSets,
      completedSets: completedSets ?? this.completedSets,
      repsOrDuration: repsOrDuration ?? this.repsOrDuration,
      weightKg: identical(weightKg, _unset)
          ? this.weightKg
          : weightKg as double?,
      setPerformances: setPerformances ?? this.setPerformances,
      restSeconds: restSeconds ?? this.restSeconds,
      status: status ?? this.status,
      restEndsAt: identical(restEndsAt, _unset)
          ? this.restEndsAt
          : restEndsAt as DateTime?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastSetFeedbackClientUploadId:
          identical(lastSetFeedbackClientUploadId, _unset)
          ? this.lastSetFeedbackClientUploadId
          : lastSetFeedbackClientUploadId as String?,
      completionOperationId: completionOperationId ?? this.completionOperationId,
      lastSetLoggedAt: lastSetLoggedAt ?? this.lastSetLoggedAt,
    );
  }
}

class ActiveExerciseBloc
    extends Bloc<ActiveExerciseEvent, ActiveExerciseState> {
  final ActiveWorkoutLocalStore _localStorage;
  final TrainingExerciseEntity _trainingExercise;
  final double? _initialWeightKg;
  final RestTimerCoordinator _restTimerCoordinator;
  final DateTime Function() _now;
  String? _trainingId;
  String? _exerciseId;

  /// Native session id of the rest in progress (memory only). An extension
  /// reuses it so the coordinator replaces the native timer with a single
  /// `start` instead of `cancel` + `start`; after a restore it is rebuilt from
  /// the persisted `restEndsAt`.
  String? _nativeRestId;

  ActiveExerciseBloc({
    required ActiveWorkoutLocalStore localStorage,
    required TrainingExerciseEntity trainingExercise,
    RestTimerCoordinator? restTimerCoordinator,
    double? initialWeightKg,
    DateTime Function()? now,
  }) : _localStorage = localStorage,
       _trainingExercise = trainingExercise,
       _restTimerCoordinator =
           restTimerCoordinator ?? PlatformRestTimerCoordinator(),
       _initialWeightKg = initialWeightKg,
       _now = now ?? DateTime.now,
       super(
         ActiveExerciseState.initial(
           trainingExercise,
           initialWeightKg: initialWeightKg,
         ),
       ) {
    // One stream orders opposite actions and their durable writes, including start,
    // pause/reset, explicit completion and abandonment. Per-type queues would race.
    on<ActiveExerciseEvent>((event, emit) async {
      if (event is StartExercise) return _onStartExercise(event, emit);
      if (event is ToggleExecutionTimer) {
        if (!state.isExecuting || state.timedTotalSeconds == null) return;
        final now = _now();
        final elapsed = state.elapsedAt(now);
        if (elapsed >= state.timedTotalSeconds! * 1000) return;
        final next = state.copyWith(
          timedElapsedMs: elapsed,
          timedStartedAt: state.timedStartedAt == null ? now : null,
        );
        emit(next);
        await _persistState(next, emit);
      } else if (event is ResetExecutionTimer) {
        if (!state.isExecuting) return;
        final next = state.copyWith(timedElapsedMs: 0, timedStartedAt: null);
        emit(next);
        await _persistState(next, emit);
      } else if (event is AttachLastSetFeedback) {
        await _onAttachLastSetFeedback(event, emit);
      } else if (event is CompleteSet) {
        await _onCompleteSet(event, emit);
      } else if (event is SkipRest) {
        await _onSkipRest(event, emit);
      } else if (event is FinishRest) {
        await _onFinishRest(event, emit);
      } else if (event is ExtendRest) {
        await _onExtendRest(event, emit);
      } else if (event is AbandonExercise) {
        await _onAbandonExercise(event, emit);
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }

  Future<void> _onStartExercise(
    StartExercise event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    _trainingId = event.trainingId;
    _exerciseId = event.assignmentDate == null
        ? event.exerciseId
        : event.sessionId == null
            ? '${event.exerciseId}:${event.assignmentDate}'
            : '${event.exerciseId}:${event.assignmentDate}:${event.sessionId}';

    var saved = _localStorage.getActiveWorkout(_exerciseId!);
    if (saved == null && event.assignmentDate != null && event.sessionId != null) {
      final dateKey = '${event.exerciseId}:${event.assignmentDate}';
      final datedDraft = _localStorage.getActiveWorkout(dateKey);
      if (datedDraft != null && datedDraft.trainingId == event.trainingId &&
          datedDraft.sessionId == event.sessionId) {
        // Persist the new key before removing the old one; a crash can be retried.
        saved = datedDraft.copyWith(exerciseId: _exerciseId);
        await _localStorage.saveActiveWorkout(saved);
        await _localStorage.removeActiveWorkout(dateKey);
      }
    }
    if (saved == null && event.assignmentDate != null && event.sessionId == null) {
      final legacy = _localStorage.getActiveWorkout(event.exerciseId);
      if (legacy != null && legacy.trainingId == event.trainingId) {
        // Keep an owner-bound legacy workout in its original slot until explicit
        // completion. Do not invent its date or strand its sets during upgrade.
        saved = legacy;
        _exerciseId = event.exerciseId;
      }
    }
    if (saved != null &&
        (saved.trainingId != event.trainingId ||
            saved.sessionId != event.sessionId)) {
      // Neither a legacy draft nor another execution may be silently adopted
      // or overwritten. Keep it recoverable until the owner selects it.
      _trainingId = null;
      _exerciseId = null;
      emit(
        state.copyWith(
          errorMessage: ActiveExerciseState.otherExecutionMessage,
        ),
      );
      return;
    }
    if (saved != null) {
      final restored = _restoreState(saved);
      if (restored.isDone) {
        await _restTimerCoordinator.cancel();
        if (!await _persistState(restored, emit)) return;
        emit(restored.copyWith(errorMessage: null));
      } else {
        emit(restored.copyWith(errorMessage: null));
        if (restored.isResting) {
          await _startNativeRest(restored);
        }
        await _persistState(restored, emit);
      }
      return;
    }

    final initial = ActiveExerciseState.initial(
      _trainingExercise,
      initialWeightKg: _initialWeightKg,
    );
    final started = initial.copyWith(sessionId: event.sessionId);
    emit(started);
    await _persistState(started, emit);
  }

  Future<void> _onAttachLastSetFeedback(
    AttachLastSetFeedback event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    if (_exerciseId == null ||
        event.clientUploadId.trim().isEmpty ||
        state.isDone) {
      return;
    }
    final nextState = state.copyWith(
      lastSetFeedbackClientUploadId: event.clientUploadId,
      errorMessage: null,
    );
    emit(nextState);
    await _persistState(nextState, emit);
  }

  Future<void> _onCompleteSet(
    CompleteSet event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    if (_exerciseId == null || !state.isExecuting) return;

    final now = _now();
    final setBase = state.copyWith(
      timedElapsedMs: 0,
      timedStartedAt: null,
      lastSetLoggedAt: DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch,
        isUtc: true,
      ),
    );
    final noValues =
        event.reps == null &&
        event.seconds == null &&
        event.weightKg == null &&
        event.rir == null;
    // Saving a pending unregistered set replaces its stored entry in place
    // (or drops it when completed without values); it was already counted.
    final filling = state.unregisteredSets.contains(state.currentSet);
    final nextCompletedSets =
        filling ? state.completedSets : state.completedSets + 1;
    final nextWeight = event.weightKg ?? state.weightKg;
    final setNumber = filling ? state.currentSet : nextCompletedSets;
    final saved = SetPerformance(
      setNumber: setNumber,
      reps: event.reps,
      seconds: event.seconds,
      weightKg: event.weightKg,
      rir: event.rir,
    );
    final List<SetPerformance> nextPerformances;
    if (filling) {
      nextPerformances = <SetPerformance>[];
      var replaced = false;
      for (final set in state.setPerformances) {
        if (set.setNumber != setNumber) {
          nextPerformances.add(set);
        } else if (!replaced) {
          replaced = true;
          if (!noValues) nextPerformances.add(saved);
        }
      }
    } else {
      nextPerformances =
          noValues ? state.setPerformances : [...state.setPerformances, saved];
    }
    final pending = unregisteredSetNumbers(
      nextCompletedSets,
      nextPerformances.map((set) => set.toJson()),
    );

    if (nextCompletedSets >= state.totalSets && pending.isEmpty) {
      if (state.restSeconds > 0) {
        final finalRestingState = setBase.copyWith(
          completedSets: state.totalSets,
          currentSet: state.totalSets,
          weightKg: nextWeight,
          setPerformances: nextPerformances,
          status: ActiveExerciseStatus.finalResting,
          restEndsAt: now.add(Duration(seconds: state.restSeconds)),
          errorMessage: null,
          lastSetFeedbackClientUploadId:
              event.lastSetFeedbackClientUploadId ??
              state.lastSetFeedbackClientUploadId,
        );
        emit(finalRestingState);
        await _persistState(finalRestingState, emit);
        await _startNativeRest(finalRestingState);
        return;
      }
      final doneState = setBase.copyWith(
        completedSets: state.totalSets,
        currentSet: state.totalSets,
        weightKg: nextWeight,
        setPerformances: nextPerformances,
        status: ActiveExerciseStatus.done,
        restEndsAt: null,
        errorMessage: null,
        completionOperationId: state.completionOperationId ?? newOperationId(),
        lastSetFeedbackClientUploadId:
            event.lastSetFeedbackClientUploadId ??
            state.lastSetFeedbackClientUploadId,
      );
      if (!await _persistState(doneState, emit)) return;
      emit(doneState);
      await _restTimerCoordinator.cancel();
      return;
    }

    final nextSet = pending.isEmpty
        ? nextCompletedSets + 1
        : pending.reduce((a, b) => a < b ? a : b);
    if (state.restSeconds <= 0) {
      final executingState = setBase.copyWith(
        completedSets: nextCompletedSets,
        currentSet: nextSet,
        weightKg: nextWeight,
        setPerformances: nextPerformances,
        status: ActiveExerciseStatus.executing,
        restEndsAt: null,
        errorMessage: null,
      );
      emit(executingState);
      await _persistState(executingState, emit);
      return;
    }

    final restingState = setBase.copyWith(
      completedSets: nextCompletedSets,
      currentSet: nextSet,
      weightKg: nextWeight,
      setPerformances: nextPerformances,
      status: ActiveExerciseStatus.resting,
      restEndsAt: now.add(Duration(seconds: state.restSeconds)),
      errorMessage: null,
    );
    emit(restingState);
    await _persistState(restingState, emit);
    await _startNativeRest(restingState);
  }

  Future<void> _onSkipRest(
    SkipRest event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    await _leaveRest(emit, finishedNaturally: false);
  }

  Future<void> _onFinishRest(
    FinishRest event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    // A tick of a rest that was extended meanwhile (outgoing footer during its
    // cross-fade, or a tick queued behind ExtendRest) must not end the new one.
    final endedRest = event.restEndsAt;
    if (endedRest != null && endedRest != state.restEndsAt) return;
    await _leaveRest(emit, finishedNaturally: true);
  }

  Future<void> _onExtendRest(
    ExtendRest event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    final currentEnd = state.restEndsAt;
    final now = _now();
    // An expired rest is not extended: its FinishRest follows.
    if (_exerciseId == null ||
        !state.isResting ||
        currentEnd == null ||
        !now.isBefore(currentEnd) ||
        event.seconds <= 0) {
      return;
    }
    final cap = now.add(ExtendRest.maxAhead);
    var nextEnd = currentEnd.add(Duration(seconds: event.seconds));
    if (nextEnd.isAfter(cap)) nextEnd = cap;
    if (!nextEnd.isAfter(currentEnd)) return;

    final next = state.copyWith(restEndsAt: nextEnd, errorMessage: null);
    emit(next);
    await _persistState(next, emit);
    await _startNativeRest(next, sessionId: _nativeRestId);
  }

  Future<void> _leaveRest(
    Emitter<ActiveExerciseState> emit, {
    required bool finishedNaturally,
  }) async {
    if (!state.isResting) return;

    _nativeRestId = null;
    if (finishedNaturally) {
      await _restTimerCoordinator.finish();
    } else {
      await _restTimerCoordinator.cancel();
    }
    if (state.isFinalResting) {
      final doneState = state.copyWith(
        status: ActiveExerciseStatus.done,
        restEndsAt: null,
        errorMessage: null,
        completionOperationId: state.completionOperationId ?? newOperationId(),
      );
      if (!await _persistState(doneState, emit)) return;
      emit(doneState);
      return;
    }

    final executingState = state.copyWith(
      status: ActiveExerciseStatus.executing,
      restEndsAt: null,
      errorMessage: null,
    );
    emit(executingState);
    await _persistState(executingState, emit);
  }

  Future<void> _onAbandonExercise(
    AbandonExercise event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    if (state.isDone) return;
    _nativeRestId = null;
    await _restTimerCoordinator.cancel();
    await _persistState(state.copyWith(errorMessage: null), emit);
  }

  ActiveExerciseState _restoreState(ActiveWorkoutHiveModel saved) {
    final totalSets = _trainingExercise.sets;
    final completedSets = saved.completedSets.clamp(0, totalSets);

    final now = _now();
    final hasPendingRest =
        saved.restEndsAt != null && saved.restEndsAt!.isAfter(now);
    // Repair on read (P3): an unregistered (RIR-only) set is pending again,
    // the first one in order is in progress; the draft itself is unchanged.
    // A completion identity freezes the content: that draft completes as it
    // is and the replay leaves the set out of the request.
    final pending = saved.completionOperationId != null
        ? const <int>{}
        : unregisteredSetNumbers(completedSets, saved.completedSetData);
    final finished = completedSets >= totalSets && pending.isEmpty;
    final currentSet = pending.isNotEmpty
        ? pending.reduce((a, b) => a < b ? a : b)
        : hasPendingRest
        ? saved.currentSet.clamp(1, totalSets)
        : (completedSets + 1).clamp(1, totalSets);

    return ActiveExerciseState(
      sessionId: saved.sessionId,
      timedElapsedMs: saved.timedElapsedMs,
      timedStartedAt: saved.timedStartedAt,
      timedTotalSeconds:
          saved.timedTotalSeconds ??
          (_trainingExercise.measureType == ExerciseMeasureType.seconds
              ? _trainingExercise.targetValue
              : null),
      timedPrescription: saved.timedTotalSeconds != null
          ? saved.timedPrescription
          : _trainingExercise.timedPrescription,
      currentSet: currentSet,
      totalSets: totalSets,
      completedSets: completedSets,
      repsOrDuration: _trainingExercise.repsOrDuration,
      weightKg: saved.lastWeightKg ?? _initialWeightKg,
      setPerformances: saved.completedSetData
          .map(
            (data) => SetPerformance(
              setNumber: data['set_number'] as int,
              reps: data['reps'] as int?,
              seconds: data['seconds'] as int?,
              weightKg: (data['weight_kg'] as num?)?.toDouble(),
              rir: (data['rir'] as num?)?.toInt(),
            ),
          )
          .toList(),
      restSeconds: _trainingExercise.restSeconds < 0
          ? 0
          : _trainingExercise.restSeconds,
      status: finished
          ? hasPendingRest
                ? ActiveExerciseStatus.finalResting
                : ActiveExerciseStatus.done
          : hasPendingRest
          ? ActiveExerciseStatus.resting
          : ActiveExerciseStatus.executing,
      restEndsAt: hasPendingRest ? saved.restEndsAt : null,
      lastSetFeedbackClientUploadId: saved.lastSetFeedbackClientUploadId,
      completionOperationId: saved.completionOperationId ??
          (finished && !hasPendingRest ? newOperationId() : null),
      lastSetLoggedAt: saved.lastSetLoggedAt?.toUtc(),
    );
  }

  Future<void> _startNativeRest(
    ActiveExerciseState restState, {
    String? sessionId,
  }) {
    final exerciseId = _exerciseId ?? _trainingExercise.exercise.id;
    // The completed set disambiguates equal deadlines and survives restore.
    final id =
        sessionId ??
        '${_trainingId ?? ''}:$exerciseId:${restState.completedSets}:${restState.restEndsAt!.millisecondsSinceEpoch}';
    _nativeRestId = id;
    return _restTimerCoordinator.start(
      RestTimerSession(
        id: id,
        exerciseName: _trainingExercise.exercise.name,
        durationSeconds: restState.restSeconds,
        endsAt: restState.restEndsAt!,
      ),
    );
  }

  Future<bool> _persistState(
    ActiveExerciseState nextState,
    Emitter<ActiveExerciseState> emit,
  ) async {
    final trainingId = _trainingId;
    final exerciseId = _exerciseId;
    if (trainingId == null || exerciseId == null) {
      return false;
    }

    try {
      await _localStorage.saveActiveWorkout(
        ActiveWorkoutHiveModel(
          timedElapsedMs: nextState.timedElapsedMs,
          timedStartedAt: nextState.timedStartedAt,
          timedTotalSeconds: nextState.timedTotalSeconds,
          timedPrescription: nextState.timedPrescription,
          trainingId: trainingId,
          sessionId: nextState.sessionId,
          exerciseId: exerciseId,
          currentSet: nextState.persistedCurrentSet,
          completedSets: nextState.completedSets,
          restEndsAt: nextState.isResting ? nextState.restEndsAt : null,
          lastWeightKg: nextState.weightKg,
          completedSetData: nextState.setPerformances
              .map((set) => set.toJson())
              .toList(),
          lastSetFeedbackClientUploadId:
              nextState.lastSetFeedbackClientUploadId,
          completionOperationId: nextState.completionOperationId,
          lastSetLoggedAt: nextState.lastSetLoggedAt,
        ),
      );
      return true;
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
      return false;
    }
  }
}
