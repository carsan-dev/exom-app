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

class FeedbackUploadAndSubmit extends FeedbackEvent {
  final File file;
  final String contentType;
  final String mediaType;
  final String? notes;
  final String? exerciseId;

  const FeedbackUploadAndSubmit({
    required this.file,
    required this.contentType,
    required this.mediaType,
    this.notes,
    this.exerciseId,
  });
}
