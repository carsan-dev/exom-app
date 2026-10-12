import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/normalize_training_progress.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_previous_exercise_performances_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/unmark_exercise_completed_usecase.dart';

part 'training_event.dart';
part 'training_state.dart';

class TrainingBloc extends Bloc<TrainingEvent, TrainingState> {
  final GetTodayTrainingUseCase _getTodayTrainingUseCase;
  final GetTrainingsUseCase _getTrainingsUseCase;
  final GetTrainingUseCase _getTrainingUseCase;
  final MarkExerciseCompletedUseCase _markExerciseCompletedUseCase;
  final UnmarkExerciseCompletedUseCase _unmarkExerciseCompletedUseCase;
  final CompleteTrainingUseCase _completeTrainingUseCase;
  final GetCompletedExercisesUseCase _getCompletedExercisesUseCase;
  final GetPreviousExercisePerformancesUseCase
  _getPreviousExercisePerformancesUseCase;

  TrainingBloc({
    required GetTodayTrainingUseCase getTodayTrainingUseCase,
    required GetTrainingsUseCase getTrainingsUseCase,
    required GetTrainingUseCase getTrainingUseCase,
    required MarkExerciseCompletedUseCase markExerciseCompletedUseCase,
    required UnmarkExerciseCompletedUseCase unmarkExerciseCompletedUseCase,
    required CompleteTrainingUseCase completeTrainingUseCase,
    required GetCompletedExercisesUseCase getCompletedExercisesUseCase,
    required GetPreviousExercisePerformancesUseCase
    getPreviousExercisePerformancesUseCase,
  }) : _getTodayTrainingUseCase = getTodayTrainingUseCase,
       _getTrainingsUseCase = getTrainingsUseCase,
       _getTrainingUseCase = getTrainingUseCase,
       _markExerciseCompletedUseCase = markExerciseCompletedUseCase,
       _unmarkExerciseCompletedUseCase = unmarkExerciseCompletedUseCase,
       _completeTrainingUseCase = completeTrainingUseCase,
       _getCompletedExercisesUseCase = getCompletedExercisesUseCase,
       _getPreviousExercisePerformancesUseCase =
           getPreviousExercisePerformancesUseCase,
       super(const TrainingInitial()) {
    on<TodayTrainingLoadRequested>(_onTodayTrainingLoad);
    on<TrainingsLoadRequested>(_onTrainingsLoad);
    on<TrainingDetailLoadRequested>(_onTrainingDetailLoad);
    on<MarkExerciseCompleted>(_onMarkExerciseCompleted);
    on<CompleteTrainingRequested>(_onCompleteTrainingRequested);
  }

  String _todayDate() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  String _resolvedDate(String? date) => date ?? _todayDate();

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onTodayTrainingLoad(
    TodayTrainingLoadRequested event,
    Emitter<TrainingState> emit,
  ) async {
    emit(const TrainingLoading());
    try {
      final targetDate = _resolvedDate(event.date);
      final trainings = await _getTodayTrainingUseCase(targetDate);
      if (trainings.isEmpty) {
        emit(TrainingNoContent(selectedDate: targetDate));
      } else {
        emit(TodayTrainingLoaded(trainings, selectedDate: targetDate));
      }
    } catch (e) {
      emit(TrainingError.from(e));
    }
  }

  Future<void> _onTrainingsLoad(
    TrainingsLoadRequested event,
    Emitter<TrainingState> emit,
  ) async {
    emit(const TrainingLoading());
    try {
      final targetDate = _resolvedDate(event.date);
      final historyDate = _resolvedDate(event.historyDate ?? event.date);
      final results = await Future.wait([
        _getTrainingsUseCase(date: historyDate),
        _getTodayTrainingUseCase(targetDate),
      ]);
      final history = (results[0] as List<TrainingHistoryEntity>)
          .where((entry) => _dateKey(entry.date) != targetDate)
          .toList(growable: false);
      emit(
        TrainingsLoaded(
          history: history,
          todayTrainings: results[1] as List<TrainingEntity>,
          selectedDate: targetDate,
          historyDate: historyDate,
        ),
      );
    } catch (e) {
      emit(
        TrainingError.from(
          e,
          selectedDate: _resolvedDate(event.date),
          historyDate: _resolvedDate(event.historyDate ?? event.date),
        ),
      );
    }
  }

