// L5-D40 (docs/plans/rediseno-exom-app.md): the streak milestone of «Retos»
// drops the bands at ±12° and shows, right of the numeral, one square per day
// of the streak in rows of 7 (sketch
// docs/bocetos/rediseno-exom-app/extension/retos-racha.html, «B · Semanas»):
// 18 dp squares 4 dp apart, lit in the data colour and dark in the rule tone,
// the whole grid at 50 % opacity, its bottom on the numeral's baseline, at
// most the last 4 weeks and «+N días anteriores» below for the rest.
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_milestone_mark.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_streak_weeks.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../core/widgets/exom_component_harness.dart';
import '../../core/widgets/expect_no_lime_ink.dart';
import 'challenges_test_support.dart';

/// Content padding of the band (`.x-band > .pad`), the margin of the section.
const double _pad = 20;

Finder get _mark => find.byType(ChallengeMilestoneMark);

Finder get _numeral =>
    find.descendant(of: _mark, matching: find.byKey(ExomNumeral.valueKey));

Finder get _grid => find.byKey(ChallengeStreakWeeks.gridKey);

/// Global y of the alphabetic baseline of the numeral's text, measured with a
/// [TextPainter] on the painted span (same style, scaler and height rules) and
/// mapped through the real transforms (including a shrinking `FittedBox`).
double _numeralBaseline(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(_numeral);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textHeightBehavior: paragraph.textHeightBehavior,
    textWidthBasis: paragraph.textWidthBasis,
  )..layout();
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  painter.dispose();
  return paragraph.localToGlobal(Offset(0, baseline)).dy;
}

Future<void> _pumpMark(
  WidgetTester tester,
  int days, {
  Brightness brightness = Brightness.dark,
  Locale locale = const Locale('es'),
  double width = 390,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: SingleChildScrollView(
          child: ChallengeMilestoneMark(
            value: '$days',
            days: days,
            semanticsLabel: '$days días',
          ),
        ),
      ),
    ),
    brightness: brightness,
    locale: locale,
    width: width,
  );
}

ExomThemePalette _palette(WidgetTester tester) =>
    tester.element(_mark).exomPalette;

