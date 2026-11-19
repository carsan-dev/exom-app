import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeSummaryUseCase _getHomeSummaryUseCase;

  /// L4b-D4: `/calendar/month` through the Calendar use case and its existing
  /// cache. Without it (older wiring, tests) the week strip has no marks.
  final GetMonthCalendarUseCase? _getMonthCalendarUseCase;

  /// Date-independent fields from the last full load. Owned by this bloc
  /// instance, which lives and dies with one signed-in shell, so it never
  /// crosses accounts.
  HomeSummaryEntity? _sharedSource;

  /// Shared by both load events; only the newest request may touch the shared
  /// cache or emit.
  int _requestEpoch = 0;

  /// Week whose calendar marks are loaded or loading, the request in flight
  /// (shared by every day of that week) and its result. Like
  /// [_sharedSource], owned by this per-session bloc.
  DateTime? _calendarWeek;
  Future<Map<String, HomeDayMark>?>? _calendarRequest;
  Map<String, HomeDayMark>? _calendarDays;

  /// Marks from the summaries loaded since the last full refresh, by day.
  final Map<String, HomeDayMark> _localDays = {};

  HomeBloc({
    required GetHomeSummaryUseCase getHomeSummaryUseCase,
    GetMonthCalendarUseCase? getMonthCalendarUseCase,
  }) : _getHomeSummaryUseCase = getHomeSummaryUseCase,
       _getMonthCalendarUseCase = getMonthCalendarUseCase,
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
    await _loadForDate(
      event.date ?? today,
      emit,
      reuseShared: false,
      reportFailureOverContent: true,
    );
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
    bool reportFailureOverContent = false,
  }) async {
    final epoch = ++_requestEpoch;
    // A full refresh invalidates the cache so later date requests fetch it
    // again instead of reusing data older than the refresh.
    if (!reuseShared) {
      _sharedSource = null;
      // The week marks reload too; the previous ones stay on screen until
      // the new answer replaces them.
      _calendarRequest = null;
      _localDays.clear();
    }
    final shared = reuseShared ? _sharedSource : null;
    final previousState = state;
    final hasContent =
        previousState is HomeLoaded || previousState is HomeRestDay;
    if (!hasContent) {
      emit(const HomeLoading());
    }
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final weekStart = HomeWeekMarks.weekStartOf(normalizedDate);
    // Started with the summary, awaited only after it is on screen.
    final calendar = _calendarFor(weekStart);

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
      _localDays[HomeWeekMarks.dayKey(normalizedDate)] = HomeDayMark.ofSummary(
        summary,
      );
      final marks = _marksFor(weekStart);
      if (summary.isRestDay) {
        emit(
          HomeRestDay(summary, selectedDate: normalizedDate, weekMarks: marks),
        );
      } else {
        emit(
          HomeLoaded(summary, selectedDate: normalizedDate, weekMarks: marks),
        );
      }
    } catch (e) {
      if (epoch != _requestEpoch) return;
      if (!hasContent) {
        emit(HomeError(e.toString()));
      } else if (reportFailureOverContent) {
        // Same content again, flagged: lets a pull-to-refresh stop waiting
        // and report the failure without replacing what is on screen.
        if (previousState is HomeLoaded) {
          emit(
            HomeLoaded(
              previousState.summary,
              selectedDate: previousState.selectedDate,
              refreshError: e.toString(),
              weekMarks: previousState.weekMarks,
            ),
          );
        } else if (previousState is HomeRestDay) {
          emit(
            HomeRestDay(
              previousState.summary,
              selectedDate: previousState.selectedDate,
              refreshError: e.toString(),
              weekMarks: previousState.weekMarks,
            ),
          );
        }
      }
    }

    if (calendar == null) return;
    await calendar;
    if (epoch != _requestEpoch) return;
    _emitMarks(emit);
  }

  /// Starts, or reuses, the calendar request of [weekStart]: one per visible
  /// week, shared by its days (L4b-D4). `null` without the use case.
  Future<Map<String, HomeDayMark>?>? _calendarFor(DateTime weekStart) {
    final useCase = _getMonthCalendarUseCase;
    if (useCase == null) return null;
    final sameWeek =
        _calendarWeek != null &&
        HomeWeekMarks.dayKey(_calendarWeek!) == HomeWeekMarks.dayKey(weekStart);
    final current = _calendarRequest;
    if (sameWeek && current != null) return current;
    if (!sameWeek) _calendarDays = null;
    _calendarWeek = weekStart;
    late final Future<Map<String, HomeDayMark>?> request;
    request = _fetchWeek(useCase, weekStart).then((days) {
      if (identical(_calendarRequest, request)) _calendarDays = days;
      return days;
    });
    _calendarRequest = request;
    return request;
  }

  /// Days of the week with their calendar mark, from the month(s) the week
  /// covers. `null` when a request fails (offline without cache included) or
  /// the week has no data: the strip then stays as before L4b. Never throws.
  Future<Map<String, HomeDayMark>?> _fetchWeek(
    GetMonthCalendarUseCase useCase,
    DateTime weekStart,
  ) async {
    try {
      final dates = HomeWeekMarks.datesOf(weekStart);
      final weekKeys = dates.map(HomeWeekMarks.dayKey).toSet();
      final months = {
        for (final day in [dates.first, dates.last]) (day.year, day.month),
      };
      final results = await Future.wait(
        months.map((month) => useCase(month.$1, month.$2)),
      );
      final days = <String, HomeDayMark>{};
      for (final day in results.expand((list) => list)) {
        final key = HomeWeekMarks.dayKey(day.date);
        if (weekKeys.contains(key)) {
          days[key] = HomeDayMark.ofCalendarDay(day);
        }
      }
      return days.isEmpty ? null : days;
    } catch (_) {
      return null;
    }
  }

  /// Marks of [weekStart]: the loaded summaries over the calendar. `null`
  /// while the calendar of that week is unknown or unavailable.
  HomeWeekMarks? _marksFor(DateTime weekStart) {
    final calendarWeek = _calendarWeek;
    final calendarDays = _calendarDays;
    if (calendarWeek == null ||
        calendarDays == null ||
        HomeWeekMarks.dayKey(calendarWeek) != HomeWeekMarks.dayKey(weekStart)) {
      return null;
    }
    return HomeWeekMarks(
      weekStart: weekStart,
      days: [
        for (final day in HomeWeekMarks.datesOf(weekStart))
          _localDays[HomeWeekMarks.dayKey(day)] ??
              calendarDays[HomeWeekMarks.dayKey(day)] ??
              HomeDayMark.none,
      ],
    );
  }

  /// Re-emits the content on screen with the marks of its week, if they
  /// changed.
  void _emitMarks(Emitter<HomeState> emit) {
    final current = state;
    if (current is HomeLoaded) {
      final marks = _marksFor(HomeWeekMarks.weekStartOf(current.selectedDate));
      if (_unchanged(marks, current.weekMarks)) return;
      emit(
        HomeLoaded(
          current.summary,
          selectedDate: current.selectedDate,
          weekMarks: marks,
        ),
      );
    } else if (current is HomeRestDay) {
      final marks = _marksFor(HomeWeekMarks.weekStartOf(current.selectedDate));
      if (_unchanged(marks, current.weekMarks)) return;
      emit(
        HomeRestDay(
          current.summary,
          selectedDate: current.selectedDate,
          weekMarks: marks,
        ),
      );
    }
  }

  static bool _unchanged(HomeWeekMarks? next, HomeWeekMarks? current) =>
      next == null ? current == null : next.sameAs(current);
}
