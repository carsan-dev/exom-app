// Redesign L5 control goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// sections 2.1, T0.4 and 5.3): two scenes of the controls of the base, in dark
// and light at text scale 1.0 and 1.6 on the 390x844 surface of the L0
// baseline, except componentes_controles_progreso at 1.6, which is 390x900 so
// the whole scene (month grid and the chart's base rule) fits in the image.
//
// Same platform rules as components_golden_test.dart: generated on Windows
// with the bundled fonts (loadRedesignFonts), so regenerate on the same OS
// with:
//   flutter test --update-goldens test/golden/components_controls_golden_test.dart
//
// Scenes:
// * componentes_controles_seleccion: ExomSegmentedControl, ExomScaleChips,
//   ExomChoiceChips.multi and ExomNumeralStepper.
// * componentes_controles_progreso: ExomStepHeader, ExomMonthGrid,
//   ExomProgressRule, ExomOperationBar and ExomLineChart.
//
// Fixed data and a fixed injected «today»; nothing reads the clock. Every
// animation is at rest in the first frame (the operation bar is determinate).
@Tags(['golden'])
library;

import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_line_chart.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

const _pad = EdgeInsetsDirectional.symmetric(horizontal: 20);

Widget _seleccion() {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExomSegmentedControl<String>(
            options: const ['Semana', 'Mes', 'Año'],
            selected: 'Mes',
            labelOf: (o) => o,
            onChanged: (_) {},
          ),
          const SizedBox(height: 24),
          ExomScaleChips(
            min: 1,
            max: 5,
            selected: 3,
            lowLabel: 'Nada',
            highLabel: 'Muchísimo',
            onChanged: (_) {},
          ),
          const SizedBox(height: 24),
          ExomChoiceChips<String>.multi(
            options: const ['Pecho', 'Espalda', 'Piernas', 'Hombros'],
            selectedValues: const {'Espalda', 'Piernas'},
            labelOf: (o) => o,
            onToggled: (_) {},
          ),
          const SizedBox(height: 24),
          ExomNumeralStepper(
            value: 68.4,
            min: 40,
            max: 200,
            step: 0.5,
            unit: 'kg',
            label: 'Peso',
            decrementLabel: 'Restar',
            incrementLabel: 'Sumar',
            acceptsTypedOutOfRange: true,
            onChanged: (_) {},
          ),
        ],
      ),
    ),
  );
}

ExomDayMark _mark(DateTime day) {
  if (day.month != 11) return ExomDayMark.none;
  return switch (day.day) {
    2 || 4 || 9 || 11 || 16 || 18 => ExomDayMark.done,
    6 || 13 => ExomDayMark.missed,
    20 || 23 || 25 || 27 => ExomDayMark.pending,
    _ => ExomDayMark.none,
  };
}

Widget _progreso() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
          child: ExomStepHeader(
            step: 2,
            total: 5,
            kicker: 'Paso 2 de 5',
            first: 'Tus datos',
            second: 'corporales',
          ),
        ),
        ExomMonthGrid(
          month: DateTime(2026, 11),
          selected: DateTime(2026, 11, 18),
          today: DateTime(2026, 11, 20),
          markOf: _mark,
          onSelect: (_) {},
          doneAsFill: true,
        ),
        const SizedBox(height: 20),
        const Padding(padding: _pad, child: ExomProgressRule(value: 0.78)),
        const SizedBox(height: 16),
        const Padding(
          padding: _pad,
          child: ExomProgressRule(value: 5 / 7, thickness: 4, segments: 7),
        ),
        const SizedBox(height: 16),
        const Padding(padding: _pad, child: ExomOperationBar(value: 0.6)),
        const SizedBox(height: 16),
        const Padding(
          padding: _pad,
          child: ExomLineChart(
            points: [
              ExomPoint(0, 71.4),
              ExomPoint(15, 70.8),
              ExomPoint(30, 70.1),
              ExomPoint(45, 69.6),
              ExomPoint(60, 69.0),
              ExomPoint(75, 68.9),
              ExomPoint(90, 68.4),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

void main() {
  final scenes = <String, Widget Function()>{
    'componentes_controles_seleccion': _seleccion,
    'componentes_controles_progreso': _progreso,
  };
  for (final scene in scenes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        final name =
            '${scene.key}_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
        final height =
            scene.key == 'componentes_controles_progreso' && scale == 1.6
            ? 900.0
            : 844.0;
        testWidgets('golden $name', (tester) async {
          await pumpComponent(
            tester,
            scene.value(),
            brightness: brightness,
            textScale: scale,
            height: height,
          );
          expectNoOverflow(tester);
          // The whole scene is in the image: nothing scrolls out of it, so
          // the grid and the chart (base rule included) are never cut.
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position;
          expect(
            position.maxScrollExtent,
            0,
            reason: 'the scene $name is taller than the image',
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
