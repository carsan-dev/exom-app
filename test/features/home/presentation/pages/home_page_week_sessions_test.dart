// «Tu semana N de M sesiones hechas» (E1 O1) counts sessions, not days.
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_e1_harness.dart';

CalendarDayEntity _day(
  String date, {
  required int assigned,
  required int done,
  bool completed = false,
}) => CalendarDayEntity(
  date: DateTime.parse(date),
  hasTraining: true,
  hasDiet: false,
  isRestDay: false,
  trainingCompleted: completed,
  dietCompleted: false,
  trainingsAssigned: assigned,
  trainingsDone: done,
  trainingCompletionMode: 'ALL',
);

void main() {
  testWidgets('a day with two sessions counts two (session day)', (
    tester,
  ) async {
    await pumpInicioE1(
      tester,
      repository: InicioE1Repository((_) => inicioE1Training),
      calendar: InicioE1Calendar(
        InicioE1Calendar.week({
          '2026-11-16': _day(
            '2026-11-16',
            assigned: 1,
            done: 1,
            completed: true,
          ),
          '2026-11-18': _day('2026-11-18', assigned: 1, done: 0),
          '2026-11-21': _day('2026-11-21', assigned: 2, done: 0),
        }),
      ),
    );
    expect(find.text('1 de 4 sesiones hechas'), findsOneWidget);
  });

  testWidgets('a day with two sessions counts two (day without training)', (
    tester,
  ) async {
    await pumpInicioE1(
      tester,
      repository: InicioE1Repository((_) => inicioE1Empty),
      calendar: InicioE1Calendar(
        InicioE1Calendar.week({
          '2026-11-16': _day(
            '2026-11-16',
            assigned: 2,
            done: 2,
            completed: true,
          ),
          '2026-11-18': InicioE1Calendar.day('2026-11-18', rest: true),
          '2026-11-21': _day('2026-11-21', assigned: 2, done: 1),
        }),
      ),
    );
    // Featured block: «3» over «/4» and «sesiones hechas».
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ExomNumeral && widget.value == '3' && widget.unit == '/4',
      ),
      findsOneWidget,
    );
  });
}
