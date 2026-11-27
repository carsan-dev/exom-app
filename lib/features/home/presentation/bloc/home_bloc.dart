import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Mark, plan and sessions of one `/calendar/month` day; [anyOf] when the
/// day completes with any one of its trainings (E1 O1).
typedef _CalendarDay = ({
  HomeDayMark mark,
  HomeDayPlan plan,
  HomeDaySessions sessions,
  bool anyOf,
});

/// Mark and sessions of a loaded Inicio summary.
typedef _LocalDay = ({HomeDayMark mark, HomeDaySessions sessions});

/// E6a: a completion the server confirmed (training and `yyyy-mm-dd`
/// assignment date) patched over the content until the next full reload.
typedef _Confirmed = ({String trainingId, String date});

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
  /// [_sharedSource], owned by this per-session bloc. Each day keeps its
  /// mark and, since L5-E1 (L5-D27), its plan (rest day or no assignment).
  DateTime? _calendarWeek;
  Future<Map<String, _CalendarDay>?>? _calendarRequest;
  Map<String, _CalendarDay>? _calendarDays;

  /// Marks and sessions from the summaries loaded since the last full
  /// refresh, by day.
  final Map<String, _LocalDay> _localDays = {};

  /// Session (account and sign-in generation) in force now, and the one this
  /// bloc was created for. Without the clock (older wiring, tests) the bloc
  /// cannot tell who confirmed a completion, so it never patches one.
  final String? Function()? _sessionStamp;
  final String? _ownerSession;

  /// E6a: content patched by [applyConfirmedCompletion], served by [state]
  /// until the bloc emits again (first of all, this same patch).
  HomeState? _patched;

  /// The patched completion, for the reload that follows it.
  _Confirmed? _confirmed;

  /// INICIO-RED (A1): summary requests not answered yet. While one is in
  /// flight a reconnection does not start another reload.
  int _summariesInFlight = 0;

  /// INICIO-RED (A1): whether the network is up, as last reported (`null`
  /// until the first report), the reconnection waiting out its debounce and
  /// the subscription to the network changes.
  final Duration _reconnectDebounce;
  bool? _online;
  Timer? _reconnectTimer;

  /// INICIO-RED r2: the debounce ended while a request was in flight; once
  /// the last one settles, Inicio is checked again (one reload at most).
  bool _pendingReconnect = false;
  StreamSubscription<bool>? _connectivitySubscription;

  /// [connectivityChanges] reports whether the device has network (`true`)
  /// or not. Without it (older wiring, tests) Inicio never reloads by itself
  /// when the network comes back.
  HomeBloc({
    required GetHomeSummaryUseCase getHomeSummaryUseCase,
    GetMonthCalendarUseCase? getMonthCalendarUseCase,
    String? Function()? sessionStamp,
    Stream<bool>? connectivityChanges,
    Duration reconnectDebounce = const Duration(seconds: 2),
  }) : _getHomeSummaryUseCase = getHomeSummaryUseCase,
       _getMonthCalendarUseCase = getMonthCalendarUseCase,
       _sessionStamp = sessionStamp,
       _ownerSession = sessionStamp?.call(),
       _reconnectDebounce = reconnectDebounce,
       super(const HomeInitial()) {
    on<HomeLoadRequested>(_onLoadRequested);
    on<HomeDateSelected>(_onDateSelected);
    on<_HomeCompletionPatched>(_onCompletionPatched);
    _connectivitySubscription = connectivityChanges?.listen(
      _onConnectivityChanged,
    );
  }

  /// INICIO-RED (A1): the network coming back (a report of "online" that
  /// does not follow another one) waits [_reconnectDebounce]; going offline
  /// in the meantime cancels it, so a flicker reloads at most once.
  void _onConnectivityChanged(bool online) {
    final wasOnline = _online;
    _online = online;
    if (!online) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _pendingReconnect = false;
      return;
    }
    if (wasOnline == true) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDebounce, _reloadAfterReconnect);
  }

  /// Reloads as «Reintentar» does, only when Inicio shows stale data or an
  /// error. With a request in flight it waits for it to settle instead.
  void _reloadAfterReconnect() {
    _reconnectTimer = null;
    if (isClosed) return;
    if (_summariesInFlight > 0) {
      _pendingReconnect = true;
      return;
    }
    _reloadIfUnavailable();
  }

  /// INICIO-RED r2: runs after the last request in flight settled and its
  /// state was emitted. Still online, it reloads once if Inicio is stale or
  /// an error; the reload it starts never sets the mark again.
  void _resumePendingReconnect() {
    if (isClosed || !_pendingReconnect || _summariesInFlight > 0) return;
    _pendingReconnect = false;
    if (_online != true) return;
    _reloadIfUnavailable();
  }

  /// The «Reintentar» of what Inicio shows: the error, or the stale content
  /// of its day. Nothing when Inicio is fresh.
  void _reloadIfUnavailable() {
    switch (state) {
      case HomeError():
        add(const HomeLoadRequested());
      case HomeLoaded(refreshError: _?, :final selectedDate) ||
          HomeRestDay(refreshError: _?, :final selectedDate):
        add(HomeLoadRequested(date: selectedDate));
      default:
        break;
    }
  }

  /// Runs [request] counted in [_summariesInFlight].
  Future<HomeSummaryEntity> _countedInFlight(
    Future<HomeSummaryEntity> Function() request,
  ) async {
    _summariesInFlight++;
    try {
      return await request();
    } finally {
      _summariesInFlight--;
      // The handler emits the resulting state after this await returns (in
      // microtasks); a zero timer runs once all of them are done.
      if (_summariesInFlight == 0 && _pendingReconnect) {
        Timer.run(_resumePendingReconnect);
      }
    }
  }

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pendingReconnect = false;
    await _connectivitySubscription?.cancel();
    return super.close();
  }

  /// The patched content while its emission is on its way, so a widget
  /// built right now (Inicio's first frame back from «Sesión hecha») already
  /// reads it. Bloc emissions are asynchronous; this is not.
  @override
  HomeState get state => _patched ?? super.state;

  @override
  void onChange(Change<HomeState> change) {
    super.onChange(change);
    _patched = null;
  }

  /// E6a, owner decision 2026-11-26: back from «Sesión hecha», marks the
  /// training [trainingId] of [date] (`yyyy-mm-dd`) done on the content in
  /// memory, and its day in «Tu semana», at once, so Inicio never paints it
  /// pending. Returns whether it patched. The caller reloads right after;
  /// that reload replaces the patch, and only if it fails or answers from
  /// the saved copy does the patch stay over it.
  ///
  /// Nothing is written (Hive, cache) or requested. Does nothing unless
  /// [sessionStamp] (the session that confirmed) is the session in force and
  /// the one of this bloc, and the content on screen is [date] holding that
  /// training. Only completion flags change: progress figures, minutes left
  /// and the streak are not deducible and wait for the reload.
  bool applyConfirmedCompletion({
    required String trainingId,
    required String date,
    required String? sessionStamp,
  }) {
    if (isClosed) return false;
    final current = _sessionStamp?.call();
    if (sessionStamp == null ||
        current == null ||
        current != sessionStamp ||
        current != _ownerSession) {
      return false;
    }
    final content = state;
    if (content is! HomeLoaded ||
        HomeWeekMarks.dayKey(content.selectedDate) != date) {
      return false;
    }
    final summary = content.summary.withTrainingCompleted(trainingId);
    if (summary == null) return false;
    // Loads still in flight started before the completion.
    _requestEpoch++;
    _confirmed = (trainingId: trainingId, date: date);
    _localDays[date] = _localDayOf(summary);
    _patched = HomeLoaded(
      summary,
      selectedDate: content.selectedDate,
      weekMarks:
          _marksFor(HomeWeekMarks.weekStartOf(content.selectedDate)) ??
          content.weekMarks,
    );
    add(const _HomeCompletionPatched());
    return true;
  }

  /// Emits the patch for the listeners, unless the bloc emitted since.
  void _onCompletionPatched(
    _HomeCompletionPatched event,
    Emitter<HomeState> emit,
  ) {
    final patched = _patched;
    if (patched == null) return;
    // Cleared first: the emitter skips a state equal to [state].
    _patched = null;
    emit(patched);
  }

  static _LocalDay _localDayOf(HomeSummaryEntity summary) => (
    mark: HomeDayMark.ofSummary(summary),
    sessions: HomeDaySessions.ofSummary(summary),
  );

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
    // E6a: a full reload replaces the patched completion; it only keeps it
    // when it cannot answer (failure or saved copy).
    final confirmed = reuseShared ? null : _confirmed;
    if (!reuseShared) _confirmed = null;
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
      var summary = await _countedInFlight(
        () => _getHomeSummaryUseCase(
          date: date,
          includeSharedData: shared == null,
        ),
      );
      if (epoch != _requestEpoch) return;
      if (shared != null) {
        summary = summary.withSharedFieldsFrom(shared);
      } else {
        _sharedSource = summary;
      }
      // The saved copy may predate the confirmed completion.
      if (confirmed != null &&
          summary.staleReason != null &&
          HomeWeekMarks.dayKey(normalizedDate) == confirmed.date) {
        summary =
            summary.withTrainingCompleted(confirmed.trainingId) ?? summary;
      }
      _localDays[HomeWeekMarks.dayKey(normalizedDate)] = _localDayOf(summary);
      final marks = _marksFor(weekStart);
      // E1 D1: content served from the saved copy because a request failed
      // carries that failure, so Inicio reports it inline over the content.
      final staleReason = summary.staleReason;
      if (summary.isRestDay) {
        emit(
          HomeRestDay(
            summary,
            selectedDate: normalizedDate,
            refreshError: staleReason,
            weekMarks: marks,
          ),
        );
      } else {
        emit(
          HomeLoaded(
            summary,
            selectedDate: normalizedDate,
            refreshError: staleReason,
            weekMarks: marks,
          ),
        );
      }
    } catch (e) {
      if (epoch != _requestEpoch) return;
      // The patched day stays over the (older) calendar that follows.
      if (confirmed != null &&
          previousState is HomeLoaded &&
          HomeWeekMarks.dayKey(previousState.selectedDate) == confirmed.date) {
        _localDays[confirmed.date] = _localDayOf(previousState.summary);
      }
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
  Future<Map<String, _CalendarDay>?>? _calendarFor(DateTime weekStart) {
    final useCase = _getMonthCalendarUseCase;
    if (useCase == null) return null;
    final sameWeek =
        _calendarWeek != null &&
        HomeWeekMarks.dayKey(_calendarWeek!) == HomeWeekMarks.dayKey(weekStart);
    final current = _calendarRequest;
    if (sameWeek && current != null) return current;
    if (!sameWeek) _calendarDays = null;
    _calendarWeek = weekStart;
    late final Future<Map<String, _CalendarDay>?> request;
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
  Future<Map<String, _CalendarDay>?> _fetchWeek(
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
      final days = <String, _CalendarDay>{};
      for (final day in results.expand((list) => list)) {
        final key = HomeWeekMarks.dayKey(day.date);
        if (weekKeys.contains(key)) {
          days[key] = (
            mark: HomeDayMark.ofCalendarDay(day),
            plan: HomeDayPlan.ofCalendarDay(day),
            sessions: HomeDaySessions.ofCalendarDay(day),
            anyOf: day.trainingCompletionMode == 'ANY',
          );
        }
      }
      return days.isEmpty ? null : days;
    } catch (_) {
      return null;
    }
  }

  /// Marks of [weekStart]: the loaded summaries over the calendar. `null`
  /// while the calendar of that week is unknown or unavailable. The plans
  /// (L5-D27) come from the calendar only: a summary cannot tell a rest day
  /// from a day without assignment.
  HomeWeekMarks? _marksFor(DateTime weekStart) {
    final calendarWeek = _calendarWeek;
    final calendarDays = _calendarDays;
    if (calendarWeek == null ||
        calendarDays == null ||
        HomeWeekMarks.dayKey(calendarWeek) != HomeWeekMarks.dayKey(weekStart)) {
      return null;
    }
    final dates = HomeWeekMarks.datesOf(weekStart);
    HomeDaySessions sessionsOf(String key) {
      final calendar = calendarDays[key];
      final local = _localDays[key]?.sessions;
      if (local == null) return calendar?.sessions ?? HomeDaySessions.none;
      // The summary does not know the completion mode; the calendar does.
      return calendar?.anyOf == true ? local.asAnyOf() : local;
    }

    HomeDayMark markOf(String key) {
      final local = _localDays[key];
      if (local == null) return calendarDays[key]?.mark ?? HomeDayMark.none;
      // In ANY mode one done session completes the day, as its count says.
      if (local.mark == HomeDayMark.pending &&
          calendarDays[key]?.anyOf == true &&
          local.sessions.done > 0) {
        return HomeDayMark.done;
      }
      return local.mark;
    }

    return HomeWeekMarks(
      weekStart: weekStart,
      days: [for (final day in dates) markOf(HomeWeekMarks.dayKey(day))],
      plans: [
        for (final day in dates)
          calendarDays[HomeWeekMarks.dayKey(day)]?.plan ?? HomeDayPlan.unknown,
      ],
      sessions: [
        for (final day in dates) sessionsOf(HomeWeekMarks.dayKey(day)),
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
