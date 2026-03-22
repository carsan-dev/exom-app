part of 'metrics_bloc.dart';

abstract class MetricsEvent {
  const MetricsEvent();
}

class MetricsLoadRequested extends MetricsEvent {
  const MetricsLoadRequested();
}

class MetricsSaveRequested extends MetricsEvent {
  final Map<String, dynamic> data;
  const MetricsSaveRequested(this.data);
}
