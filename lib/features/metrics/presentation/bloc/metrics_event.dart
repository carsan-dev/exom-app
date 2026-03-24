part of 'metrics_bloc.dart';

abstract class MetricsEvent {
  const MetricsEvent();
}

class MetricsLoadRequested extends MetricsEvent {
  const MetricsLoadRequested();
}

class MetricsSaveRequested extends MetricsEvent {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? profileData;

  const MetricsSaveRequested(this.data, {this.profileData});
}
