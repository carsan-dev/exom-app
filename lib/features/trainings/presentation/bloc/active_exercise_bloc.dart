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

  const StartExercise({required this.trainingId, required this.exerciseId});
}

class CompleteSet extends ActiveExerciseEvent {
  final int? reps;
  final int? seconds;
  final double? weightKg;
  final String? lastSetFeedbackClientUploadId;

  const CompleteSet({
    this.reps,
    this.seconds,
    this.weightKg,
    this.lastSetFeedbackClientUploadId,
  });
}

class SkipRest extends ActiveExerciseEvent {
  const SkipRest();
}

class FinishRest extends ActiveExerciseEvent {
  const FinishRest();
}

class AbandonExercise extends ActiveExerciseEvent {
  const AbandonExercise();
}

class ActiveExerciseState {
  static const _unset = Object();

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

  const ActiveExerciseState({
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
  });

  factory ActiveExerciseState.initial(
    TrainingExerciseEntity trainingExercise, {
    double? initialWeightKg,
  }) {
    return ActiveExerciseState(
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

  bool get isExecuting => status == ActiveExerciseStatus.executing;
  bool get isResting =>
      status == ActiveExerciseStatus.resting ||
      status == ActiveExerciseStatus.finalResting;
  bool get isFinalResting => status == ActiveExerciseStatus.finalResting;
  bool get isDone => status == ActiveExerciseStatus.done;

  ActiveExerciseState copyWith({
    int? currentSet,
    int? totalSets,
    int? completedSets,
    String? repsOrDuration,
    Object? weightKg = _unset,
    List<SetPerformance>? setPerformances,
    int? restSeconds,
    ActiveExerciseStatus? status,
    Object? restEndsAt = _unset,
    Object? errorMessage = _unset,
    Object? lastSetFeedbackClientUploadId = _unset,
  }) {
    return ActiveExerciseState(
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
    );
  }
}

class ActiveExerciseBloc
    extends Bloc<ActiveExerciseEvent, ActiveExerciseState> {
  final ActiveWorkoutLocalStore _localStorage;
  final TrainingExerciseEntity _trainingExercise;
  final double? _initialWeightKg;
  final RestTimerCoordinator _restTimerCoordinator;
  String? _trainingId;
  String? _exerciseId;

  ActiveExerciseBloc({
    required ActiveWorkoutLocalStore localStorage,
    required TrainingExerciseEntity trainingExercise,
    RestTimerCoordinator? restTimerCoordinator,
    double? initialWeightKg,
  }) : _localStorage = localStorage,
       _trainingExercise = trainingExercise,
       _restTimerCoordinator =
           restTimerCoordinator ?? PlatformRestTimerCoordinator(),
       _initialWeightKg = initialWeightKg,
       super(
         ActiveExerciseState.initial(
           trainingExercise,
           initialWeightKg: initialWeightKg,
         ),
       ) {
    on<StartExercise>(_onStartExercise);
    on<CompleteSet>(_onCompleteSet);
    on<SkipRest>(_onSkipRest);
    on<FinishRest>(_onFinishRest);
    on<AbandonExercise>(_onAbandonExercise);
  }

  Future<void> _onStartExercise(
    StartExercise event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    _trainingId = event.trainingId;
    _exerciseId = event.exerciseId;

    final saved = _localStorage.getActiveWorkout(event.exerciseId);
    if (saved != null && saved.trainingId == event.trainingId) {
      final restored = _restoreState(saved);
      emit(restored.copyWith(errorMessage: null));
      if (restored.isDone) {
        await _restTimerCoordinator.cancel();
        await _removeSavedProgress(emit);
      } else {
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
    emit(initial);
    await _persistState(initial, emit);
  }

  Future<void> _onCompleteSet(
    CompleteSet event,
    Emitter<ActiveExerciseState> emit,
  ) async {
    if (!state.isExecuting) return;

    final nextCompletedSets = state.completedSets + 1;
    final nextWeight = event.weightKg ?? state.weightKg;
    final nextPerformances =
        event.reps == null && event.seconds == null && event.weightKg == null
        ? state.setPerformances
        : [
            ...state.setPerformances,
            SetPerformance(
              setNumber: nextCompletedSets,
              reps: event.reps,
              seconds: event.seconds,
              weightKg: event.weightKg,
            ),
          ];

    if (nextCompletedSets >= state.totalSets) {
      if (state.restSeconds > 0) {
        final finalRestingState = state.copyWith(
          completedSets: state.totalSets,
          currentSet: state.totalSets,
          weightKg: nextWeight,
          setPerformances: nextPerformances,
          status: ActiveExerciseStatus.finalResting,
          restEndsAt: DateTime.now().add(Duration(seconds: state.restSeconds)),
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
      final doneState = state.copyWith(
        completedSets: state.totalSets,
        currentSet: state.totalSets,
        weightKg: nextWeight,
        setPerformances: nextPerformances,
        status: ActiveExerciseStatus.done,
        restEndsAt: null,
        errorMessage: null,
        lastSetFeedbackClientUploadId:
            event.lastSetFeedbackClientUploadId ??
            state.lastSetFeedbackClientUploadId,
      );
      emit(doneState);
      await _restTimerCoordinator.cancel();
      await _removeSavedProgress(emit);
      return;
    }

    final nextSet = nextCompletedSets + 1;
    if (state.restSeconds <= 0) {
      final executingState = state.copyWith(
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

    final restingState = state.copyWith(
      completedSets: nextCompletedSets,
      currentSet: nextSet,
      weightKg: nextWeight,
      setPerformances: nextPerformances,
      status: ActiveExerciseStatus.resting,
      restEndsAt: DateTime.now().add(Duration(seconds: state.restSeconds)),
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
    await _leaveRest(emit, finishedNaturally: true);
  }

  Future<void> _leaveRest(
    Emitter<ActiveExerciseState> emit, {
    required bool finishedNaturally,
  }) async {
    if (!state.isResting) return;

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
      );
      emit(doneState);
      await _removeSavedProgress(emit);
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
    await _restTimerCoordinator.cancel();
    await _persistState(state.copyWith(errorMessage: null), emit);
  }

  ActiveExerciseState _restoreState(ActiveWorkoutHiveModel saved) {
    final totalSets = _trainingExercise.sets;
    final completedSets = saved.completedSets.clamp(0, totalSets);

    final now = DateTime.now();
    final hasPendingRest =
        saved.restEndsAt != null && saved.restEndsAt!.isAfter(now);
    final currentSet = hasPendingRest
        ? saved.currentSet.clamp(1, totalSets)
        : (completedSets + 1).clamp(1, totalSets);

    return ActiveExerciseState(
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
            ),
          )
          .toList(),
      restSeconds: _trainingExercise.restSeconds < 0
          ? 0
          : _trainingExercise.restSeconds,
      status: completedSets >= totalSets
          ? hasPendingRest
                ? ActiveExerciseStatus.finalResting
                : ActiveExerciseStatus.done
          : hasPendingRest
          ? ActiveExerciseStatus.resting
          : ActiveExerciseStatus.executing,
      restEndsAt: hasPendingRest ? saved.restEndsAt : null,
      lastSetFeedbackClientUploadId: saved.lastSetFeedbackClientUploadId,
    );
  }

  Future<void> _startNativeRest(ActiveExerciseState restState) {
    final exerciseId = _exerciseId ?? _trainingExercise.exercise.id;
    return _restTimerCoordinator.start(
      RestTimerSession(
        id: '${_trainingId ?? ''}:$exerciseId:${restState.restEndsAt!.millisecondsSinceEpoch}',
        exerciseName: _trainingExercise.exercise.name,
        durationSeconds: restState.restSeconds,
        endsAt: restState.restEndsAt!,
      ),
    );
  }

  Future<void> _persistState(
    ActiveExerciseState nextState,
    Emitter<ActiveExerciseState> emit,
  ) async {
    final trainingId = _trainingId;
    final exerciseId = _exerciseId;
    if (trainingId == null || exerciseId == null) {
      return;
    }

    try {
      await _localStorage.saveActiveWorkout(
        ActiveWorkoutHiveModel(
          trainingId: trainingId,
          exerciseId: exerciseId,
          currentSet: nextState.currentSet,
          completedSets: nextState.completedSets,
          restEndsAt: nextState.isResting ? nextState.restEndsAt : null,
          lastWeightKg: nextState.weightKg,
          completedSetData: nextState.setPerformances
              .map((set) => set.toJson())
              .toList(),
          lastSetFeedbackClientUploadId:
              nextState.lastSetFeedbackClientUploadId,
        ),
      );
    } catch (error) {
      emit(nextState.copyWith(errorMessage: error.toString()));
    }
  }

  Future<void> _removeSavedProgress(Emitter<ActiveExerciseState> emit) async {
    final exerciseId = _exerciseId;
    if (exerciseId == null) return;

    try {
      await _localStorage.removeActiveWorkout(exerciseId);
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
    }
  }
}
