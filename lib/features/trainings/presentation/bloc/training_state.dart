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
  const TrainingsLoaded({required this.trainings, this.todayTraining});
}

class TodayTrainingLoaded extends TrainingState {
  final TrainingEntity? training;
  const TodayTrainingLoaded(this.training);
}

class TrainingDetailLoaded extends TrainingState {
  final TrainingEntity training;
  final Set<String> completedExerciseIds;
  const TrainingDetailLoaded(this.training, {this.completedExerciseIds = const {}});

  TrainingDetailLoaded copyWith({TrainingEntity? training, Set<String>? completedExerciseIds}) {
    return TrainingDetailLoaded(
      training ?? this.training,
      completedExerciseIds: completedExerciseIds ?? this.completedExerciseIds,
    );
  }
}

class TrainingError extends TrainingState {
  final String message;
  const TrainingError(this.message);
}

class TrainingNoContent extends TrainingState {
  const TrainingNoContent();
}
