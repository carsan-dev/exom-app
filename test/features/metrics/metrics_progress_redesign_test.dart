// L5-E9a · «Progreso»: structure of the redesigned screen (sketch
// e-migradas.html, frame «Progreso») and CC 3 / CC 4 of the batch: no overflow
// at 320 dp (1.3x, 1.6x) and 360 dp (1.6x) in es and en, all the content
// reachable by scrolling at 2.0x, tap targets >= 48 dp in both themes.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../../core/widgets/expect_no_lime_ink.dart';
import 'metrics_progress_redesign_fixture.dart';

const _surfaces = [(320.0, 1.3), (320.0, 1.6), (360.0, 1.6)];
const _locales = [Locale('es'), Locale('en')];

void main() {
  group('Progreso structure', () {
    testWidgets('weight is the protagonist numeral in the data colour', (
      tester,
    ) async {
      await pumpProgressScene(tester, height: 1400);
      final numeral = find.byType(ExomNumeral);
      expect(numeral, findsOneWidget);
      final widget = tester.widget<ExomNumeral>(numeral);
      expect(widget.size, ExomNumeralSize.hero96);
      expect(widget.value, '68,4');
      expect(widget.unit, 'kg');
      expect(widget.isData, isTrue);
      // The delta sentence keeps its single-text form next to the numeral.
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
    });

    testWidgets('two-line headline and numbered sections 01 and 02', (
      tester,
    ) async {
      await pumpProgressScene(tester, height: 1400);
      expect(find.byType(ExomTwoLineHeadline), findsOneWidget);
      final headers = tester
          .widgetList<ExomNumberedSectionHeader>(
            find.byType(ExomNumberedSectionHeader),
          )
          .toList();
      expect(headers.map((h) => h.n), [1, 2]);
      expect(headers.first.title, 'Últimas medidas');
      expect(headers.last.title, 'Fotos de progreso');
      expect(find.byType(ExomIndexNumber), findsNWidgets(2));
    });

    testWidgets('latest measures are figure columns, keys intact', (
      tester,
    ) async {
      await pumpProgressScene(tester, height: 1400);
      expect(find.byType(ExomFigureColumns), findsWidgets);
      expect(
        find.byKey(const ValueKey('progress-measure-waist_cm-2026-11-18')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('progress-measure-weight_kg-2026-11-18')),
        findsOneWidget,
      );
    });

    testWidgets('the chart line is data-coloured, axis on the right', (
      tester,
    ) async {
      await pumpProgressScene(tester, height: 1400);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = chart.data.lineBarsData.single;
      expect(bar.color, AppTheme.dark.extension<ExomThemePalette>()!.data);
      expect(chart.data.titlesData.rightTitles.sideTitles.showTitles, isTrue);
      expect(chart.data.titlesData.leftTitles.sideTitles.showTitles, isFalse);
    });

    testWidgets('the cached band is kept', (tester) async {
      await pumpProgressScene(tester, fromCache: true, height: 1400);
      expect(find.text('Sin conexión · datos guardados'), findsOneWidget);
    });
  });

  group('Progreso layout', () {
    for (final (width, scale) in _surfaces) {
      for (final locale in _locales) {
        testWidgets(
          'no overflow at ${width}dp x$scale, ${locale.languageCode}',
          (tester) async {
            await pumpProgressScene(
              tester,
              fromCache: true,
              width: width,
              height: 640,
              textScale: scale,
              locale: locale,
            );
            expectNoOverflow(tester);
            await tester.scrollUntilVisible(
              find.byKey(const Key('progress-photos-row')),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            expectNoOverflow(tester);
          },
        );
      }
    }

    testWidgets('at 2.0x everything is reachable by scrolling', (tester) async {
      await pumpProgressScene(tester, width: 320, height: 640, textScale: 2.0);
      await tester.scrollUntilVisible(
        find.byKey(const Key('progress-photos-row')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expectNoOverflow(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('tap targets and ink, ${brightness.name}', (tester) async {
        await pumpProgressScene(tester, brightness: brightness);
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
      });
    }
  });
}
