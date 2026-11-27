// E1 O1: `/calendar/month` per-day session counts are optional. Anything that
// is not a whole number >= 0 reads as absent, so «Tu semana» falls back to
// one session per day with a mark instead of trusting a malformed value.
import 'package:exom_app/features/calendar/data/models/calendar_day_model.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarDayModel _day(Map<String, Object?> fields) => CalendarDayModel.fromJson({
  'date': '2026-11-18',
  'has_training': true,
  'has_diet': false,
  'is_rest_day': false,
  'training_completed': false,
  'diet_completed': false,
  ...fields,
});

void main() {
  test('reads the counts and the mode', () {
    final day = _day({
      'trainings_assigned': 3,
      'trainings_done': 1,
      'training_completion_mode': 'ALL',
    });
    expect(day.trainingsAssigned, 3);
    expect(day.trainingsDone, 1);
    expect(day.trainingCompletionMode, 'ALL');
    expect(HomeDaySessions.ofCalendarDay(day), const HomeDaySessions(3, 1));
  });

  test('a whole double reads as its integer', () {
    final day = _day({'trainings_assigned': 2.0, 'trainings_done': 1.0});
    expect(day.trainingsAssigned, 2);
    expect(day.trainingsDone, 1);
  });

  for (final (label, value) in [
    ('null', null),
    ('a string', '2'),
    ('a negative number', -1),
    ('a fraction', 1.5),
    ('a boolean', true),
  ]) {
    test('$label reads as absent', () {
      final day = _day({
        'trainings_assigned': value,
        'trainings_done': value,
        'training_completion_mode': 'ALL',
      });
      expect(day.trainingsAssigned, isNull);
      expect(day.trainingsDone, isNull);
      // Falls back to one session for the day with a mark.
      expect(HomeDaySessions.ofCalendarDay(day), const HomeDaySessions(1, 0));
    });
  }

  test('missing fields (older API or saved calendar) read as absent', () {
    final day = _day(const {});
    expect(day.trainingsAssigned, isNull);
    expect(day.trainingsDone, isNull);
    expect(day.trainingCompletionMode, isNull);
    expect(HomeDaySessions.ofCalendarDay(day), const HomeDaySessions(1, 0));
  });

  test('a mode that is not a string reads as absent', () {
    final day = _day({'training_completion_mode': 1});
    expect(day.trainingCompletionMode, isNull);
  });

  for (final mode in ['SOME', 'any']) {
    test('an unknown mode «$mode» counts every training, as ALL', () {
      final day = _day({
        'trainings_assigned': 2,
        'trainings_done': 1,
        'training_completion_mode': mode,
      });
      expect(day.trainingCompletionMode, mode);
      expect(HomeDaySessions.ofCalendarDay(day), const HomeDaySessions(2, 1));
    });
  }

  test('done counts above the assigned ones are capped', () {
    final day = _day({'trainings_assigned': 2, 'trainings_done': 5});
    expect(HomeDaySessions.ofCalendarDay(day), const HomeDaySessions(2, 2));
  });
}
