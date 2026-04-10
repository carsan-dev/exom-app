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
  final List<TrainingHistoryEntity> history;
  final TrainingEntity? todayTraining;
  final String selectedDate;
  final String historyDate;

  const TrainingsLoaded({
    required this.history,
    this.todayTraining,
    required this.selectedDate,
    required this.historyDate,
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
  final String? errorMessage;

  const TrainingDetailLoaded(
    this.training, {
    this.completedExerciseIds = const {},
    required this.selectedDate,
    this.exerciseWeights = const {},
    this.errorMessage,
  });

  TrainingDetailLoaded copyWith({
    TrainingEntity? training,
    Set<String>? completedExerciseIds,
    String? selectedDate,
    Map<String, double>? exerciseWeights,
    String? errorMessage,
  }) {
    return TrainingDetailLoaded(
      training ?? this.training,
      completedExerciseIds: completedExerciseIds ?? this.completedExerciseIds,
      selectedDate: selectedDate ?? this.selectedDate,
      exerciseWeights: exerciseWeights ?? this.exerciseWeights,
      errorMessage: errorMessage,
    );
  }
}

class TrainingError extends TrainingState {
  final String message;
  final String? selectedDate;
  final String? historyDate;

  const TrainingError(this.message, {this.selectedDate, this.historyDate});
}

class TrainingNoContent extends TrainingState {
  final String selectedDate;

  const TrainingNoContent({required this.selectedDate});
}
