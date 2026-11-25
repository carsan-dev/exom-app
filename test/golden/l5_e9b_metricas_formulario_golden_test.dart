// L5-E9b «Formulario de métricas» goldens
// (docs/plans/rediseno-app-l5-contrato-v2.md, CC 4 and CC 8): the top of the
// form with a loaded day (title, the numbered sections 01 date and 02 weight
// with the stepper, the start of 03), in dark and light at text scale 1.0 and
// 1.6 on 390x844, without animation; and the body measurements (section 06
// in list mode) at 1.0.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_e9b_metricas_formulario_golden_test.dart
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../core/widgets/expect_no_lime_ink.dart';
import '../features/metrics/metrics_form_scene.dart';

/// Runs after the golden: painting the tree for expectNoLimeInk leaves the
/// text of the filled fields out of a later capture in the light theme.
Future<void> _checks(WidgetTester tester, Brightness brightness) async {
  expectNoOverflow(tester);
  if (brightness == Brightness.light) expectNoLimeInk(tester);
  await expectTapTargetGuidelines(tester);
  await expectLater(tester, meetsGuideline(textContrastGuideline));
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
  }
}
