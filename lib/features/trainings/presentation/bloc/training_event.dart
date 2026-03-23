part of 'training_bloc.dart';

abstract class TrainingEvent {
  const TrainingEvent();
}

class TrainingsLoadRequested extends TrainingEvent {
  const TrainingsLoadRequested();
}

class TodayTrainingLoadRequested extends TrainingEvent {
  const TodayTrainingLoadRequested();
}

class TrainingDetailLoadRequested extends TrainingEvent {
  final String id;
  const TrainingDetailLoadRequested(this.id);
}

class MarkExerciseCompleted extends TrainingEvent {
  final String trainingExerciseId;
  final String exerciseId;
  final bool completed;
  const MarkExerciseCompleted({
    required this.trainingExerciseId,
    required this.exerciseId,
    required this.completed,
  });
}

class CompleteTrainingRequested extends TrainingEvent {
  final String? notes;

  const CompleteTrainingRequested({this.notes});
}
