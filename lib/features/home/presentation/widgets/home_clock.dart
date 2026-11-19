import 'package:flutter/widgets.dart';

/// Source of the current wall-clock time for the Home presentation layer.
typedef HomeNow = DateTime Function();

/// Injectable clock for Inicio (decision D10 of the redesign plan).
///
/// [HomePage] places one scope above its content with the clock it receives
/// (`DateTime.now` by default); the widgets that need "today" (relative date
/// label, week strip, lime action only for today) read it through
/// [HomeClock.now]. Tests pass a fixed clock so the screen is deterministic.
/// Without a scope the real clock is used, so widgets pumped on their own keep
/// working. The HomeBloc is not affected: it keeps its own `DateTime.now()`.
class HomeClock extends InheritedWidget {
  const HomeClock({super.key, required this.now, required super.child});

  final HomeNow now;

  /// Current time from the nearest scope, or the real clock.
  static DateTime nowOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HomeClock>();
    return (scope?.now ?? DateTime.now)();
  }

  /// Local midnight of the current day.
  static DateTime todayOf(BuildContext context) {
    final now = nowOf(context);
    return DateTime(now.year, now.month, now.day);
  }

  /// Whether [date] is the current day of the scope clock.
  static bool isToday(BuildContext context, DateTime date) {
    return isSameDay(todayOf(context), date);
  }

  @override
  bool updateShouldNotify(HomeClock oldWidget) => oldWidget.now != now;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
