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
  final List<TrainingEntity> todayTrainings;
  final String selectedDate;
  final String historyDate;

  const TrainingsLoaded({
    required this.history,
    this.todayTrainings = const [],
    required this.selectedDate,
    required this.historyDate,
  });
}

class TodayTrainingLoaded extends TrainingState {
  final List<TrainingEntity> trainings;
  final String selectedDate;

  const TodayTrainingLoaded(this.trainings, {required this.selectedDate});
}

class TrainingDetailLoaded extends TrainingState {
  final TrainingEntity training;
  final Set<String> completedExerciseIds;
  final String selectedDate;
  final Map<String, double> exerciseWeights;
  final Map<String, List<SetPerformance>> currentPerformances;
  final Map<String, List<SetPerformance>> previousPerformances;
  final String? clientNote;
  final String? adminReplyText;
  final DateTime? adminReplySentAt;
  final String? errorMessage;
  final bool isCompleting;

  const TrainingDetailLoaded(
    this.training, {
    this.completedExerciseIds = const {},
    required this.selectedDate,
    this.exerciseWeights = const {},
    this.currentPerformances = const {},
    this.previousPerformances = const {},
    this.clientNote,
    this.adminReplyText,
    this.adminReplySentAt,
    this.errorMessage,
    this.isCompleting = false,
  });

  TrainingDetailLoaded copyWith({
    TrainingEntity? training,
    Set<String>? completedExerciseIds,
    String? selectedDate,
    Map<String, double>? exerciseWeights,
    Map<String, List<SetPerformance>>? currentPerformances,
    Map<String, List<SetPerformance>>? previousPerformances,
    String? clientNote,
    String? adminReplyText,
    DateTime? adminReplySentAt,
    String? errorMessage,
    bool? isCompleting,
  }) {
    return TrainingDetailLoaded(
      training ?? this.training,
      completedExerciseIds: completedExerciseIds ?? this.completedExerciseIds,
      selectedDate: selectedDate ?? this.selectedDate,
      exerciseWeights: exerciseWeights ?? this.exerciseWeights,
      currentPerformances: currentPerformances ?? this.currentPerformances,
      previousPerformances: previousPerformances ?? this.previousPerformances,
      clientNote: clientNote ?? this.clientNote,
      adminReplyText: adminReplyText ?? this.adminReplyText,
      adminReplySentAt: adminReplySentAt ?? this.adminReplySentAt,
      errorMessage: errorMessage,
      isCompleting: isCompleting ?? this.isCompleting,
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
