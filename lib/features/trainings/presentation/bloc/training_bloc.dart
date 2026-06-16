import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
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

  TrainingBloc({
    required GetTodayTrainingUseCase getTodayTrainingUseCase,
    required GetTrainingsUseCase getTrainingsUseCase,
    required GetTrainingUseCase getTrainingUseCase,
    required MarkExerciseCompletedUseCase markExerciseCompletedUseCase,
    required UnmarkExerciseCompletedUseCase unmarkExerciseCompletedUseCase,
    required CompleteTrainingUseCase completeTrainingUseCase,
    required GetCompletedExercisesUseCase getCompletedExercisesUseCase,
  }) : _getTodayTrainingUseCase = getTodayTrainingUseCase,
       _getTrainingsUseCase = getTrainingsUseCase,
       _getTrainingUseCase = getTrainingUseCase,
       _markExerciseCompletedUseCase = markExerciseCompletedUseCase,
       _unmarkExerciseCompletedUseCase = unmarkExerciseCompletedUseCase,
       _completeTrainingUseCase = completeTrainingUseCase,
       _getCompletedExercisesUseCase = getCompletedExercisesUseCase,
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
      final training = await _getTodayTrainingUseCase(targetDate);
      if (training == null) {
        emit(TrainingNoContent(selectedDate: targetDate));
      } else {
        emit(TodayTrainingLoaded(training, selectedDate: targetDate));
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
          todayTraining: results[1] as TrainingEntity?,
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
      final training = await _getTrainingUseCase(event.id);
      ({Set<String> ids, Map<String, double> weights}) progress = (
        ids: <String>{},
        weights: <String, double>{},
      );
      try {
        progress = await _getCompletedExercisesUseCase(targetDate);
      } catch (_) {}
      emit(
        TrainingDetailLoaded(
          training,
          completedExerciseIds: progress.ids,
          exerciseWeights: progress.weights,
          selectedDate: targetDate,
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
      final updated = Set<String>.from(current.completedExerciseIds);
      final updatedWeights = Map<String, double>.from(current.exerciseWeights);

      if (event.completed) {
        updated.add(event.trainingExerciseId);
        if (event.weightUsed != null) {
          updatedWeights[event.trainingExerciseId] = event.weightUsed!;
        }
      } else {
        updated.remove(event.trainingExerciseId);
        updatedWeights.remove(event.trainingExerciseId);
      }
      emit(
        current.copyWith(
          completedExerciseIds: updated,
          exerciseWeights: updatedWeights,
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
          );
        } else {
          await _unmarkExerciseCompletedUseCase(event.trainingExerciseId, date);
        }
      } catch (e) {
        emit(
          current.copyWith(
            completedExerciseIds: previous,
            exerciseWeights: previousWeights,
            errorMessage: e.toString(),
          ),
        );
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
      await _completeTrainingUseCase(current.selectedDate, notes: event.notes);
    } catch (_) {
      emit(current.copyWith(completedExerciseIds: previous));
    }
  }
}
