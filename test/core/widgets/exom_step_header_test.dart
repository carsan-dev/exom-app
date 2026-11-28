// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomStepHeader (ESPEC §3,
// `.x-step`): kicker, two-line headline and a rule of N segments of 4 px.
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_step_header.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Widget _header({int step = 2, int total = 5}) => ExomStepHeader(
  step: step,
  total: total,
  kicker: 'Paso $step de $total',
  first: 'Tus datos',
  second: 'corporales',
);

void main() {
  registerTextComponentMatrix('ExomStepHeader', _header);

  testWidgets('composes ExomKicker, ExomTwoLineHeadline and a 4 px rule of '
      'N segments', (tester) async {
    await pumpComponent(tester, _header());
    expect(find.byType(ExomKicker), findsOneWidget);
    expect(find.byType(ExomTwoLineHeadline), findsOneWidget);
    final rule = tester.widget<ExomProgressRule>(find.byType(ExomProgressRule));
    expect(rule.segments, 5);
    expect(rule.thickness, ExomRule.bar);
    expect(rule.value, closeTo(2 / 5, 1e-9));
    expect(
      find.byKey(const ValueKey('exom-rule-segment-on')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('exom-rule-segment-off')),
      findsNWidgets(3),
    );
  });

  testWidgets('semantics: «paso X de N», headline as header', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      ExomStepHeader(
        step: 3,
        total: 4,
        kicker: 'Medidas',
        first: 'Tus datos',
        second: 'corporales',
      ),
    );
    expect(find.bySemanticsLabel('Paso 3 de 4'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ExomTwoLineHeadline)),
      matchesSemantics(label: 'Tus datos corporales', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('semantics in English', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _header(), locale: const Locale('en'));
    expect(find.bySemanticsLabel('Step 2 of 5'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a kicker that says «Paso X de N» is not read twice', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _header());
    expect(
      find.bySemanticsLabel(RegExp('paso 2 de 5', caseSensitive: false)),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a different kicker is still read, besides the step', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      ExomStepHeader(
        step: 3,
        total: 4,
        kicker: 'Medidas',
        first: 'Tus datos',
        second: 'corporales',
      ),
    );
    expect(find.bySemanticsLabel('Medidas'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 3 de 4'), findsOneWidget);
    handle.dispose();
  });

  test('asserts 1 <= step <= total', () {
    final step = 6;
    expect(
      () => ExomStepHeader(
        step: step,
        total: 5,
        kicker: 'k',
        first: 'a',
        second: 'b',
      ),
      throwsAssertionError,
    );
  });
}
