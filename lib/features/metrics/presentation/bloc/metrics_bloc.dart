import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';

part 'metrics_event.dart';
part 'metrics_state.dart';

class MetricsBloc extends Bloc<MetricsEvent, MetricsState> {
  final SaveMetricUseCase _saveMetricUseCase;
  final MetricsRepository _metricsRepository;
  final UpdateProfileUseCase? _updateProfileUseCase;

  MetricsBloc({
    required SaveMetricUseCase saveMetricUseCase,
    required MetricsRepository metricsRepository,
    UpdateProfileUseCase? updateProfileUseCase,
  }) : _saveMetricUseCase = saveMetricUseCase,
       _metricsRepository = metricsRepository,
       _updateProfileUseCase = updateProfileUseCase,
       super(const MetricsInitial()) {
    on<MetricsLoadRequested>(_onLoadRequested);
    on<MetricsSaveRequested>(_onSaveRequested);
    on<MetricsHistoryRequested>(_onHistoryRequested);
  }

  /// Bumped by every history load: only the newest one may emit, so an older
  /// overlapping response can never replace newer data (same scheme as
  /// HomeBloc's request epoch).
  int _historyEpoch = 0;

  Future<void> _onHistoryRequested(
    MetricsHistoryRequested event,
    Emitter<MetricsState> emit,
  ) async {
    final epoch = ++_historyEpoch;
    emit(const MetricsHistoryLoading());
    try {
      final (history, latest) = await (
        _metricsRepository.getWeightHistory(),
        _metricsRepository.getLatestMetric(),
      ).wait;
      if (epoch != _historyEpoch) return;
      emit(MetricsHistoryLoaded(weightHistory: history, latest: latest));
    } catch (error) {
      if (epoch != _historyEpoch) return;
      // Only the latest record failed and the history has weights: show them
      // (latest: null). The history alone never claims that the failed half
      // is empty; an empty history or a failed history stays a failure.
      final history = _historyWithoutLatest(error);
      if (history != null) {
        emit(MetricsHistoryLoaded(weightHistory: history));
        return;
      }
      // A session change (LocalSessionChanged) is a failure too: the data
      // may belong to the previous owner and is never shown.
      emit(MetricsHistoryFailure(offline: _isOffline(error)));
    }
  }

  static List<BodyMetricEntity>? _historyWithoutLatest(Object error) {
    if (error is! ParallelWaitError<Object?, Object?>) return null;
    if (error.errors case (
      null,
      final AsyncError latestError,
    ) when !_isSessionChange(latestError.error)) {
      if (error.values case (
        final List<BodyMetricEntity> history,
        _,
      ) when history.any((metric) => metric.weightKg != null)) {
        return history;
      }
    }
    return null;
  }

  /// LocalSessionChanged, or a request the auth interceptor cancelled because
  /// the session changed while it was in flight.
  static bool _isSessionChange(Object error) =>
      error is LocalSessionChanged ||
      (error is DioException && error.type == DioExceptionType.cancel);

  static bool _isOffline(Object error) {
    if (error is ParallelWaitError<Object?, Object?>) {
      if (error.errors case (final AsyncError? a, final AsyncError? b)) {
        return [a, b].any((e) => e != null && isOfflineError(e.error));
      }
    }
    return isOfflineError(error);
  }

  Future<void> _onLoadRequested(
    MetricsLoadRequested event,
    Emitter<MetricsState> emit,
  ) async {
    emit(const MetricsLoading());
    try {
      final metric = await _metricsRepository.getLatestMetric(date: event.date);
      emit(MetricsLoaded(metric));
    } catch (_) {
      emit(const MetricsLoaded(null));
    }
  }

  Future<void> _onSaveRequested(
    MetricsSaveRequested event,
    Emitter<MetricsState> emit,
  ) async {
    emit(const MetricsSaving());
    try {
      await _saveMetricUseCase(event.data);
      if (event.profileData != null && event.profileData!.isNotEmpty) {
        final updateProfileUseCase =
            _updateProfileUseCase ?? sl<UpdateProfileUseCase>();
        await updateProfileUseCase(event.profileData!);
      }
      emit(const MetricsSaved());
    } catch (e) {
      emit(MetricsError(e.toString()));
    }
  }
}
