part of 'training_bloc.dart';

abstract class TrainingEvent {
  const TrainingEvent();
}

class TrainingsLoadRequested extends TrainingEvent {
  final String? date;
  final String? historyDate;

  const TrainingsLoadRequested({this.date, this.historyDate});
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
  final List<SetPerformance>? sets;
  final Completer<void>? completion;
  const MarkExerciseCompleted({
    required this.trainingExerciseId,
    required this.exerciseId,
    required this.completed,
    this.weightUsed,
    this.sets,
    this.completion,
  });
}

class CompleteTrainingRequested extends TrainingEvent {
  final String? notes;

  const CompleteTrainingRequested({this.notes});
}
