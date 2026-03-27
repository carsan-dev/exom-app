part of 'training_bloc.dart';

abstract class TrainingState {
  const TrainingState();
}

class TrainingInitial extends TrainingState {
  const TrainingInitial();
}

class TrainingLoading extends TrainingState {
  const TrainingLoading();
}

class TrainingsLoaded extends TrainingState {
  final List<TrainingEntity> trainings;
  final TrainingEntity? todayTraining;
  final String selectedDate;

  const TrainingsLoaded({
    required this.trainings,
    this.todayTraining,
    required this.selectedDate,
  });
}

class TodayTrainingLoaded extends TrainingState {
  final TrainingEntity? training;
  final String selectedDate;

  const TodayTrainingLoaded(this.training, {required this.selectedDate});
}

class TrainingDetailLoaded extends TrainingState {
  final TrainingEntity training;
  final Set<String> completedExerciseIds;
  final String selectedDate;
  final Map<String, double> exerciseWeights;

  const TrainingDetailLoaded(
    this.training, {
    this.completedExerciseIds = const {},
    required this.selectedDate,
    this.exerciseWeights = const {},
  });

  TrainingDetailLoaded copyWith({
    TrainingEntity? training,
    Set<String>? completedExerciseIds,
    String? selectedDate,
    Map<String, double>? exerciseWeights,
  }) {
    return TrainingDetailLoaded(
      training ?? this.training,
      completedExerciseIds: completedExerciseIds ?? this.completedExerciseIds,
      selectedDate: selectedDate ?? this.selectedDate,
      exerciseWeights: exerciseWeights ?? this.exerciseWeights,
    );
  }
}

class TrainingError extends TrainingState {
  final String message;
  const TrainingError(this.message);
}

class TrainingNoContent extends TrainingState {
  final String selectedDate;

  const TrainingNoContent({required this.selectedDate});
}
