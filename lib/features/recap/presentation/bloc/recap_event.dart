part of 'recap_bloc.dart';

abstract class RecapEvent {
  const RecapEvent();
}

class RecapLoadRequested extends RecapEvent {
  const RecapLoadRequested();
}

class RecapCreateRequested extends RecapEvent {
  const RecapCreateRequested();
}

class RecapFormStarted extends RecapEvent {
  final String? recapId;
  final Map<String, dynamic> initialData;

  const RecapFormStarted({required this.initialData, this.recapId});
}

class RecapFieldUpdated extends RecapEvent {
  final String field;
  final dynamic value;

  const RecapFieldUpdated({required this.field, required this.value});
}

class RecapStepChanged extends RecapEvent {
  final int step;

  const RecapStepChanged(this.step);
}

class RecapSaveRequested extends RecapEvent {
  const RecapSaveRequested();
}

class RecapSubmitRequested extends RecapEvent {
  final String? recapId;

  const RecapSubmitRequested({this.recapId});
}

class RecapFormCancelled extends RecapEvent {
  const RecapFormCancelled();
}
