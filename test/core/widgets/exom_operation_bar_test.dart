// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomOperationBar (`.bar`),
// the 4 px bar of uploads and system operations: text colour, never lime
// (rule D19).
//
// How to test a screen that shows it: the indeterminate bar (value null)
// repeats while motion is standard, so `pumpAndSettle` would never settle.
// Pump fixed durations (`tester.pump(duration)`) or pump the screen with
// reduced motion (`disableAnimations: true`), where nothing loops.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'expect_no_lime_ink.dart';

Widget _padded(Widget child) => Padding(
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
  child: child,
);

Color _fillColor(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find.descendant(
        of: find.byKey(ExomOperationBar.fillKey),
        matching: find.byType(ColoredBox),
      ),
    )
    .color;

void main() {
  registerTextComponentMatrix(
    'ExomOperationBar',
    () => const ExomOperationBar(value: 0.6),
  );

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('determinate: 4 px, text-coloured fill, never lime or data '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _padded(const ExomOperationBar(value: 0.6)),
        brightness: brightness,
      );
      final bar = tester.getRect(find.byType(ExomOperationBar));
      expect(bar.height, 4);
      final fill = tester.getRect(find.byKey(ExomOperationBar.fillKey));
      expect(fill.width, closeTo(bar.width * 0.6, 0.01));
      expect(_fillColor(tester), palette.textPrimary);
      expect(_fillColor(tester), isNot(palette.limeFill));
      expect(_fillColor(tester), isNot(palette.data));
    });

    testWidgets('indeterminate: text-coloured, never lime '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _padded(const ExomOperationBar()),
        brightness: brightness,
      );
      expect(_fillColor(tester), palette.textPrimary);
      expectNoLimeInk(tester);
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('indeterminate moves while motion is standard', (tester) async {
    await pumpComponent(tester, _padded(const ExomOperationBar()));
    final first = tester.getRect(find.byKey(ExomOperationBar.fillKey));
    await tester.pump(const Duration(milliseconds: 500));
    final later = tester.getRect(find.byKey(ExomOperationBar.fillKey));
    expect(later.left, isNot(first.left));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // Leave without settling: it loops by design.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: indeterminate does not loop, pumpAndSettle '
      'returns', (tester) async {
    await pumpComponent(
      tester,
      _padded(const ExomOperationBar()),
      disableAnimations: true,
    );
    final first = tester.getRect(find.byKey(ExomOperationBar.fillKey));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.getRect(find.byKey(ExomOperationBar.fillKey)), first);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('determinate never loops: pumpAndSettle returns', (tester) async {
    await pumpComponent(tester, _padded(const ExomOperationBar(value: 0.3)));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('switching from indeterminate to a value stops the loop', (
    tester,
  ) async {
    double? value;
    late StateSetter set;
    await pumpComponent(
      tester,
      _padded(
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return ExomOperationBar(value: value);
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    set(() => value = 1);
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(ExomOperationBar));
    expect(
      tester.getRect(find.byKey(ExomOperationBar.fillKey)).width,
      closeTo(bar.width, 0.01),
    );
  });

  testWidgets('semantics: determinate exposes its value', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _padded(const ExomOperationBar(value: 0.25)));
    expect(
      tester
          .getSemantics(find.byType(ExomOperationBar))
          .getSemanticsData()
          .value,
      NumberFormat.percentPattern('es').format(0.25),
    );
    handle.dispose();
  });

  for (final (locale, label) in const [
    (Locale('es'), 'En curso'),
    (Locale('en'), 'In progress'),
  ]) {
    testWidgets('semantics: indeterminate is labelled «$label»', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        _padded(const ExomOperationBar()),
        locale: locale,
        disableAnimations: true,
      );
      final data = tester
          .getSemantics(find.byType(ExomOperationBar))
          .getSemanticsData();
      expect(data.label, label);
      expect(data.value, isEmpty);
      handle.dispose();
    });
  }

  testWidgets('semantics: determinate has no «en curso» label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _padded(const ExomOperationBar(value: 0.5)));
    expect(
      tester
          .getSemantics(find.byType(ExomOperationBar))
          .getSemanticsData()
          .label,
      isEmpty,
    );
    handle.dispose();
  });
}
