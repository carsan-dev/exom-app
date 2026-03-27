part of 'training_bloc.dart';

abstract class TrainingEvent {
  const TrainingEvent();
}

class TrainingsLoadRequested extends TrainingEvent {
  final String? date;

  const TrainingsLoadRequested({this.date});
}

class TodayTrainingLoadRequested extends TrainingEvent {
  final String? date;

  const TodayTrainingLoadRequested({this.date});
}

class TrainingDetailLoadRequested extends TrainingEvent {
  final String id;
  final String? date;

  const TrainingDetailLoadRequested(this.id, {this.date});
}

class MarkExerciseCompleted extends TrainingEvent {
  final String trainingExerciseId;
  final String exerciseId;
  final bool completed;
  final double? weightUsed;
  const MarkExerciseCompleted({
    required this.trainingExerciseId,
    required this.exerciseId,
    required this.completed,
    this.weightUsed,
  });
}

class CompleteTrainingRequested extends TrainingEvent {
  final String? notes;

  const CompleteTrainingRequested({this.notes});
}
