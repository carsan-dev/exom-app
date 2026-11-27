// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomProgressRule
// (`.x-rule`, `.x-rule-4`, `.x-segs`), the data-coloured progress rule.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Widget _padded(Widget child) => Padding(
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
  child: child,
);

void main() {
  registerTextComponentMatrix(
    'ExomProgressRule',
    () => const ExomProgressRule(value: 0.4),
  );
  registerTextComponentMatrix(
    'ExomProgressRule segments',
    () => const ExomProgressRule(value: 5 / 7, thickness: 4, segments: 7),
  );

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('continuous: track and data fill of the value '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _padded(const ExomProgressRule(value: 0.4)),
        brightness: brightness,
      );
      final rule = tester.getRect(find.byType(ExomProgressRule));
      expect(rule.height, 2);
      final fill = tester.getRect(find.byKey(ExomProgressRule.fillKey));
      expect(fill.width, closeTo(rule.width * 0.4, 0.01));
      expect(fill.height, 2);
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(ExomProgressRule.fillKey),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, palette.data);
      final track = tester.widget<ColoredBox>(
        find.byKey(ExomProgressRule.trackKey),
      );
      expect(track.color, palette.borderSoft);
    });

    testWidgets('segments: N segments, the done ones in data '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _padded(
          const ExomProgressRule(value: 5 / 7, thickness: 4, segments: 7),
        ),
        brightness: brightness,
      );
      final on = find.byKey(const ValueKey('exom-rule-segment-on'));
      final off = find.byKey(const ValueKey('exom-rule-segment-off'));
      expect(on, findsNWidgets(5));
      expect(off, findsNWidgets(2));
      for (final element in on.evaluate()) {
        final box = element.widget as DecoratedBox;
        expect((box.decoration as BoxDecoration).color, palette.data);
        expect(tester.getSize(find.byWidget(box)).height, 4);
      }
    });
  }

  testWidgets('thickness sets the height', (tester) async {
    await pumpComponent(
      tester,
      _padded(const ExomProgressRule(value: 0.5, thickness: 4)),
    );
    expect(tester.getSize(find.byType(ExomProgressRule)).height, 4);
  });

  testWidgets('value is clamped to 0..1', (tester) async {
    await pumpComponent(tester, _padded(const ExomProgressRule(value: 1.7)));
    final rule = tester.getRect(find.byType(ExomProgressRule));
    expect(
      tester.getRect(find.byKey(ExomProgressRule.fillKey)).width,
      closeTo(rule.width, 0.01),
    );
    await pumpComponent(tester, _padded(const ExomProgressRule(value: -1)));
    expect(tester.getRect(find.byKey(ExomProgressRule.fillKey)).width, 0);
  });

  testWidgets('semantics: a bar with its percentage value', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _padded(const ExomProgressRule(value: 0.78)));
    final expected = NumberFormat.percentPattern('es').format(0.78);
    final data = tester
        .getSemantics(find.byType(ExomProgressRule))
        .getSemanticsData();
    expect(data.value, expected);
    handle.dispose();
  });

  testWidgets('segments: lastSegmentGrowth paints the last filled segment '
      'only that share of its width, the value stays', (tester) async {
    await pumpComponent(
      tester,
      _padded(
        const ExomProgressRule(
          value: 0.5,
          thickness: 4,
          segments: 4,
          lastSegmentGrowth: 0.25,
        ),
      ),
    );
    final growing = find.byKey(ExomProgressRule.growthKey);
    expect(growing, findsOneWidget);
    expect(tester.widget<FractionallySizedBox>(growing).widthFactor, 0.25);
    // The complete segment is still on; the growing one counts as an outline
    // until it is done.
    expect(find.byKey(const ValueKey('exom-rule-segment-on')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('exom-rule-segment-off')),
      findsNWidgets(3),
    );
    final cell = tester.getRect(growing);
    final fill = tester.getRect(
      find.descendant(of: growing, matching: find.byType(ColoredBox)),
    );
    expect(fill.width, closeTo(cell.width * 0.25, 0.01));
    expect(fill.left, closeTo(cell.left, 0.01));
  });

  testWidgets('segments: lastSegmentGrowth 1 (default) is the plain rule', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      _padded(const ExomProgressRule(value: 0.5, thickness: 4, segments: 4)),
    );
    expect(find.byKey(ExomProgressRule.growthKey), findsNothing);
    expect(
      find.byKey(const ValueKey('exom-rule-segment-on')),
      findsNWidgets(2),
    );
  });
}
