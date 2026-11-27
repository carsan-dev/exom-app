import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme/wcag_contrast.dart';
import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

const _body = 'Cuando tu entrenador te asigne uno, aparecerá aquí.';

Widget _empty() => ExomEmptyState(
  first: 'Aún no hay',
  second: 'entrenamientos',
  body: _body,
  action: FilledButton(onPressed: () {}, child: const Text('Actualizar')),
);

void main() {
  // The rendered-text guideline samples anti-aliased glyph pixels and misreads
  // 14 px secondary text in the light theme (3.10 reported for a pair that is
  // far above 4.5), so contrast is checked on the real colours below.
  registerTextComponentMatrix('ExomEmptyState', _empty, checkContrast: false);

  for (final brightness in Brightness.values) {
    testWidgets('body contrast on background and panel (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(tester, _empty(), brightness: brightness);
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      final colour = tester.widget<Text>(find.text(_body)).style!.color!;
      expect(
        contrastRatio(colour, palette.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrastRatio(colour, palette.surface), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('uses the two-line headline with first and second lines', (
    tester,
  ) async {
    await pumpComponent(tester, _empty());
    final headline = tester.widget<ExomTwoLineHeadline>(
      find.byType(ExomTwoLineHeadline),
    );
    expect(headline.first, 'Aún no hay');
    expect(headline.second, 'entrenamientos');
    expect(find.text(_body), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
  });

  testWidgets('body and action are optional', (tester) async {
    await pumpComponent(
      tester,
      const ExomEmptyState(first: 'Nada', second: 'por aquí'),
    );
    expect(find.byType(ExomTwoLineHeadline), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('lead: strong line between the headline and the body '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        const ExomEmptyState(
          first: 'Sin plan.',
          second: 'Todavía.',
          lead: 'No tienes entrenamientos asignados',
          body: _body,
        ),
        brightness: brightness,
      );
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      final lead = tester.widget<Text>(
        find.text('No tienes entrenamientos asignados'),
      );
      expect(lead.style!.fontWeight, FontWeight.w600);
      expect(lead.style!.color, palette.textPrimary);
      expect(
        contrastRatio(lead.style!.color!, palette.background),
        greaterThanOrEqualTo(4.5),
      );
      final headline = tester.getRect(find.byType(ExomTwoLineHeadline));
      final leadRect = tester.getRect(
        find.text('No tienes entrenamientos asignados'),
      );
      final bodyRect = tester.getRect(find.text(_body));
      expect(leadRect.top - headline.bottom, 14);
      expect(bodyRect.top - leadRect.bottom, 14);
      expect(leadRect.left, 20);
    });
  }

  testWidgets('content is start aligned with 20 dp inset', (tester) async {
    await pumpComponent(tester, _empty());
    expect(tester.getTopLeft(find.byType(ExomTwoLineHeadline)).dx, 20);
    expect(tester.getTopLeft(find.text(_body)).dx, 20);
  });

  testWidgets('semantics: headline is a header; body is read', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _empty());
    final data = tester
        .getSemantics(find.byType(ExomTwoLineHeadline))
        .getSemanticsData();
    expect(data.label, 'Aún no hay entrenamientos');
    expect(data.flagsCollection.isHeader, isTrue);
    expect(find.bySemanticsLabel(_body), findsOneWidget);
    handle.dispose();
  });

  testWidgets('body in secondary text colour', (tester) async {
    await pumpComponent(tester, _empty());
    final palette = themeFor(Brightness.dark).extension<ExomThemePalette>()!;
    final style = tester.widget<Text>(find.text(_body)).style!;
    expect(style.color, palette.textSecondary);
    expect(style.fontSize, 14); // `.sec` of the sketch
  });
}
