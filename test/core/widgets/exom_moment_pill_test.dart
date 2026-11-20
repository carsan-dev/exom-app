import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_moment_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Iterable<DecoratedBox> _boxes(WidgetTester tester) =>
    tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(ExomMomentPill),
        matching: find.byType(DecoratedBox),
      ),
    );

BoxDecoration _fill(WidgetTester tester) => _boxes(tester)
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.color != null);

void main() {
  registerTextComponentMatrix(
    'ExomMomentPill',
    () => const ExomMomentPill('Hoy'),
  );

  for (final brightness in Brightness.values) {
    testWidgets('lime fill, dark ink, outline only in light '
        '(${brightness.name})', (tester) async {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        const ExomMomentPill('Hoy'),
        brightness: brightness,
      );
      expect(_fill(tester).color, palette.limeFill);
      final text = tester.widget<Text>(find.text('HOY'));
      expect(text.style?.color, palette.onLimeFill);
      expect(text.style?.fontWeight, FontWeight.w600);
      final foreground = _boxes(tester)
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>();
      if (brightness == Brightness.dark) {
        expect(palette.limeFillOutline, isNull);
        expect(foreground, isEmpty);
      } else {
        expect(palette.limeFillOutline, isNotNull);
        expect(foreground, hasLength(1));
        expect(foreground.single.top.color, palette.limeFillOutline);
        expect(foreground.single.top.width, ExomRule.outline);
      }
    });
  }

  testWidgets('keeps at least 32 dp of height and is not stretched', (
    tester,
  ) async {
    await pumpComponent(tester, const ExomMomentPill('Hoy'));
    final size = tester.getSize(find.byType(ExomMomentPill));
    expect(size.height, greaterThanOrEqualTo(32));
    expect(size.width, lessThan(120));
  });

  testWidgets('semantics keep the original case', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, const ExomMomentPill('Hoy'));
    expect(find.bySemanticsLabel('Hoy'), findsOneWidget);
    expect(find.bySemanticsLabel('HOY'), findsNothing);
    handle.dispose();
  });
}
