import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeSummaryUseCase _getHomeSummaryUseCase;

  HomeBloc({required GetHomeSummaryUseCase getHomeSummaryUseCase})
      : _getHomeSummaryUseCase = getHomeSummaryUseCase,
        super(const HomeInitial()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    try {
      final summary = await _getHomeSummaryUseCase();
      if (summary.isRestDay) {
        emit(HomeRestDay(summary));
      } else {
        emit(HomeLoaded(summary));
      }
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}
