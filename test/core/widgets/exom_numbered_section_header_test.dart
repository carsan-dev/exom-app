import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Widget _header() => const ExomNumberedSectionHeader(
  n: 2,
  title: 'Fuerza y movilidad del tren inferior',
  trailing: Text('Ver todo'),
);

void main() {
  registerTextComponentMatrix('ExomNumberedSectionHeader', _header);

  for (final brightness in Brightness.values) {
    testWidgets('index in data, title upper case in text colour '
        '(${brightness.name})', (tester) async {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        const ExomNumberedSectionHeader(n: 2, title: 'Calentamiento'),
        brightness: brightness,
      );
      expect(tester.widget<Text>(find.text('02')).style?.color, palette.data);
      final title = tester.widget<Text>(find.text('CALENTAMIENTO'));
      expect(title.style?.color, palette.textPrimary);
      expect(title.style?.fontSize, ExomType.section.fontSize);
      expect(title.style?.fontWeight, FontWeight.w800);
    });
  }

  testWidgets('semantics: header with the original title', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ExomNumberedSectionHeader(n: 1, title: 'Calentamiento'),
    );
    expect(
      tester.getSemantics(find.text('CALENTAMIENTO')),
      matchesSemantics(isHeader: true, label: 'Calentamiento'),
    );
    expect(find.bySemanticsLabel('CALENTAMIENTO'), findsNothing);
    handle.dispose();
  });

  testWidgets('trailing is shown and a long title wraps without cut', (
    tester,
  ) async {
    await pumpComponent(tester, _header(), width: 320, textScale: 1.6);
    expect(find.text('Ver todo'), findsOneWidget);
    final title = find.text('FUERZA Y MOVILIDAD DEL TREN INFERIOR');
    expect(title, findsOneWidget);
    // Wrapped: taller than a single line of the scaled title.
    expect(tester.getSize(title).height, greaterThan(22 * 1.6 * 1.5));
    expect(tester.widget<Text>(title).maxLines, isNull);
    expectNoOverflow(tester);
  });

  testWidgets('padding is directional, so RTL mirrors it', (tester) async {
    await pumpComponent(
      tester,
      const ExomNumberedSectionHeader(n: 1, title: 'Calentamiento'),
    );
    final paddings = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byType(ExomNumberedSectionHeader),
            matching: find.byType(Padding),
          ),
        )
        .map((p) => p.padding);
    expect(
      paddings,
      contains(const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 6)),
    );
  });
}
