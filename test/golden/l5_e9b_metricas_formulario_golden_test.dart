// L5-E9b «Formulario de métricas» goldens
// (docs/plans/rediseno-app-l5-contrato-v2.md, CC 4 and CC 8): the top of the
// form with a loaded day (title, the numbered sections 01 date and 02 weight
// with the stepper, the start of 03), in dark and light at text scale 1.0 and
// 1.6 on 390x844, without animation; and the body measurements (section 06
// in list mode) at 1.0.
//
// L6-D2 «06 Medidas corporales»: the list of flat rows (regenerated), the
// body view on the C5b figure with «Brazo» selected and the sheet of a pair,
// in dark and light at 1.0, with the measures of the sketch.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e9b_metricas_formulario_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/theme/wcag_contrast.dart';
import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines, themeFor;
import '../core/widgets/expect_no_lime_ink.dart';
import '../features/metrics/metrics_form_scene.dart';
import '../features/metrics/metrics_measures_helpers.dart';

/// The measures of the sketch «L6 · 06 Medidas corporales»: hips without
/// data, the thigh with only the left side.
final BodyMetricEntity _measuresMetric = BodyMetricEntity(
  id: 'metric-l6',
  date: DateTime(2026, 11, 19),
  weightKg: 68.4,
  heightCm: 168,
  muscleMassKg: 31.2,
  sleepHours: 7.5,
  neckCm: 38,
  shouldersCm: 112,
  chestCm: 96.5,
  waistCm: 74,
  armLeftCm: 33,
  armRightCm: 33.5,
  forearmLeftCm: 27,
  forearmRightCm: 27.5,
  thighLeftCm: 55,
  calfLeftCm: 36.5,
  calfRightCm: 36.5,
);

/// Runs after the golden: painting the tree for expectNoLimeInk leaves the
/// text of the filled fields out of a later capture in the light theme.
Future<void> _checks(WidgetTester tester, Brightness brightness) async {
  expectNoOverflow(tester);
  if (brightness == Brightness.light) expectNoLimeInk(tester);
  await expectTapTargetGuidelines(tester);
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// [_checks] over an open sheet. textContrastGuideline samples rendered
/// pixels and misreads the muted «Última» line of the sheet (as it does the
/// confirmation sheet body, exom_sheet_confirm_test): a report may only name
/// that line, and the real colour pairs of the sheet must reach AA.
Future<void> _sheetChecks(WidgetTester tester, Brightness brightness) async {
  expectNoOverflow(tester);
  if (brightness == Brightness.light) expectNoLimeInk(tester);
  await expectTapTargetGuidelines(tester);
  final handle = tester.ensureSemantics();
  final evaluation = await textContrastGuideline.evaluate(tester);
  handle.dispose();
  if (!evaluation.passed) {
    final reason = evaluation.reason ?? '';
    expect(
      RegExp('SemanticsNode#').allMatches(reason).length,
      1,
      reason: reason,
    );
    expect(reason, contains('label: "Última:'), reason: reason);
  }
  final palette = themeFor(brightness).extension<ExomThemePalette>()!;
  expect(
    contrastRatio(palette.textSecondary, palette.surface),
    greaterThanOrEqualTo(4.5),
  );
  expect(
    contrastRatio(palette.textPrimary, palette.surface),
    greaterThanOrEqualTo(4.5),
  );
}

void main() {
  // D19 (CC 10): the weight is the client's own figure, painted in `data`.
  for (final brightness in Brightness.values) {
    testWidgets('the weight figure is painted in data (${brightness.name})', (
      tester,
    ) async {
      await pumpMetricsFormScene(tester, brightness: brightness);
      final stepper = find.byKey(const Key('metrics-weight-stepper'));
      final figure = tester.widget<RichText>(
        find
            .descendant(
              of: stepper,
              matching: find.textContaining('68,4', findRichText: true),
            )
            .first,
      );
      final palette = tester.element(stepper).exomPalette;
      expect(figure.text.style?.color, palette.data);
    });
  }

  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden metricas_formulario_$suffix', (tester) async {
        await pumpMetricsFormScene(
          tester,
          brightness: brightness,
          textScaler: TextScaler.linear(scale),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/metricas_formulario_$suffix.png'),
        );
        await _checks(tester, brightness);
      });
    }

    testWidgets('golden metricas_formulario_medidas_${brightness.name}_1_0x', (
      tester,
    ) async {
      await pumpMetricsFormScene(tester, brightness: brightness);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MetricsFormPage)),
      );
      final toggle = find.text(l10n.listViewToggle);
      await tester.scrollUntilVisible(
        toggle,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/metricas_formulario_medidas_${brightness.name}_1_0x.png',
        ),
      );
      await _checks(tester, brightness);
    });

    testWidgets('golden metricas_formulario_cuerpo_${brightness.name}_1_0x', (
      tester,
    ) async {
      await pumpMetricsFormScene(
        tester,
        brightness: brightness,
        latest: _measuresMetric,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MetricsFormPage)),
      );
      final toggle = find.text(l10n.bodyViewToggle);
      await tester.scrollUntilVisible(
        toggle,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      // «Brazo» chosen on the figure; its sheet closed without changes.
      final handle = tester.ensureSemantics();
      final arm = find.bySemanticsLabel(RegExp('^${l10n.measureArm}'));
      await tester.ensureVisible(arm.first);
      await tester.pumpAndSettle();
      // The semantic box is not hit-tested; the figure under it takes the tap.
      await tester.tap(arm.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      handle.dispose();
      Navigator.of(tester.element(measureSheet())).pop();
      await tester.pumpAndSettle();
      final hint = find.text(l10n.metricsMeasureTapZone);
      await tester.scrollUntilVisible(
        hint,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/metricas_formulario_cuerpo_${brightness.name}_1_0x.png',
        ),
      );
      await _checks(tester, brightness);
    });

    testWidgets(
      'golden metricas_formulario_hoja_bilateral_${brightness.name}_1_0x',
      (tester) async {
        await pumpMetricsFormScene(
          tester,
          brightness: brightness,
          latest: _measuresMetric,
        );
        await openMeasureSheet(tester, BodyZone.upperArm);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/metricas_formulario_hoja_bilateral_'
            '${brightness.name}_1_0x.png',
          ),
        );
        await _sheetChecks(tester, brightness);
      },
    );
  }
}
