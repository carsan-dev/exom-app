part of 'feedback_bloc.dart';

abstract class FeedbackEvent {
  const FeedbackEvent();
}

class FeedbackLoadRequested extends FeedbackEvent {
  const FeedbackLoadRequested();
}

class FeedbackSubmitRequested extends FeedbackEvent {
  final String mediaType;
  final String mediaUrl;
  final String? notes;
  final String? exerciseId;

  const FeedbackSubmitRequested({
    required this.mediaType,
    required this.mediaUrl,
    this.notes,
    this.exerciseId,
  });
}
