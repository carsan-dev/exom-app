// Redesign L5 component goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// section 2.1 and 5.3): one scene per batch of the base (tanda 0), in dark and
// light at text scale 1.0 and 1.6 on the 390x844 surface of the L0 baseline.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts (loadRedesignFonts), so regenerate on the same
// OS with:
//   flutter test --update-goldens test/golden/components_golden_test.dart
//
// Scenes: componentes_texto (T0.2): ExomKicker, ExomTwoLineHeadline,
// ExomMomentPill, ExomNumeral, ExomNumberedSectionHeader, ExomFigureColumns and
// ExomIndexNumber.
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_moment_pill.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

/// Fixed fictitious data; nothing here depends on the clock or the locale
/// beyond the already formatted strings.
Widget _componentesTexto() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExomKicker('Semana 3', icon: Icons.calendar_today),
              const SizedBox(height: 10),
              const ExomTwoLineHeadline(
                first: 'Tu semana',
                second: 'en marcha',
                size: ExomHeadlineSize.screen,
              ),
              const SizedBox(height: 14),
              const ExomMomentPill('Hoy'),
              const SizedBox(height: 18),
              ExomNumeral(
                value: '68,4',
                unit: 'kg',
                size: ExomNumeralSize.hero96,
                side: Builder(
                  builder: (context) => Text(
                    'desde 71,4 kg',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  ExomIndexNumber(10),
                  SizedBox(width: 12),
                  ExomIndexNumber(100),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const ExomNumberedSectionHeader(
          n: 1,
          title: 'Calentamiento',
          trailing: Text('Ver todo'),
        ),
        const ExomFigureColumns(
          items: [
            ExomFigure(value: '6', label: 'ejercicios'),
            ExomFigure(value: '42', label: 'minutos', unit: 'min'),
            ExomFigure(value: '18', label: 'series'),
          ],
        ),
      ],
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'componentes_texto_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpComponent(
          tester,
          _componentesTexto(),
          brightness: brightness,
          textScale: scale,
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
