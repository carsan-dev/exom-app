import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeSummaryUseCase _getHomeSummaryUseCase;

  /// Date-independent fields from the last full load. Owned by this bloc
  /// instance, which lives and dies with one signed-in shell, so it never
  /// crosses accounts.
  HomeSummaryEntity? _sharedSource;

  /// Shared by both load events; only the newest request may touch the shared
  /// cache or emit.
  int _requestEpoch = 0;

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
    // Initial load, retry, pull-to-refresh and post-action refreshes always
    // refetch the shared fields.
    await _loadForDate(event.date ?? today, emit, reuseShared: false);
  }

  Future<void> _onDateSelected(
    HomeDateSelected event,
    Emitter<HomeState> emit,
  ) async {
    await _loadForDate(event.date, emit, reuseShared: true);
  }

  Future<void> _loadForDate(
    DateTime date,
    Emitter<HomeState> emit, {
    required bool reuseShared,
  }) async {
    final epoch = ++_requestEpoch;
    // A full refresh invalidates the cache so later date requests fetch it
    // again instead of reusing data older than the refresh.
    if (!reuseShared) _sharedSource = null;
    final shared = reuseShared ? _sharedSource : null;
    final previousState = state;
    final hasContent =
        previousState is HomeLoaded || previousState is HomeRestDay;
    if (!hasContent) {
      emit(const HomeLoading());
    }

    try {
      var summary = await _getHomeSummaryUseCase(
        date: date,
        includeSharedData: shared == null,
      );
      if (epoch != _requestEpoch) return;
      if (shared != null) {
        summary = summary.withSharedFieldsFrom(shared);
      } else {
        _sharedSource = summary;
      }
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (summary.isRestDay) {
        emit(HomeRestDay(summary, selectedDate: normalizedDate));
      } else {
        emit(HomeLoaded(summary, selectedDate: normalizedDate));
      }
    } catch (e) {
      if (epoch != _requestEpoch) return;
      if (!hasContent) {
        emit(HomeError(e.toString()));
      }
    }
  }
}
