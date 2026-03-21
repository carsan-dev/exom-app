part of 'recap_bloc.dart';

abstract class RecapState {
  const RecapState();
}

class RecapInitial extends RecapState {
  const RecapInitial();
}

class RecapLoading extends RecapState {
  const RecapLoading();
}

class RecapListLoaded extends RecapState {
  final List<RecapEntity> recaps;

  const RecapListLoaded(this.recaps);
}

class RecapFormActive extends RecapState {
  final int step;
  final Map<String, dynamic> formData;
  final String? recapId;

  const RecapFormActive({
    required this.step,
    required this.formData,
    this.recapId,
  });
}

class RecapSubmitted extends RecapListLoaded {
  const RecapSubmitted(super.recaps);
}

class RecapError extends RecapState {
  final String message;

  const RecapError(this.message);
}
