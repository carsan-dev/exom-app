// L6-S25-D2 (L5-FLU1): on a 120 Hz S25 the month change spent its raster
// budget on group-opacity layers: the title, the protagonist figure and the
// grid each moved as two partially transparent OpacityLayers (six offscreen
// render passes per frame). The three now move as images of their content
// (`ExomStepTransition.snapshot`): during the whole change the page has no
// partially transparent OpacityLayer, while the month still moves (the
// position checks live in calendar_month_transition_test.dart). Checked at
// the device pixel ratio of real phones (2.625, 3.0; the S25 is about 2.8),
// not only at 1.0, with marks in both the leaving and the incoming month.
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'calendar_redesign_fixture.dart';

/// Partially transparent opacity layers in the scene.
int _partialOpacityLayers(WidgetTester tester) {
  var count = 0;
  void walk(Layer layer) {
    if (layer is OpacityLayer) {
      final alpha = layer.alpha ?? 255;
      if (alpha > 0 && alpha < 255) count++;
    }
    if (layer is ContainerLayer) {
      for (var c = layer.firstChild; c != null; c = c.nextSibling) {
        walk(c);
      }
    }
  }

  walk(tester.binding.renderViews.first.debugLayer!);
  return count;
}

/// Days of the incoming [month] with trainings, diets, rest days and
/// completions, so the grid that moves in has marks to draw.
List<CalendarDayEntity> _markedDays(int month) => [
  for (var d = 1; d <= 30; d++)
    CalendarDayEntity(
      date: DateTime(2026, month, d),
      hasTraining: d % 3 == 0,
      hasDiet: d % 7 != 0,
      isRestDay: d % 7 == 0,
      trainingCompleted: d % 6 == 0,
      dietCompleted: d < 12 && d % 7 != 0,
    ),
];

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  for (final ratio in const [1.0, 2.625, 3.0]) {
    for (final advance in [true, false]) {
      _monthChange(advance: advance, ratio: ratio);
    }
  }
}

void _monthChange({required bool advance, required double ratio}) {
  testWidgets('month change (${advance ? 'next' : 'previous'}) at dpr '
      '$ratio: no offscreen opacity layer while it moves', (tester) async {
    final bloc = await pumpCalendarScene(
      tester,
      state: sceneLoaded(),
      disableAnimations: false,
      devicePixelRatio: ratio,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_partialOpacityLayers(tester), 0, reason: 'at rest');

    await tester.tap(
      find.byKey(
        Key(advance ? 'calendar-month-next' : 'calendar-month-previous'),
      ),
    );
    bloc.seed(const CalendarLoading());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_partialOpacityLayers(tester), 0, reason: 'title moving');

    final month = advance ? 11 : 9;
    bloc.seed(
      sceneLoaded(
        year: 2026,
        month: month,
        selected: DateTime(2026, month, 15),
        days: _markedDays(month),
        challenges: const [],
      ),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      // Both months are on screen while the grid moves.
      if (i < 8) {
        expect(
          find.byKey(ExomMonthGrid.visualKey(DateTime(2026, 10, 15))),
          findsOneWidget,
        );
        expect(
          find.byKey(ExomMonthGrid.visualKey(DateTime(2026, month, 15))),
          findsWidgets,
        );
      }
      expect(_partialOpacityLayers(tester), 0, reason: 'frame $i');
    }
    await tester.pumpAndSettle();
    expect(
      find.byKey(ExomMonthGrid.visualKey(DateTime(2026, 10, 15))),
      findsNothing,
    );
    expect(_partialOpacityLayers(tester), 0, reason: 'at rest');
  });
}
