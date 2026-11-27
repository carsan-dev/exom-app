// Skeleton tests. How screen tests deal with the pulse: with motion the
// skeleton repeats an opacity animation forever, so `pumpAndSettle` would time
// out while one is on screen. Screen tests either pump a fixed duration
// (`tester.pump(const Duration(milliseconds: 300))`) or run with
// `MediaQuery.disableAnimations` (reduced motion), where the skeleton is
// static and `pumpAndSettle` returns (both covered below).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Widget _all() => const Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    ExomSkeleton.numeral(),
    ExomSkeleton.headline(),
    ExomSkeleton.rule(),
    ExomSkeleton.row(),
  ],
);

Finder _fades() => find.descendant(
  of: find.byType(ExomSkeleton),
  matching: find.byType(FadeTransition),
);

void main() {
  registerTextComponentMatrix('ExomSkeleton', _all, checkContrast: false);

  testWidgets('shapes follow the sketch', (tester) async {
    await pumpComponent(tester, _all(), disableAnimations: true);
    expect(
      tester.getSize(find.byType(ExomSkeleton).at(0)).height,
      closeTo(76.8, 0.01),
    );
    expect(
      tester.getSize(find.byType(ExomSkeleton).at(1)).height,
      closeTo(54.4, 0.01),
    );
    expect(tester.getSize(find.byType(ExomSkeleton).at(2)).height, 4);
    expect(
      tester.getSize(find.byType(ExomSkeleton).at(3)).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('numeral is capped by a share of the container width', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(width: 100, child: ExomSkeleton.numeral()),
      ),
      disableAnimations: true,
    );
    expect(tester.getSize(find.byType(ExomSkeleton)).height, closeTo(24, 0.01));
  });

  testWidgets('blocks are painted in the raised surface colour', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        const ExomSkeleton.rule(),
        brightness: brightness,
        disableAnimations: true,
      );
      await tester.pumpAndSettle(); // the theme change animates (200 ms)
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ExomSkeleton),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, palette.surfaceElevated);
    }
  });

  testWidgets('excluded from semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _all());
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ExomSkeleton).first,
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('with motion: pulses and keeps scheduling frames', (
    tester,
  ) async {
    await pumpComponent(tester, const ExomSkeleton.rule());
    double opacity() => tester.widget<FadeTransition>(_fades()).opacity.value;
    final first = opacity();
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), isNot(first));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduced motion: static, no frames scheduled, '
      'pumpAndSettle returns', (tester) async {
    await pumpComponent(tester, _all(), disableAnimations: true);
    expect(_fades(), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final entry in {
    'numeral': const ExomSkeleton.numeral(),
    'headline': const ExomSkeleton.headline(),
    'rule': const ExomSkeleton.rule(),
    'row': const ExomSkeleton.row(),
  }.entries) {
    testWidgets('${entry.key} lays out with unbounded width', (tester) async {
      await pumpComponent(
        tester,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [entry.value]),
        ),
        disableAnimations: true,
      );
      expectNoOverflow(tester);
      final size = tester.getSize(find.byType(ExomSkeleton));
      expect(size.width.isFinite, isTrue);
      expect(size.width, greaterThan(0));
    });
  }

  testWidgets('switching to reduced motion stops the pulse', (tester) async {
    await pumpComponent(tester, const ExomSkeleton.rule());
    expect(tester.binding.hasScheduledFrame, isTrue);
    await pumpComponent(
      tester,
      const ExomSkeleton.rule(),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_fades(), findsNothing);
  });
}
