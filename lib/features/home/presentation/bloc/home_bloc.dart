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
    on<HomeDateSelected>(_onDateSelected);
  }

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    await _loadForDate(today, emit);
  }

  Future<void> _onDateSelected(
    HomeDateSelected event,
    Emitter<HomeState> emit,
  ) async {
    await _loadForDate(event.date, emit);
  }

  Future<void> _loadForDate(DateTime date, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    try {
      final summary = await _getHomeSummaryUseCase(date: date);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (summary.isRestDay) {
        emit(HomeRestDay(summary, selectedDate: normalizedDate));
      } else {
        emit(HomeLoaded(summary, selectedDate: normalizedDate));
      }
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}