  Future<void> _onTrainingDetailLoad(
    TrainingDetailLoadRequested event,
    Emitter<TrainingState> emit,
  ) async {
    emit(const TrainingLoading());
    try {
      final targetDate = _resolvedDate(event.date);
      final training = await _getTrainingUseCase(event.id, date: targetDate);
      var progress = const TrainingDayProgress();
      try {
        progress = await _getCompletedExercisesUseCase(targetDate);
      } catch (_) {}
      final normalizedProgress = normalizeTrainingProgress(
        training: training,
        rawIds: progress.ids,
        rawWeights: progress.weights,
        rawPerformances: progress.performances,
      );
      var previousPerformances = <String, List<SetPerformance>>{};
      try {
        final previousByExerciseId =
            await _getPreviousExercisePerformancesUseCase(
              training.exercises
                  .map((trainingExercise) => trainingExercise.exercise.id)
                  .toList(growable: false),
              targetDate,
            );
        previousPerformances = {
          for (final trainingExercise in training.exercises)
            if (previousByExerciseId[trainingExercise.exercise.id] != null)
              trainingExercise.id:
                  previousByExerciseId[trainingExercise.exercise.id]!,
        };
      } catch (_) {}
      emit(
        TrainingDetailLoaded(
          training,
          completedExerciseIds: normalizedProgress.ids,
          exerciseWeights: normalizedProgress.weights,
          currentPerformances: normalizedProgress.performances,
          sessionProgress: {
            for (final sessionId in progress.sessions.keys)
              sessionId: () {
                final scoped = progress.forSession(sessionId, training.id);
                final normalized = normalizeTrainingProgress(
                  training: training,
                  rawIds: scoped.ids,
                  rawWeights: scoped.weights,
                  rawPerformances: scoped.performances,
                );
                return TrainingDayProgress(
                  ids: normalized.ids,
                  weights: normalized.weights,
                  performances: normalized.performances,
                );
              }(),
          },
          previousPerformances: previousPerformances,
          selectedDate: targetDate,
          clientNote: progress.note,
          adminReplyText: progress.adminReplyText,
          adminReplySentAt: progress.adminReplySentAt,
        ),
      );
    } catch (e) {
      emit(TrainingError.from(e));
    }
  }

  bool _matchesSession(String? stamp) =>
      stamp == null || sl<LocalStorage>().sessionStamp == stamp;

