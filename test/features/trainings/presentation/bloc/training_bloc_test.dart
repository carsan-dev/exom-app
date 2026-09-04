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
  test('completion keeps selected date and exposes backend rejection', () async {
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
      const TrainingDetailLoadRequested(
        'training-1',
        date: '2026-09-05',
      ),
    );
    await loaded;

    final failed = bloc.stream.firstWhere(
      (state) =>
          state is TrainingDetailLoaded && state.errorMessage != null,
    );
    bloc.add(const CompleteTrainingRequested());
    final state = await failed as TrainingDetailLoaded;

    expect(repository.completedDate, '2026-09-05');
    expect(state.selectedDate, '2026-09-05');
    expect(state.errorMessage, 'Entrenamiento no asignado para esa fecha');
  });
}

class _FailingCompletionRepository implements TrainingRepository {
  String? completedDate;

  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
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
  }) async {}

  @override
  Future<void> unmarkExerciseCompleted(
    String trainingExerciseId,
    String date,
  ) async {}
}
