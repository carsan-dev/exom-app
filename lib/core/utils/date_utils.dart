import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _displayDateFormat = DateFormat('d MMM', 'es');
  static final _fullDateFormat = DateFormat('EEEE, d MMMM yyyy', 'es');
  static final _monthYearFormat = DateFormat('MMMM yyyy', 'es');

  static String toIso(DateTime date) => _dateFormat.format(date);

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String todayIso() => toIso(today());

  static String toDisplay(DateTime date) => _displayDateFormat.format(date);

  static String toFullDisplay(DateTime date) => _fullDateFormat.format(date);

  static String toMonthYear(DateTime date) => _monthYearFormat.format(date);

  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday; // 1=Mon, 7=Sun
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0);

  static bool isToday(DateTime date) {
    final now = today();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String relativeDay(DateTime date) {
    final t = today();
    final diff = DateTime(date.year, date.month, date.day)
        .difference(t)
        .inDays;
    return switch (diff) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => toDisplay(date),
    };
  }
}