void main() {
  group('streakWeeksFor (L5-D40)', () {
    // (days, rows, lit, earlier)
    const table = <(int, int, int, int)>[
      (0, 1, 0, 0),
      (1, 1, 1, 0),
      (7, 1, 7, 0),
      (12, 2, 12, 0),
      (28, 4, 28, 0),
      (29, 4, 22, 7),
      (35, 4, 28, 7),
      (40, 4, 26, 14),
      (365, 4, 22, 343),
    ];
    for (final (days, rows, lit, earlier) in table) {
      test('$days days -> $rows rows, $lit lit, +$earlier', () {
        final weeks = streakWeeksFor(days);
        expect(weeks.rows, rows);
        expect(weeks.lit, lit);
        expect(weeks.earlier, earlier);
        expect(weeks.squares, rows * 7);
        // Lit squares plus earlier days always account for the whole streak.
        expect(weeks.lit + weeks.earlier, days);
      });
    }

    test('a negative count is an empty streak', () {
      final weeks = streakWeeksFor(-3);
      expect((weeks.rows, weeks.lit, weeks.earlier), (1, 0, 0));
    });
  });

  group('ChallengeMilestoneMark weeks (L5-D40)', () {
    for (final brightness in Brightness.values) {
      testWidgets('12 days: 14 squares, 12 lit, right of the numeral on its '
          'baseline, ${brightness.name}', (tester) async {
        await _pumpMark(tester, 12, brightness: brightness);
        final palette = _palette(tester);

        // No bands: nothing under the mark is rotated.
        final rotated = tester
            .widgetList<Transform>(
              find.descendant(of: _mark, matching: find.byType(Transform)),
            )
            .where(
              (t) =>
                  math
                      .atan2(t.transform.entry(1, 0), t.transform.entry(0, 0))
                      .abs() >
                  1e-6,
            );
        expect(rotated, isEmpty);

        final on = find.byKey(ChallengeStreakWeeks.onKey);
        final off = find.byKey(ChallengeStreakWeeks.offKey);
        expect(on, findsNWidgets(12));
        expect(off, findsNWidgets(2));
        for (final square in [...on.evaluate(), ...off.evaluate()]) {
          final box = square.renderObject! as RenderBox;
          expect(box.size, const Size.square(18));
        }
        expect(tester.widget<ColoredBox>(on.first).color, palette.data);
        expect(tester.widget<ColoredBox>(off.first).color, palette.borderSoft);
        // Squares 4 dp apart, rows filled top to bottom.
        final squares = on.evaluate().toList();
        final first = tester.getRect(find.byWidget(squares[0].widget));
        final second = tester.getRect(find.byWidget(squares[1].widget));
        final eighth = tester.getRect(find.byWidget(squares[7].widget));
        expect(second.left - first.right, closeTo(4, 0.01));
        expect(eighth.top - first.bottom, closeTo(4, 0.01));
        expect(eighth.left, closeTo(first.left, 0.01));

        // The whole grid at 50 %, decorative.
        final opacity = tester.widget<Opacity>(
          find.ancestor(of: _grid, matching: find.byType(Opacity)).first,
        );
        expect(opacity.opacity, 0.5);
        expect(
          find.ancestor(
            of: _grid,
            matching: find.byWidgetPredicate(
              (w) => w is ExcludeSemantics && w.excluding,
            ),
          ),
          findsOneWidget,
        );

        // Right of the numeral, at the content's end, bottom on the baseline.
        final grid = tester.getRect(_grid);
        final numeral = tester.getRect(_numeral);
        final mark = tester.getRect(_mark);
        expect(grid.left, greaterThanOrEqualTo(numeral.right));
        expect(grid.right, closeTo(mark.right - _pad, 0.01));
        expect((grid.bottom - _numeralBaseline(tester)).abs(), lessThan(1));
        expect(find.textContaining('+'), findsNothing);

        expect(find.bySemanticsLabel('12 días'), findsOneWidget);
        expectParagraphContrast(tester, _mark, fallback: palette.background);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        expectNoOverflow(tester);
      });

      for (final (locale, earlier) in const [
        (Locale('es'), '+14 días anteriores'),
        (Locale('en'), '+14 earlier days'),
      ]) {
        testWidgets('40 days: 28 squares, 26 lit and «$earlier», '
            '${brightness.name}', (tester) async {
          await _pumpMark(tester, 40, brightness: brightness, locale: locale);
          expect(find.byKey(ChallengeStreakWeeks.onKey), findsNWidgets(26));
          expect(find.byKey(ChallengeStreakWeeks.offKey), findsNWidgets(2));
          final more = find.text(earlier);
          expect(more, findsOneWidget);
          // Below the grid, at the content's end, and read aloud.
          final mark = tester.getRect(_mark);
          final text = tester.getRect(more);
          expect(text.top, greaterThanOrEqualTo(tester.getRect(_grid).bottom));
          expect(text.right, closeTo(mark.right - _pad, 0.01));
          expect(find.bySemanticsLabel(earlier), findsOneWidget);
          final palette = _palette(tester);
          expectParagraphContrast(tester, _mark, fallback: palette.background);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          expectNoOverflow(tester);
        });
      }
    }

    testWidgets('0 days: one row of 7 dark squares', (tester) async {
      await _pumpMark(tester, 0);
      expect(find.byKey(ChallengeStreakWeeks.onKey), findsNothing);
      expect(find.byKey(ChallengeStreakWeeks.offKey), findsNWidgets(7));
      expect(tester.getSize(_grid), const Size(7 * 18 + 6 * 4, 18));
      expect(find.textContaining('+'), findsNothing);
      expectNoOverflow(tester);
    });

    test('«+N días anteriores» is an ICU plural (es, en)', () {
      final es = lookupAppLocalizations(const Locale('es'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(es.challengesStreakEarlierDays(1), '+1 día anterior');
      expect(es.challengesStreakEarlierDays(14), '+14 días anteriores');
      expect(en.challengesStreakEarlierDays(1), '+1 earlier day');
      expect(en.challengesStreakEarlierDays(14), '+14 earlier days');
    });

    // Large text: beside the numeral while both fit in one row; otherwise the
    // grid drops below it, still at the content's end. Never overflows nor
    // splits a word.
    for (final width in const [300.0, 320.0, 360.0, 390.0]) {
      for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
        for (final days in const [12, 40, 365]) {
          testWidgets('${width.toInt()} dp, ${scale}x, $days days', (
            tester,
          ) async {
            await _pumpMark(
              tester,
              days,
              width: width,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            expectNoOverflow(tester);
            expectNoBrokenWords(tester);
            final mark = tester.getRect(_mark);
            final grid = tester.getRect(_grid);
            final numeral = tester.getRect(_numeral);
            expect(grid.right, closeTo(mark.right - _pad, 0.01));
            expect(numeral.left, greaterThanOrEqualTo(mark.left + _pad - 0.01));
            expect(numeral.right, lessThanOrEqualTo(mark.right - _pad + 0.01));
            // In one row the grid shares the numeral's line; otherwise it is
            // entirely below the numeral.
            final beside = grid.top < numeral.bottom;
            if (beside) {
              expect(grid.left, greaterThanOrEqualTo(numeral.right));
              expect(
                (grid.bottom - _numeralBaseline(tester)).abs(),
                lessThan(1),
              );
            } else {
              expect(grid.top, greaterThanOrEqualTo(numeral.bottom));
            }
            if (width == 390 && scale == 1.0 && days == 12) {
              expect(beside, isTrue, reason: 'fits in one row');
            }
            if (width == 300 && scale == 2.0) {
              expect(beside, isFalse, reason: 'does not fit in one row');
            }
          });
        }
      }
    }
  });
}
