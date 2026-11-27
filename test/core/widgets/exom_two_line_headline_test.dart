import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Text _line(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

void main() {
  registerTextComponentMatrix(
    'ExomTwoLineHeadline',
    () => const ExomTwoLineHeadline(first: 'Tu semana', second: 'en marcha'),
  );

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;

    testWidgets('paints upper case, first in text, second in data '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        const ExomTwoLineHeadline(first: 'Tu semana', second: 'en marcha'),
        brightness: brightness,
      );
      final first = _line(tester, 'TU SEMANA');
      final second = _line(tester, 'EN MARCHA');
      expect(first.style?.color, palette.textPrimary);
      expect(second.style?.color, palette.data);
      expect(first.style?.fontSize, ExomType.headline2Section.fontSize);
      expect(first.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('isError paints the second line in error '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        const ExomTwoLineHeadline(
          first: 'No se pudo',
          second: 'guardar',
          isError: true,
        ),
        brightness: brightness,
      );
      expect(_line(tester, 'GUARDAR').style?.color, palette.error);
      expect(_line(tester, 'NO SE PUDO').style?.color, palette.textPrimary);
    });
  }

  testWidgets('screen size uses headline2Screen', (tester) async {
    await pumpComponent(
      tester,
      const ExomTwoLineHeadline(
        first: 'Hola',
        second: 'Ana',
        size: ExomHeadlineSize.screen,
      ),
    );
    expect(_line(tester, 'HOLA').style?.fontSize, 44);
    expect(_line(tester, 'ANA').style?.fontSize, 44);
  });

  testWidgets('single header node with the original text', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ExomTwoLineHeadline(first: 'Tu semana', second: 'en marcha'),
    );
    expect(
      tester.getSemantics(find.byType(ExomTwoLineHeadline)),
      matchesSemantics(isHeader: true, label: 'Tu semana en marcha'),
    );
    expect(find.bySemanticsLabel('TU SEMANA'), findsNothing);
    handle.dispose();
  });

  testWidgets('semanticsLabel overrides the label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ExomTwoLineHeadline(
        first: 'Tu semana',
        second: 'en marcha',
        semanticsLabel: 'Resumen semanal',
      ),
    );
    expect(
      tester.getSemantics(find.byType(ExomTwoLineHeadline)),
      matchesSemantics(isHeader: true, label: 'Resumen semanal'),
    );
    handle.dispose();
  });
}
