part of 'metrics_bloc.dart';

abstract class MetricsState {
  const MetricsState();
}

class MetricsInitial extends MetricsState {
  const MetricsInitial();
}

class MetricsLoading extends MetricsState {
  const MetricsLoading();
}

class MetricsLoaded extends MetricsState {
  final BodyMetricEntity? current;
  const MetricsLoaded(this.current);
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

// ── «Progreso» view states ──────────────────────────────────────────────────
// Emitted only in answer to [MetricsHistoryRequested]. The day form listens
// for [MetricsLoaded], [MetricsSaved] and [MetricsError] and ignores these.

class MetricsHistoryLoading extends MetricsState {
  const MetricsHistoryLoading();
}

class MetricsHistoryLoaded extends MetricsState {
  /// Weight points as returned by the repository (`/metrics/weight-history`).
  final List<BodyMetricEntity> weightHistory;

  /// Most recent record of any date (`/metrics/latest`), or null.
  final BodyMetricEntity? latest;

  const MetricsHistoryLoaded({required this.weightHistory, this.latest});
}

class MetricsHistoryFailure extends MetricsState {
  /// True when the request failed for lack of connection.
  final bool offline;

  const MetricsHistoryFailure({this.offline = false});
}
