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

/// Answer to a [MetricsLoadRequested]: [current] is the metric of the
/// requested day, or null for a day without metrics. A failed load is
/// [MetricsLoadFailed], never a null [current] (L6-UX7).
///
/// Only the newest load emits it; [date] and [request] tag which load it
/// answers.
class MetricsLoaded extends MetricsState {
  final BodyMetricEntity? current;

  /// The `yyyy-MM-dd` date that was requested, or null for the initial
  /// «latest» load.
  final String? date;

  /// Sequence number of the load within its bloc (0 when not set).
  final int request;

  const MetricsLoaded(this.current, {this.date, this.request = 0});
}

/// Answer to a [MetricsLoadRequested] whose load failed: no connection and no
/// cached copy, a server error, a timeout, an unexpected answer or a session
/// change. It is not a day without metrics, so the form must not be saved
/// over it (L6-UX7).
///
/// Only the newest load emits it; [date] and [request] tag which load it
/// answers, as in [MetricsLoaded].
class MetricsLoadFailed extends MetricsState {
  /// The `yyyy-MM-dd` date that was requested, or null for the initial
  /// «latest» load.
  final String? date;

  /// Sequence number of the load within its bloc (0 when not set).
  final int request;

  /// The load failed for lack of connection.
  final bool offline;

  /// The session changed (logout or user switch) while the load was in
  /// flight: the form belongs to the previous session and is not reloaded.
  final bool sessionChanged;

  const MetricsLoadFailed({
    this.date,
    this.request = 0,
    this.offline = false,
    this.sessionChanged = false,
  });
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

/// Why [MetricsHistoryLoaded.latest] is missing.
enum MetricsLatestUnavailability {
  /// The latest record was read: [MetricsHistoryLoaded.latest] is the record,
  /// or null because the account has none.
  none,

  /// The latest-record request failed for lack of connection and there was no
  /// cached copy.
  offline,

  /// The latest-record request failed for another reason (server error,
  /// unexpected answer...).
  error,
}

class MetricsHistoryLoaded extends MetricsState {
  /// Weight points as returned by the repository (`/metrics/weight-history`).
  final List<BodyMetricEntity> weightHistory;

  /// Most recent record of any date (`/metrics/latest`), or null.
  final BodyMetricEntity? latest;

  /// [weightHistory] is the offline cache copy, not the server's answer.
  final bool historyFromCache;

  /// [latest] is the offline cache copy, not the server's answer. Always false
  /// when [latest] is null.
  final bool latestFromCache;

  /// Why [latest] is null; [MetricsLatestUnavailability.none] whenever the
  /// latest record was read (including an account without records).
  final MetricsLatestUnavailability latestUnavailability;

  const MetricsHistoryLoaded({
    required this.weightHistory,
    this.latest,
    this.historyFromCache = false,
    this.latestFromCache = false,
    this.latestUnavailability = MetricsLatestUnavailability.none,
  });
}

class MetricsHistoryFailure extends MetricsState {
  /// True when the request failed for lack of connection.
  final bool offline;

  const MetricsHistoryFailure({this.offline = false});
}
