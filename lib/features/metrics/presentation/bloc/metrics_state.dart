part of 'metrics_bloc.dart';

abstract class MetricsState {
  const MetricsState();
}

class MetricsInitial extends MetricsState {
  const MetricsInitial();
}

class MetricsSaving extends MetricsState {
  const MetricsSaving();
}

class MetricsSaved extends MetricsState {
  const MetricsSaved();
}

class MetricsError extends MetricsState {
  final String message;
  const MetricsError(this.message);
}
