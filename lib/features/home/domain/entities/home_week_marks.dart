import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

/// What the week strip of Inicio shows under a day number (L4b-D4).
enum HomeDayMark {
  /// No session, rest day or no data: nothing is drawn.
  none,

  /// A session is assigned and not done yet.
  pending,

  /// Every session of the day is done.
  done;

  /// Mark of a `/calendar/month` day.
  static HomeDayMark ofCalendarDay(CalendarDayEntity day) {
    if (!day.hasTraining || day.isRestDay) return none;
    return day.trainingCompleted ? done : pending;
  }

  /// Mark of a loaded Inicio summary: its local state (progress with the
  /// pending offline actions overlaid) is newer than the calendar.
  static HomeDayMark ofSummary(HomeSummaryEntity summary) {
    final hasTraining =
        summary.trainings.isNotEmpty || summary.trainingId != null;
    if (!hasTraining) return none;
    return summary.trainingCompleted ? done : pending;
  }
}

/// What `/calendar/month` says a day holds (L5-D27, exception EX-Q6): for a
/// day with neither training nor diet in the Inicio summary, Inicio tells a
/// rest day from a day without assignment with it.
enum HomeDayPlan {
  /// No calendar answer for the day (not loaded yet, failed, no cache).
  unknown,

  /// `is_rest_day`: the plan has a rest day here.
  rest,

  /// No training, no diet and no rest day: nothing assigned yet.
  unassigned,

  /// Anything else: an assignment that is not a rest day (Q11: its trainings
  /// may be inactive, so the summary can still be empty).
  assigned;

  /// Plan of a `/calendar/month` day.
  static HomeDayPlan ofCalendarDay(CalendarDayEntity day) {
    if (day.isRestDay) return rest;
    if (!day.hasTraining && !day.hasDiet) return unassigned;
    return assigned;
  }
}

/// Sessions (trainings) of one day for «Tu semana» (E1 O1): how many the
/// day holds and how many of them are done.
class HomeDaySessions {
  const HomeDaySessions(this.total, this.done);

  final int total;
  final int done;

  static const none = HomeDaySessions(0, 0);

  /// One session per day with a mark: the count before the API sent the
  /// per-day counts (older API or older saved calendar).
  static HomeDaySessions ofMark(HomeDayMark mark) => switch (mark) {
    HomeDayMark.none => none,
    HomeDayMark.pending => const HomeDaySessions(1, 0),
    HomeDayMark.done => const HomeDaySessions(1, 1),
  };

  /// Sessions of a `/calendar/month` day from `trainings_assigned`,
  /// `trainings_done` and `training_completion_mode`. A rest day or a day
  /// without training has none, as its mark. The day's done flag is the
  /// canonical completion: a done day has all its sessions done.
  static HomeDaySessions ofCalendarDay(CalendarDayEntity day) {
    final mark = HomeDayMark.ofCalendarDay(day);
    final assigned = day.trainingsAssigned;
    if (mark == HomeDayMark.none || assigned == null || assigned < 1) {
      return ofMark(mark);
    }
    final sessions = HomeDaySessions(
      assigned,
      mark == HomeDayMark.done
          ? assigned
          : (day.trainingsDone ?? 0).clamp(0, assigned),
    );
    return day.trainingCompletionMode == 'ANY' ? sessions.asAnyOf() : sessions;
  }

  /// Sessions of a loaded Inicio summary: its trainings and which are done
  /// (local state, newer than the calendar).
  static HomeDaySessions ofSummary(HomeSummaryEntity summary) {
    final mark = HomeDayMark.ofSummary(summary);
    if (mark == HomeDayMark.none || summary.trainings.isEmpty) {
      return ofMark(mark);
    }
    final total = summary.trainings.length;
    return HomeDaySessions(
      total,
      summary.trainingCompleted
          ? total
          : summary.trainings.where((t) => t.completed).length,
    );
  }

  /// A day that completes with any one of its trainings
  /// (`training_completion_mode` `ANY`) prescribes one session.
  HomeDaySessions asAnyOf() =>
      total == 0 ? this : HomeDaySessions(1, done > 0 ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is HomeDaySessions && other.total == total && other.done == done;

  @override
  int get hashCode => Object.hash(total, done);
}

/// Marks of the seven days (Monday first) of one week.
class HomeWeekMarks {
  HomeWeekMarks({
    required DateTime weekStart,
    required List<HomeDayMark> days,
    List<HomeDayPlan>? plans,
    List<HomeDaySessions>? sessions,
  }) : weekStart = weekStartOf(weekStart),
       days = List.unmodifiable(days),
       plans = List.unmodifiable(plans ?? List.filled(7, HomeDayPlan.unknown)),
       sessions = List.unmodifiable(
         sessions ?? days.map(HomeDaySessions.ofMark),
       ) {
    assert(days.length == 7, 'A week has seven days');
    assert(this.plans.length == 7, 'A week has seven days');
    assert(this.sessions.length == 7, 'A week has seven days');
  }

  /// Local midnight of the Monday of the week.
  final DateTime weekStart;

  /// Monday first.
  final List<HomeDayMark> days;

  /// Calendar plan of each day, Monday first (L5-D27); [HomeDayPlan.unknown]
  /// when the calendar did not say.
  final List<HomeDayPlan> plans;

  /// Sessions of each day, Monday first (E1 O1). Without them, one per day
  /// with a mark.
  final List<HomeDaySessions> sessions;

  /// Sessions of the week: the «M» of «N de M sesiones hechas» (E1 O1:
  /// sessions, not days).
  int get sessionCount => sessions.fold(0, (sum, day) => sum + day.total);

  /// Done sessions of the week: the «N».
  int get doneCount => sessions.fold(0, (sum, day) => sum + day.done);

  /// Local midnight of the Monday of [day]'s week. Calendar arithmetic, not a
  /// `Duration` subtracted from a local `DateTime`: around a clock change that
  /// can shift the result by an hour.
  static DateTime weekStartOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  /// `yyyy-mm-dd` of the calendar date of [day], whatever its time zone flag.
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// The seven dates of the week of [weekStart], Monday first.
  static List<DateTime> datesOf(DateTime weekStart) => List.generate(
    7,
    (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
  );

  /// Mark of [day], or `null` when it is outside this week.
  HomeDayMark? markFor(DateTime day) {
    final key = dayKey(day);
    final dates = datesOf(weekStart);
    for (var i = 0; i < dates.length; i++) {
      if (dayKey(dates[i]) == key) return days[i];
    }
    return null;
  }

  /// Calendar plan of [day], or [HomeDayPlan.unknown] when it is outside
  /// this week.
  HomeDayPlan planFor(DateTime day) {
    final key = dayKey(day);
    final dates = datesOf(weekStart);
    for (var i = 0; i < dates.length; i++) {
      if (dayKey(dates[i]) == key) return plans[i];
    }
    return HomeDayPlan.unknown;
  }

  bool sameAs(HomeWeekMarks? other) {
    if (other == null || dayKey(other.weekStart) != dayKey(weekStart)) {
      return false;
    }
    for (var i = 0; i < days.length; i++) {
      if (days[i] != other.days[i]) return false;
      if (plans[i] != other.plans[i]) return false;
      if (sessions[i] != other.sessions[i]) return false;
    }
    return true;
  }
}