  Future<void> _onMarkExerciseCompleted(
    MarkExerciseCompleted event,
    Emitter<TrainingState> emit,
  ) async {
    if (event.sessionStamp == null || !_matchesSession(event.sessionStamp)) {
      event.completion?.completeError(const LocalSessionChanged());
      return;
    }
    final current = state;
    if (current is TrainingDetailLoaded) {
      final previous = Set<String>.from(current.completedExerciseIds);
      final previousWeights = Map<String, double>.from(current.exerciseWeights);
      final previousPerformances = Map<String, List<SetPerformance>>.from(
        current.currentPerformances,
      );
      final updated = Set<String>.from(current.completedExerciseIds);
      final updatedWeights = Map<String, double>.from(current.exerciseWeights);
      final updatedPerformances = Map<String, List<SetPerformance>>.from(
        current.currentPerformances,
      );

      if (event.completed) {
        updated.add(event.trainingExerciseId);
        if (event.weightUsed != null) {
          updatedWeights[event.trainingExerciseId] = event.weightUsed!;
        }
        if (event.sets != null) {
          updatedPerformances[event.trainingExerciseId] = event.sets!;
        }
      } else {
        updated.remove(event.trainingExerciseId);
        updatedWeights.remove(event.trainingExerciseId);
        updatedPerformances.remove(event.trainingExerciseId);
      }
      final previousSessionProgress = current.sessionProgress;
      final scoped = event.sessionId == null ? null :
          current.sessionProgress[event.sessionId] ?? const TrainingDayProgress();
      Map<String, TrainingDayProgress>? updatedSessions;
      if (scoped != null) {
        final ids = Set<String>.from(scoped.ids);
        final weights = Map<String, double>.from(scoped.weights);
        final performances = Map<String, List<SetPerformance>>.from(scoped.performances);
        if (event.completed) {
          ids.add(event.trainingExerciseId);
          if (event.weightUsed != null) weights[event.trainingExerciseId] = event.weightUsed!;
          if (event.sets != null) performances[event.trainingExerciseId] = event.sets!;
        } else {
          ids.remove(event.trainingExerciseId);
          weights.remove(event.trainingExerciseId);
          performances.remove(event.trainingExerciseId);
        }
        updatedSessions = {...current.sessionProgress, event.sessionId!: TrainingDayProgress(
          ids: ids, weights: weights, performances: performances)};
      }
      emit(
        current.copyWith(
          completedExerciseIds: updated,
          exerciseWeights: updatedWeights,
          currentPerformances: updatedPerformances,
          sessionProgress: updatedSessions,
        ),
      );

      try {
        final date = current.selectedDate;
        if (event.completed) {
          await _markExerciseCompletedUseCase(
            event.trainingExerciseId,
            event.exerciseId,
            date,
            weightUsed: event.weightUsed,
            sets: event.sets,
            lastSetFeedbackClientUploadId: event.lastSetFeedbackClientUploadId,
            trainingId: current.training.id,
            sessionId: event.sessionId,
            operationId: event.operationId,
          );
        } else {
          await _unmarkExerciseCompletedUseCase(event.trainingExerciseId, date, sessionId: event.sessionId);
        }
        if (!_matchesSession(event.sessionStamp)) {
          event.completion?.completeError(const LocalSessionChanged());
          return;
        }
        event.completion?.complete();
      } catch (e) {
        if (!_matchesSession(event.sessionStamp)) {
          event.completion?.completeError(const LocalSessionChanged());
          return;
        }
        emit(
          current.copyWith(
            completedExerciseIds: previous,
            exerciseWeights: previousWeights,
            currentPerformances: previousPerformances,
            sessionProgress: previousSessionProgress,
            errorMessage:
                ApiException.maybeFrom(e)?.message ??
                'No se pudo guardar el progreso. Inténtalo de nuevo.',
          ),
        );
        event.completion?.completeError(e);
      }
    }
  }

  Future<void> _onCompleteTrainingRequested(
    CompleteTrainingRequested event,
    Emitter<TrainingState> emit,
  ) async {
    final current = state;
    if (event.sessionStamp == null || !_matchesSession(event.sessionStamp)) {
      event.completion?.completeError(const LocalSessionChanged());
      return;
    }
    if (current is! TrainingDetailLoaded || current.isCompleting) {
      event.completion?.completeError(StateError('Training completion unavailable'));
      return;
    }

    final allExerciseIds = current.training.exercises
        .map((trainingExercise) => trainingExercise.id)
        .toSet();
    emit(current.copyWith(isCompleting: true));

    try {
      await _completeTrainingUseCase(
        current.selectedDate,
        trainingId: current.training.id,
        sessionId: event.sessionId,
        rpe: event.rpe,
        notes: event.notes,
      );
      if (!_matchesSession(event.sessionStamp)) {
        event.completion?.completeError(const LocalSessionChanged());
        return;
      }
      event.completion?.complete();
      final latest = state;
      if (latest is TrainingDetailLoaded &&
          latest.training.id == current.training.id &&
          latest.selectedDate == current.selectedDate) {
        emit(
          latest.copyWith(
            completedExerciseIds: allExerciseIds,
            sessionProgress: event.sessionId == null ? null : {
              ...latest.sessionProgress,
              event.sessionId!: TrainingDayProgress(ids: allExerciseIds,
                weights: latest.sessionProgress[event.sessionId]?.weights ?? const {},
                performances: latest.sessionProgress[event.sessionId]?.performances ?? const {}),
            },
            isCompleting: false,
          ),
        );
      }
    } catch (error) {
      if (!_matchesSession(event.sessionStamp)) {
        event.completion?.completeError(const LocalSessionChanged());
        return;
      }
      event.completion?.completeError(error);
      final latest = state;
      if (latest is! TrainingDetailLoaded ||
          latest.training.id != current.training.id ||
          latest.selectedDate != current.selectedDate) {
        return;
      }
      emit(
        latest.copyWith(
          isCompleting: false,
          errorMessage:
              ApiException.maybeFrom(error)?.message ??
              'No se pudo completar el entrenamiento. Inténtalo de nuevo.',
        ),
      );
    }
  }
}
