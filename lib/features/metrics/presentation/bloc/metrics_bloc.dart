import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';

part 'metrics_event.dart';
part 'metrics_state.dart';

class MetricsBloc extends Bloc<MetricsEvent, MetricsState> {
  final SaveMetricUseCase _saveMetricUseCase;
  final MetricsRepository _metricsRepository;

  MetricsBloc({
    required SaveMetricUseCase saveMetricUseCase,
    required MetricsRepository metricsRepository,
  })  : _saveMetricUseCase = saveMetricUseCase,
        _metricsRepository = metricsRepository,
        super(const MetricsInitial()) {
    on<MetricsLoadRequested>(_onLoadRequested);
    on<MetricsSaveRequested>(_onSaveRequested);
  }

  Future<void> _onLoadRequested(
    MetricsLoadRequested event,
    Emitter<MetricsState> emit,
  ) async {
    emit(const MetricsLoading());
    try {
      final metric = await _metricsRepository.getLatestMetric();
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
      emit(const MetricsSaved());
    } catch (e) {
      emit(MetricsError(e.toString()));
    }
  }
}
