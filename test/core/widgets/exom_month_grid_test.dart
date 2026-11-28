// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomMonthGrid (ESPEC §3,
// `.x-month`, `.day`): Monday-first month grid, calendar arithmetic without
// Duration (L3b P5b), visual cells >= 44 and tap areas as wide as their
// column (>= 44, no overlap) and >= 48 high (L5-D34).
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'expect_no_lime_ink.dart';

final _month = DateTime(2026, 11);
final _today = DateTime(2026, 11, 20);

ExomDayMark _marks(DateTime day) {
  if (day.month != 11) return ExomDayMark.none;
  return switch (day.day) {
    2 || 4 || 9 => ExomDayMark.done,
    6 => ExomDayMark.missed,
    20 || 23 || 25 => ExomDayMark.pending,
    18 => ExomDayMark.done,
    _ => ExomDayMark.none,
  };
}

Widget _grid({
  DateTime? selected,
  bool doneAsFill = true,
  ValueChanged<DateTime>? onSelect,
  DateTime? month,
}) => ExomMonthGrid(
  month: month ?? _month,
  selected: selected,
  today: _today,
  markOf: _marks,
  onSelect: onSelect ?? (_) {},
  doneAsFill: doneAsFill,
);

BoxDecoration _decorationOf(WidgetTester tester, DateTime day) =>
    tester
            .widget<AnimatedContainer>(find.byKey(ExomMonthGrid.visualKey(day)))
            .decoration!
        as BoxDecoration;

