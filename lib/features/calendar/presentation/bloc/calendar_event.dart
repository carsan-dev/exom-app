part of 'calendar_bloc.dart';

abstract class CalendarEvent {
  const CalendarEvent();
}

class CalendarMonthLoadRequested extends CalendarEvent {
  final int year;
  final int month;
  final DateTime? selectedDate;

  const CalendarMonthLoadRequested({
    required this.year,
    required this.month,
    this.selectedDate,
  });
}

class CalendarDaySelected extends CalendarEvent {
  final DateTime date;

  const CalendarDaySelected(this.date);
}
