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

/// Marks of the seven days (Monday first) of one week.
class HomeWeekMarks {
  HomeWeekMarks({required DateTime weekStart, required List<HomeDayMark> days})
    : weekStart = weekStartOf(weekStart),
      days = List.unmodifiable(days) {
    assert(days.length == 7, 'A week has seven days');
  }

  /// Local midnight of the Monday of the week.
  final DateTime weekStart;

  /// Monday first.
  final List<HomeDayMark> days;

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

  bool sameAs(HomeWeekMarks? other) {
    if (other == null || dayKey(other.weekStart) != dayKey(weekStart)) {
      return false;
    }
    for (var i = 0; i < days.length; i++) {
      if (days[i] != other.days[i]) return false;
    }
    return true;
  }
}
