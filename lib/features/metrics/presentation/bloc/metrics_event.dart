part of 'metrics_bloc.dart';

abstract class MetricsEvent {
  const MetricsEvent();
}

class MetricsSaveRequested extends MetricsEvent {
  final Map<String, dynamic> data;
  const MetricsSaveRequested(this.data);
}
