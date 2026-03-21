import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';

part 'metrics_event.dart';
part 'metrics_state.dart';

class MetricsBloc extends Bloc<MetricsEvent, MetricsState> {
  final SaveMetricUseCase _saveMetricUseCase;

  MetricsBloc({required SaveMetricUseCase saveMetricUseCase})
      : _saveMetricUseCase = saveMetricUseCase,
        super(const MetricsInitial()) {
    on<MetricsSaveRequested>(_onSaveRequested);
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
