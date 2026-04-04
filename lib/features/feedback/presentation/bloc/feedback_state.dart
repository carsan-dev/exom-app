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

class FeedbackLoaded extends FeedbackState {
  final List<FeedbackEntity> items;
  const FeedbackLoaded(this.items);
}

class FeedbackSubmitting extends FeedbackLoaded {
  const FeedbackSubmitting(super.items);
}

class FeedbackSubmitSuccess extends FeedbackLoaded {
  const FeedbackSubmitSuccess(super.items);
}

class FeedbackError extends FeedbackLoaded {
  final String message;
  const FeedbackError(this.message, [super.items = const []]);
}
