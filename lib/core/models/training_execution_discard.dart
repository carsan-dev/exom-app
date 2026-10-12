/// Identity captured when the UI asks for informed, execution-specific consent.
/// A later confirmation must use this same owner and session generation.
class TrainingExecutionDiscardRequest {
  const TrainingExecutionDiscardRequest({
    required this.ownerId,
    required this.sessionStamp,
    required this.executionId,
    required this.trainingId,
    required this.date,
  });
  final String ownerId;
  final String sessionStamp;
  final String executionId;
  final String trainingId;
  final String date;
}

enum TrainingExecutionDiscardReason {
  eligible,
  discarded,
  alreadyDiscarded,
  wrongOwner,
  staleSession,
  notFound,
  identityMismatch,
  unknownOwnership,
  confirmed,
  inFlight,
  unsentDependencies,
  storageFailure,
}

/// Shared typed inspection/command outcome; inspection is never authorization.
class TrainingExecutionDiscardResult {
  const TrainingExecutionDiscardResult(this.reason);
  final TrainingExecutionDiscardReason reason;
  bool get canDiscard => reason == TrainingExecutionDiscardReason.eligible;
  bool get isDiscarded => reason == TrainingExecutionDiscardReason.discarded ||
      reason == TrainingExecutionDiscardReason.alreadyDiscarded;
}
