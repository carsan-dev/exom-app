import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:exom_app/core/api/api_client.dart';
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
      emit(TrainingError(e.toString()));
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
        TrainingError(
          e.toString(),
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
          previousPerformances: previousPerformances,
          selectedDate: targetDate,
          clientNote: progress.note,
          adminReplyText: progress.adminReplyText,
          adminReplySentAt: progress.adminReplySentAt,
        ),
      );
    } catch (e) {
      emit(TrainingError(e.toString()));
    }
  }

  Future<void> _onMarkExerciseCompleted(
    MarkExerciseCompleted event,
    Emitter<TrainingState> emit,
  ) async {
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
      emit(
        current.copyWith(
          completedExerciseIds: updated,
          exerciseWeights: updatedWeights,
          currentPerformances: updatedPerformances,
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
          );
        } else {
          await _unmarkExerciseCompletedUseCase(event.trainingExerciseId, date);
        }
        event.completion?.complete();
      } catch (e) {
        emit(
          current.copyWith(
            completedExerciseIds: previous,
            exerciseWeights: previousWeights,
            currentPerformances: previousPerformances,
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
    if (current is! TrainingDetailLoaded) {
      return;
    }

    final allExerciseIds = current.training.exercises
        .map((trainingExercise) => trainingExercise.id)
        .toSet();
    final previous = Set<String>.from(current.completedExerciseIds);

    emit(current.copyWith(completedExerciseIds: allExerciseIds));

    try {
      await _completeTrainingUseCase(
        current.selectedDate,
        trainingId: current.training.id,
        notes: event.notes,
      );
    } catch (_) {
      emit(current.copyWith(completedExerciseIds: previous));
    }
  }
}
