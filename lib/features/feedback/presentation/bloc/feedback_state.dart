part of 'feedback_bloc.dart';

abstract class FeedbackState {
  const FeedbackState();
}

class FeedbackInitial extends FeedbackState {
  const FeedbackInitial();
}

class FeedbackLoading extends FeedbackState {
  const FeedbackLoading();
}

class FeedbackSubmitting extends FeedbackState {
  const FeedbackSubmitting();
}

class FeedbackLoaded extends FeedbackState {
  final List<FeedbackEntity> items;
  const FeedbackLoaded(this.items);
}

class FeedbackSubmitSuccess extends FeedbackLoaded {
  const FeedbackSubmitSuccess(super.items);
}

class FeedbackError extends FeedbackState {
  final String message;
  const FeedbackError(this.message);
}
