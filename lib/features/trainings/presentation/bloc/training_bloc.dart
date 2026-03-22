import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';

part 'training_event.dart';
part 'training_state.dart';

class TrainingBloc extends Bloc<TrainingEvent, TrainingState> {
  final GetTodayTrainingUseCase _getTodayTrainingUseCase;
  final GetTrainingsUseCase _getTrainingsUseCase;
  final GetTrainingUseCase _getTrainingUseCase;
  final MarkExerciseCompletedUseCase _markExerciseCompletedUseCase;
  final GetCompletedExercisesUseCase _getCompletedExercisesUseCase;

  TrainingBloc({
    required GetTodayTrainingUseCase getTodayTrainingUseCase,
    required GetTrainingsUseCase getTrainingsUseCase,
    required GetTrainingUseCase getTrainingUseCase,
    required MarkExerciseCompletedUseCase markExerciseCompletedUseCase,
    required GetCompletedExercisesUseCase getCompletedExercisesUseCase,
  })  : _getTodayTrainingUseCase = getTodayTrainingUseCase,
        _getTrainingsUseCase = getTrainingsUseCase,
        _getTrainingUseCase = getTrainingUseCase,
        _markExerciseCompletedUseCase = markExerciseCompletedUseCase,
        _getCompletedExercisesUseCase = getCompletedExercisesUseCase,
        super(const TrainingInitial()) {
    on<TodayTrainingLoadRequested>(_onTodayTrainingLoad);
    on<TrainingsLoadRequested>(_onTrainingsLoad);
    on<TrainingDetailLoadRequested>(_onTrainingDetailLoad);
    on<MarkExerciseCompleted>(_onMarkExerciseCompleted);
  }

  Future<void> _onTodayTrainingLoad(
    TodayTrainingLoadRequested event,
    Emitter<TrainingState> emit,
  ) async {
    emit(const TrainingLoading());
    try {
      final training = await _getTodayTrainingUseCase();
      if (training == null) {
        emit(const TrainingNoContent());
      } else {
        emit(TodayTrainingLoaded(training));
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
      final results = await Future.wait([
        _getTrainingsUseCase(),
        _getTodayTrainingUseCase(),
      ]);
      emit(TrainingsLoaded(
        trainings: results[0] as List<TrainingEntity>,
        todayTraining: results[1] as TrainingEntity?,
      ));
    } catch (e) {
      emit(TrainingError(e.toString()));
    }
  }

  Future<void> _onTrainingDetailLoad(
    TrainingDetailLoadRequested event,
    Emitter<TrainingState> emit,
  ) async {
    emit(const TrainingLoading());
    try {
      final results = await Future.wait([
        _getTrainingUseCase(event.id),
        _getCompletedExercisesUseCase(),
      ]);
      emit(TrainingDetailLoaded(
        results[0] as TrainingEntity,
        completedExerciseIds: results[1] as Set<String>,
      ));
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
      // Optimistic update (store exercise_id to match server format)
      final updated = Set<String>.from(current.completedExerciseIds);
      if (event.completed) {
        updated.add(event.exerciseId);
      } else {
        updated.remove(event.exerciseId);
      }
      emit(current.copyWith(completedExerciseIds: updated));

      // Sync with backend (fire-and-forget, best effort)
      if (event.completed) {
        try {
          final today = DateTime.now();
          final date =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          await _markExerciseCompletedUseCase(event.exerciseId, date);
        } catch (_) {
          // Don't revert UI on failure — progress is informational
        }
      }
    }
  }
}