Color? _numberColor(WidgetTester tester, DateTime day) {
  final text = find.descendant(
    of: find.byKey(ExomMonthGrid.visualKey(day)),
    matching: find.text('${day.day}'),
  );
  return tester.widget<Text>(text).style?.color;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

void main() {
  registerTextComponentMatrix(
    'ExomMonthGrid',
    () => _grid(selected: DateTime(2026, 11, 18)),
  );
  registerTextComponentMatrix(
    'ExomMonthGrid without fill',
    () => _grid(selected: DateTime(2026, 11, 3), doneAsFill: false),
  );

  group('daysOf: calendar arithmetic', () {
    final firstWeekdays = <int>{};
    final lengths = <int>{};
    for (var year = 2024; year <= 2027; year++) {
      for (var m = 1; m <= 12; m++) {
        final month = DateTime(year, m);
        test('$year-$m starts on Monday and lists consecutive days', () {
          final days = ExomMonthGrid.daysOf(month);
          final daysInMonth = DateTime(year, m + 1, 0).day;
          firstWeekdays.add(DateTime(year, m, 1).weekday);
          lengths.add(daysInMonth);
          expect(days.length % 7, 0);
          expect(days.length, inInclusiveRange(28, 42));
          expect(days.first.weekday, DateTime.monday);
          expect(days.last.weekday, DateTime.sunday);
          for (var i = 0; i < days.length; i++) {
            expect(days[i].hour, 0, reason: '${days[i]} is not midnight');
            expect(days[i].minute, 0);
            if (i > 0) {
              final prev = days[i - 1];
              final next = DateTime(prev.year, prev.month, prev.day + 1);
              expect(_sameDay(days[i], next), isTrue, reason: '${days[i]}');
            }
          }
          final inMonth = days.where((d) => d.month == m).toList();
          expect(inMonth.length, daysInMonth);
          expect(inMonth.first.day, 1);
          expect(inMonth.last.day, daysInMonth);
        });
      }
    }
    test('the sample covers every first weekday and month length', () {
      expect(firstWeekdays, hasLength(7));
      expect(lengths, {28, 29, 30, 31});
    });
  });

  test('daylight saving changes do not skip or repeat a day', () {
    for (final (month, before, after) in [
      (DateTime(2026, 3), 29, 30),
      (DateTime(2026, 10), 25, 26),
      (DateTime(2025, 3), 30, 31),
      (DateTime(2025, 10), 26, 27),
    ]) {
      final days = ExomMonthGrid.daysOf(month);
      final i = days.indexWhere(
        (d) => d.month == month.month && d.day == before,
      );
      expect(days[i + 1].day, after);
      expect(days[i + 1].hour, 0);
    }
  });

  test('the grid never computes days with Duration', () {
    final source = File(
      'lib/core/widgets/exom_month_grid.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Duration(days')));
    expect(source, isNot(contains('Duration(hours')));
    expect(source, isNot(contains('.add(')));
    expect(source, isNot(contains('.subtract(')));
    expect(source, isNot(contains('.difference(')));
    expect(source, isNot(contains('DateTime.now(')));
  });

  testWidgets('first column is Monday (es and en)', (tester) async {
    await pumpComponent(tester, _grid());
    final first = ExomMonthGrid.daysOf(_month).first;
    expect(first, DateTime(2026, 10, 26));
    expect(first.weekday, DateTime.monday);
    final initials = find.byKey(ExomMonthGrid.weekdayHeaderKey);
    expect(
      find
          .descendant(of: initials, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data),
      ['L', 'M', 'X', 'J', 'V', 'S', 'D'],
    );
    await pumpComponent(tester, _grid(), locale: const Locale('en'));
    expect(
      find
          .descendant(of: initials, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data),
      ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    );
  });

  // Contract change approved by the owner (L5-D34, 2026-11-20), replacing the
  // earlier "measured tap area >= 48 x 48 per cell" test: at 320 dp a column
  // measures 45.7, so 48-wide areas had to overlap their neighbours and a tap
  // near a day's edge could select the next day. Now each day's tap area is
  // exactly its column (>= 44, no overlap) and at least 48 high; the grid is
  // full bleed or has horizontal margins of at most 6 dp.
  for (final width in const [320.0, 360.0]) {
    for (final margin in const [0.0, 6.0]) {
      for (final scale in const [1.0, 1.6]) {
        final name = '$width dp, margin $margin, $scale x';
        testWidgets('tap areas: column wide (>= 44), >= 48 high, no overlap, '
            'visual >= 44 ($name)', (tester) async {
          await pumpComponent(
            tester,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: _grid(),
            ),
            width: width,
            textScale: scale,
          );
          final column = (width - 2 * margin) / 7;
          expect(column, greaterThanOrEqualTo(44));
          final days = ExomMonthGrid.daysOf(_month);
          for (var i = 0; i < days.length; i++) {
            final day = days[i];
            if (day.month != 11) continue;
            final hit = tester.getRect(find.byKey(ExomMonthGrid.cellKey(day)));
            expect(hit.width, moreOrLessEquals(column, epsilon: 0.01));
            expect(hit.height, greaterThanOrEqualTo(48), reason: '$day');
            final visual = tester.getSize(
              find.byKey(ExomMonthGrid.visualKey(day)),
            );
            expect(visual.width, greaterThanOrEqualTo(44), reason: '$day');
            expect(visual.height, greaterThanOrEqualTo(44), reason: '$day');
            final next = i + 1 < days.length ? days[i + 1] : null;
            if (next != null && next.month == 11 && i % 7 != 6) {
              final nextHit = tester.getRect(
                find.byKey(ExomMonthGrid.cellKey(next)),
              );
              expect(
                hit.right,
                lessThanOrEqualTo(nextHit.left + 0.01),
                reason: '$day overlaps $next',
              );
            }
          }
        });

        testWidgets('a tap 1 dp inside the end edge selects that day '
            '($name)', (tester) async {
          final taps = <DateTime>[];
          await pumpComponent(
            tester,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: _grid(onSelect: taps.add),
            ),
            width: width,
            textScale: scale,
          );
          for (var d = 2; d <= 8; d++) {
            final day = DateTime(2026, 11, d);
            final hit = tester.getRect(find.byKey(ExomMonthGrid.cellKey(day)));
            await tester.tapAt(Offset(hit.right - 1, hit.center.dy));
            await tester.pump();
            expect(_sameDay(taps.last, day), isTrue, reason: 'day $d');
          }
        });
      }
    }
  }

  // Under L5-D34 a 320 dp column (45.7) is below Android's 48 dp guideline by
  // design; iOS (44) and labels are checked at 320, all three at 360.
  testWidgets('tap targets pass the iOS and label guidelines at 320 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _grid(), width: 320);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('tap targets pass all the guidelines at 360 dp', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _grid(), width: 360);
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('every tap area selects its own day, edges included', (
    tester,
  ) async {
    final taps = <DateTime>[];
    await pumpComponent(tester, _grid(onSelect: taps.add), width: 320);
    for (final d in [2, 8, 9, 15, 30]) {
      final day = DateTime(2026, 11, d);
      await tester.tap(find.byKey(ExomMonthGrid.visualKey(day)));
      await tester.pump();
      expect(_sameDay(taps.last, day), isTrue, reason: 'day $d');
    }
  });

  testWidgets('days of other months are painted but not tappable', (
    tester,
  ) async {
    final taps = <DateTime>[];
    await pumpComponent(tester, _grid(onSelect: taps.add));
    final outside = DateTime(2026, 10, 27);
    expect(find.byKey(ExomMonthGrid.cellKey(outside)), findsNothing);
    expect(find.byKey(ExomMonthGrid.visualKey(outside)), findsOneWidget);
    await tester.tap(
      find.byKey(ExomMonthGrid.visualKey(outside)),
      warnIfMissed: false,
    );
    expect(taps, isEmpty);
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('states and colours (${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _grid(selected: DateTime(2026, 11, 12)),
        brightness: brightness,
      );
      await tester.pumpAndSettle();
      // Selected: selection fill, never lime.
      final selected = _decorationOf(tester, DateTime(2026, 11, 12));
      expect(selected.color, palette.selectionFill);
      expect(
        _numberColor(tester, DateTime(2026, 11, 12)),
        palette.onSelectionFill,
      );
      // Today: 1.5 outline in the text colour.
      final today = _decorationOf(tester, _today);
      final todayBorder = today.border! as Border;
      expect(todayBorder.top.color, palette.textPrimary);
      expect(todayBorder.top.width, 1.5);
      // Done with doneAsFill: lime fill, ink on lime, outline in light.
      final done = _decorationOf(tester, DateTime(2026, 11, 4));
      expect(done.color, palette.limeFill);
      expect(_numberColor(tester, DateTime(2026, 11, 4)), palette.onLimeFill);
      final outline = palette.limeFillOutline;
      if (outline == null) {
        expect(done.border, isNull);
      } else {
        expect((done.border! as Border).top.color, outline);
        expect((done.border! as Border).top.width, 1.5);
      }
      expect(
        tester
            .widget<Icon>(
              find.byKey(ExomMonthGrid.markKey(DateTime(2026, 11, 4))),
            )
            .color,
        palette.onLimeFill,
      );
      // Out of month: secondary colour.
      expect(
        _numberColor(tester, DateTime(2026, 10, 26)),
        palette.textSecondary,
      );
    });

    testWidgets('doneAsFill false: no fill, check in data '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _grid(doneAsFill: false),
        brightness: brightness,
      );
      final done = _decorationOf(tester, DateTime(2026, 11, 4));
      expect(done.color, isNull);
      final check = tester.widget<Icon>(
        find.byKey(ExomMonthGrid.markKey(DateTime(2026, 11, 4))),
      );
      expect(check.icon, ExomIcons.check);
      expect(check.color, palette.data);
      expect(_numberColor(tester, DateTime(2026, 11, 4)), palette.textPrimary);
      expectNoLimeInk(tester);
    });
  }

  // The painted numbers are excluded from semantics (each day is read through
  // its tap area), so textContrastGuideline cannot see them: the colour pairs
  // the grid paints are checked directly.
  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    test('painted colour pairs reach 4.5:1 (${brightness.name})', () {
      double ratio(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      final pairs = {
        'day number': (palette.textPrimary, palette.background),
        'other month': (palette.textSecondary, palette.background),
        'weekday initial': (palette.textSecondary, palette.background),
        'selected': (palette.onSelectionFill, palette.selectionFill),
        'done fill': (palette.onLimeFill, palette.limeFill),
        'done check': (palette.data, palette.background),
      };
      pairs.forEach((name, pair) {
        expect(
          ratio(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      });
    });
  }

  testWidgets('marks: dot for pending, check for done, ring for missed', (
    tester,
  ) async {
    await pumpComponent(tester, _grid(doneAsFill: false));
    Finder mark(int d) =>
        find.byKey(ExomMonthGrid.markKey(DateTime(2026, 11, d)));
    expect(tester.widget<Icon>(mark(9)).icon, ExomIcons.check);
    final dot =
        tester.widget<DecoratedBox>(mark(23)).decoration as BoxDecoration;
    expect(dot.shape, BoxShape.circle);
    expect(dot.color, isNotNull);
    expect(dot.border, isNull);
    final ring =
        tester.widget<DecoratedBox>(mark(6)).decoration as BoxDecoration;
    expect(ring.shape, BoxShape.circle);
    expect(ring.color, isNull);
    expect((ring.border! as Border).top.width, 1.5);
    expect(mark(1), findsNothing);
  });

  testWidgets('semantics per day: localised date, today, mark, selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _grid(selected: DateTime(2026, 11, 18)));
    String date(int d) =>
        DateFormat.MMMMEEEEd('es').format(DateTime(2026, 11, d));
    expect(
      tester.getSemantics(
        find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 11, 18))),
      ),
      matchesSemantics(
        label: '${date(18)}, sesión hecha',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(ExomMonthGrid.cellKey(_today))),
      matchesSemantics(
        label: '${date(20)}, hoy, sesión pendiente',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 11, 6))),
      ),
      matchesSemantics(
        label: '${date(6)}, sesión no hecha',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('markLabelOf replaces the session words (L5-A4 O4)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final marks = <ExomDayMark>[];
    await pumpComponent(
      tester,
      ExomMonthGrid(
        month: _month,
        selected: null,
        today: _today,
        markOf: _marks,
        onSelect: (_) {},
        markLabelOf: (label, mark) {
          marks.add(mark);
          return '$label, diet ${mark.name}';
        },
      ),
    );
    String date(int d) =>
        DateFormat.MMMMEEEEd('es').format(DateTime(2026, 11, d));
    String label(int d) => tester
        .getSemantics(find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 11, d))))
        .label;
    expect(label(18), '${date(18)}, diet done');
    expect(label(20), '${date(20)}, hoy, diet pending');
    expect(label(6), '${date(6)}, diet missed');
    // A day without a mark keeps its date only; none is never passed.
    expect(label(1), date(1));
    expect(marks, isNot(contains(ExomDayMark.none)));
    handle.dispose();
  });

  testWidgets('today is injected, not read from the clock', (tester) async {
    await pumpComponent(
      tester,
      ExomMonthGrid(
        month: DateTime(2030, 2),
        selected: null,
        today: DateTime(2030, 2, 14),
        markOf: (_) => ExomDayMark.none,
      ),
    );
    final border =
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(
                        ExomMonthGrid.visualKey(DateTime(2030, 2, 14)),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .border;
    expect(border, isNotNull);
  });

  testWidgets('a tap during the selection crossfade acts at once', (
    tester,
  ) async {
    final taps = <DateTime>[];
    DateTime? selected;
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) => _grid(
          selected: selected,
          onSelect: (d) {
            taps.add(d);
            setState(() => selected = d);
          },
        ),
      ),
    );
    await tester.tap(
      find.byKey(ExomMonthGrid.visualKey(DateTime(2026, 11, 10))),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(
      find.byKey(ExomMonthGrid.visualKey(DateTime(2026, 11, 11))),
    );
    expect(taps.map((d) => d.day), [10, 11]);
    await tester.pumpAndSettle();
  });

  for (final reduced in const [false, true]) {
    testWidgets('selection crossfade duration (reduced: $reduced)', (
      tester,
    ) async {
      await pumpComponent(tester, _grid(), disableAnimations: reduced);
      final container = tester.widget<AnimatedContainer>(
        find.byKey(ExomMonthGrid.visualKey(DateTime(2026, 11, 10))),
      );
      expect(
        container.duration,
        ExomMotion.resolve(reduced: reduced).chipCrossfade,
      );
    });
  }

  testWidgets('null onSelect: days are not tappable', (tester) async {
    await pumpComponent(
      tester,
      ExomMonthGrid(
        month: _month,
        selected: null,
        today: _today,
        markOf: _marks,
      ),
    );
    expect(
      find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 11, 3))),
      findsNothing,
    );
  });

  group('flag (L5-A4a: challenge in the corner, sketch `.a-fl`)', () {
    bool flagged(DateTime day) =>
        day.month == 11 && (day.day == 3 || day.day == 18 || day.day == 9);

    Widget flaggedGrid({DateTime? selected}) => ExomMonthGrid(
      month: _month,
      selected: selected,
      today: _today,
      markOf: _marks,
      onSelect: (_) {},
      doneAsFill: true,
      flagOf: flagged,
      flagLabelOf: (label) => '$label, flag',
    );

    testWidgets('no flag without flagOf', (tester) async {
      await pumpComponent(tester, _grid());
      expect(
        find.byKey(ExomMonthGrid.flagKey(DateTime(2026, 11, 3))),
        findsNothing,
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('flag colours: secondary, on selection, on lime '
          '(${brightness.name})', (tester) async {
        await pumpComponent(
          tester,
          flaggedGrid(selected: DateTime(2026, 11, 18)),
          brightness: brightness,
        );
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        Color? colour(int d) => tester
            .widget<Icon>(
              find.byKey(ExomMonthGrid.flagKey(DateTime(2026, 11, d))),
            )
            .color;
        expect(colour(3), palette.textSecondary);
        expect(colour(18), palette.onSelectionFill);
        expect(colour(9), palette.onLimeFill);
        expect(
          find.byKey(ExomMonthGrid.flagKey(DateTime(2026, 11, 4))),
          findsNothing,
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
      });
    }

    testWidgets('the flag stays inside its cell and the label says it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, flaggedGrid(), width: 320, textScale: 1.6);
      expectNoOverflow(tester);
      final day = DateTime(2026, 11, 3);
      final cell = tester.getRect(find.byKey(ExomMonthGrid.visualKey(day)));
      final flag = tester.getRect(find.byKey(ExomMonthGrid.flagKey(day)));
      expect(cell.contains(flag.topLeft), isTrue);
      expect(
        cell.contains(flag.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
      );
      final date = DateFormat.MMMMEEEEd('es').format(day);
      expect(
        tester.getSemantics(find.byKey(ExomMonthGrid.cellKey(day))).label,
        '$date, flag',
      );
      handle.dispose();
    });
  });

  // L5-A4c (sketch a-diario.html#calendario): with slideSelection the bone
  // fill of the chosen day slides between cells in ExomMotion.selectionSlide
  // (200 ms, ease-out); reduced motion keeps the 120 ms crossfade in place.
  // With monthTransition the weeks of a new month enter horizontally while
  // the weekday initials stay.
  group('L5-A4c motion (optional)', () {
    Widget slideGrid(DateTime selected, {bool slide = true}) => ExomMonthGrid(
      month: _month,
      selected: selected,
      today: _today,
      markOf: _marks,
      onSelect: (_) {},
      doneAsFill: true,
      slideSelection: slide,
    );

    final from = DateTime(2026, 11, 10);
    final to = DateTime(2026, 11, 12);
    final otherWeek = DateTime(2026, 11, 26);

    testWidgets('the fill slides from the previous cell in 200 ms', (
      tester,
    ) async {
      await pumpComponent(tester, slideGrid(from));
      await tester.pumpAndSettle();
      final fill = find.byKey(ExomMonthGrid.selectionFillKey);
      expect(fill, findsOneWidget);
      final fromRect = tester.getRect(
        find.byKey(ExomMonthGrid.visualKey(from)),
      );
      expect(tester.getRect(fill), fromRect);
      await pumpComponent(tester, slideGrid(to));
      final toRect = tester.getRect(find.byKey(ExomMonthGrid.visualKey(to)));
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.getRect(fill).left, closeTo(fromRect.left, 2));
      await tester.pump(const Duration(milliseconds: 99));
      final mid = tester.getRect(fill).left;
      expect(mid, greaterThan(fromRect.left));
      expect(mid, lessThan(toRect.left));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(fill).left, lessThan(toRect.left));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getRect(fill), toRect);
      expect(ExomMotion.selectionSlide, const Duration(milliseconds: 200));
      // The cell itself carries no fill: the sliding layer paints it.
      expect(_decorationOf(tester, to).color, isNull);
    });

    testWidgets('to another week it slides along the new row', (tester) async {
      await pumpComponent(tester, slideGrid(from));
      await tester.pumpAndSettle();
      await pumpComponent(tester, slideGrid(otherWeek));
      await tester.pump(const Duration(milliseconds: 100));
      final target = tester.getRect(
        find.byKey(ExomMonthGrid.visualKey(otherWeek)),
      );
      final mid = tester.getRect(find.byKey(ExomMonthGrid.selectionFillKey));
      expect(mid.top, target.top);
      expect(mid.left, lessThan(target.left));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(ExomMonthGrid.selectionFillKey)),
        target,
      );
    });

    testWidgets('reduced motion: no sliding layer, crossfade in the cell', (
      tester,
    ) async {
      await pumpComponent(tester, slideGrid(from), disableAnimations: true);
      await pumpComponent(tester, slideGrid(to), disableAnimations: true);
      expect(find.byKey(ExomMonthGrid.selectionFillKey), findsNothing);
      await tester.pumpAndSettle();
      final palette = themeFor(
        Brightness.dark,
      ).extension<ExomThemePalette>()!;
      expect(_decorationOf(tester, to).color, palette.selectionFill);
    });

    testWidgets('without slideSelection the grid is unchanged', (
      tester,
    ) async {
      await pumpComponent(tester, slideGrid(from, slide: false));
      expect(find.byKey(ExomMonthGrid.selectionFillKey), findsNothing);
      final palette = themeFor(
        Brightness.dark,
      ).extension<ExomThemePalette>()!;
      expect(_decorationOf(tester, from).color, palette.selectionFill);
    });

    testWidgets('monthTransition: the weeks move, the initials stay', (
      tester,
    ) async {
      Widget monthGrid(DateTime month) => ExomMonthGrid(
        month: month,
        selected: null,
        today: _today,
        markOf: (_) => ExomDayMark.none,
        monthTransition: true,
      );
      await pumpComponent(tester, monthGrid(_month));
      final header = tester.getRect(find.byKey(ExomMonthGrid.weekdayHeaderKey));
      final day = DateTime(2026, 12, 15);
      await pumpComponent(tester, monthGrid(DateTime(2026, 12)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(ExomMonthGrid.weekdayHeaderKey)),
        header,
      );
      expect(find.byKey(ExomMonthGrid.weekdayHeaderKey), findsOneWidget);
      final mid = tester.getTopLeft(find.byKey(ExomMonthGrid.visualKey(day)));
      await tester.pumpAndSettle();
      final rest = tester.getTopLeft(find.byKey(ExomMonthGrid.visualKey(day)));
      expect(mid.dx, greaterThan(rest.dx));
      expect(
        find.byKey(ExomMonthGrid.visualKey(DateTime(2026, 11, 15))),
        findsNothing,
      );
    });
  });
}
