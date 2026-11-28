// Inicio week strip: the Monday of a week is plain calendar arithmetic, so a
// clock change inside the week (last Sunday of March / October in
// Europe/Madrid) can never shift a day. The process time zone cannot be fixed
// from a test, so the pure function is checked over the DST weeks of several
// years for the properties that must hold in any zone: every day is local
// midnight, consecutive, starts on Monday and contains the given day.
import 'package:exom_app/features/home/presentation/widgets/week_day_selector.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _lastSunday(int year, int month) {
  var day = DateTime(year, month + 1, 0);
  while (day.weekday != DateTime.sunday) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return day;
}

void main() {
  for (final year in [2025, 2026, 2027]) {
    for (final month in [3, 10]) {
      final change = _lastSunday(year, month);
      test('week containing the clock change $year-$month-${change.day}', () {
        // Every day from the Monday before the change to the Sunday after it.
        for (var offset = -7; offset <= 7; offset++) {
          final today = DateTime(change.year, change.month, change.day + offset);
          final start = WeekDaySelector.weekStartOf(today);

          expect(start.weekday, DateTime.monday, reason: '$today');
          expect(start.isUtc, isFalse);
          final days = [
            for (var i = 0; i < 7; i++)
              DateTime(start.year, start.month, start.day + i),
          ];
          for (final day in days) {
            expect(
              [day.hour, day.minute, day.second, day.millisecond],
              [0, 0, 0, 0],
              reason: 'day $day of the week of $today is not local midnight',
            );
          }
          for (var i = 1; i < days.length; i++) {
            final previous = days[i - 1];
            expect(
              days[i],
              DateTime(previous.year, previous.month, previous.day + 1),
            );
          }
          expect(
            days.any(
              (day) =>
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day,
            ),
            isTrue,
            reason: 'the week of $today must contain it',
          );
          expect(
            [start.hour, start.minute],
            [0, 0],
            reason: 'start of the week of $today is not local midnight',
          );
        }
      });
    }
  }

  test('an already-Monday day is its own week start', () {
    expect(
      WeekDaySelector.weekStartOf(DateTime(2026, 11, 16)),
      DateTime(2026, 11, 16),
    );
  });
}
