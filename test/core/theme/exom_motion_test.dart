import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExomMotion constants (plan §8)', () {
    test('press, sheet, chip, screen and milestone values', () {
      expect(ExomMotion.pressIn, const Duration(milliseconds: 80));
      expect(ExomMotion.pressOut, const Duration(milliseconds: 120));
      expect(ExomMotion.pressCurve, Curves.easeOut);
      expect(ExomMotion.pressScale, 0.97);
      expect(ExomMotion.sheetEnter, const Duration(milliseconds: 280));
      expect(ExomMotion.sheetEnterCurve, const Cubic(0.22, 0.75, 0.18, 1));
      expect(ExomMotion.scrim, const Duration(milliseconds: 200));
      expect(ExomMotion.scrimCurve, Curves.linear);
      expect(ExomMotion.sheetExit, const Duration(milliseconds: 200));
      expect(ExomMotion.sheetExitCurve, const Cubic(0.4, 0, 1, 1));
      expect(ExomMotion.chipCrossfade, const Duration(milliseconds: 160));
      expect(ExomMotion.screen, const Duration(milliseconds: 240));
      expect(ExomMotion.screenCurve, Curves.easeOut);
      expect(ExomMotion.milestoneBand, const Duration(milliseconds: 450));
      expect(
        ExomMotion.milestoneLetterStagger,
        const Duration(milliseconds: 40),
      );
      expect(ExomMotion.milestoneCount, const Duration(milliseconds: 600));
      expect(ExomMotion.milestoneMax, const Duration(milliseconds: 900));
      expect(ExomMotion.reducedFade, const Duration(milliseconds: 120));
      expect(ExomMotion.reducedScreen, const Duration(milliseconds: 100));
      expect(ExomMotion.reducedMilestone, const Duration(milliseconds: 150));
    });

    test('ordinary transitions are <= 300 ms (principle 9)', () {
      for (final spec in [ExomMotionSpec.standard, ExomMotionSpec.reduced]) {
        for (final d in [
          spec.pressIn,
          spec.pressOut,
          spec.sheetEnter,
          spec.sheetExit,
          spec.scrim,
          spec.chipCrossfade,
          spec.screen,
        ]) {
          expect(d, lessThanOrEqualTo(const Duration(milliseconds: 300)));
        }
      }
      expect(
        ExomMotionSpec.standard.milestoneTotal,
        lessThanOrEqualTo(const Duration(milliseconds: 900)),
      );
    });
  });

  group('ExomMotion.resolve', () {
    test('standard mode keeps scale and translate', () {
      final spec = ExomMotion.resolve(reduced: false);
      expect(spec.isReduced, isFalse);
      expect(spec.pressScale, 0.97);
      expect(spec.pressOpacity, 1.0);
      expect(spec.sheetSlides, isTrue);
      expect(spec.sheetEnter, const Duration(milliseconds: 280));
      expect(spec.sheetExit, const Duration(milliseconds: 200));
      expect(spec.sheetEnterCurve, ExomMotion.sheetEnterCurve);
      expect(spec.sheetExitCurve, ExomMotion.sheetExitCurve);
      expect(spec.chipCrossfade, const Duration(milliseconds: 160));
      expect(spec.screen, const Duration(milliseconds: 240));
      expect(spec.screenSlides, isTrue);
      expect(spec.milestoneBand, const Duration(milliseconds: 450));
      expect(spec.milestoneCount, const Duration(milliseconds: 600));
      expect(spec.milestoneTotal, const Duration(milliseconds: 900));
    });

    test(
      'reduced mode: no scale/translate, fades <= 120 ms, milestone 150',
      () {
        final spec = ExomMotion.resolve(reduced: true);
        expect(spec.isReduced, isTrue);
        expect(spec.pressScale, 1.0);
        expect(spec.pressOpacity, lessThan(1.0));
        expect(spec.sheetSlides, isFalse);
        expect(spec.screenSlides, isFalse);
        for (final d in [
          spec.pressIn,
          spec.pressOut,
          spec.sheetEnter,
          spec.sheetExit,
          spec.scrim,
          spec.chipCrossfade,
        ]) {
          expect(d, lessThanOrEqualTo(const Duration(milliseconds: 120)));
        }
        expect(spec.screen, const Duration(milliseconds: 100));
        expect(spec.milestoneBand, Duration.zero);
        expect(spec.milestoneCount, Duration.zero);
        expect(spec.milestoneTotal, const Duration(milliseconds: 150));
      },
    );
  });

  group('ExomMotion.of', () {
    Future<ExomMotionSpec> resolveWith(
      WidgetTester tester,
      MediaQueryData data,
    ) async {
      late ExomMotionSpec spec;
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: Builder(
            builder: (context) {
              spec = ExomMotion.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return spec;
    }

    testWidgets('disableAnimations resolves the reduced variant', (
      tester,
    ) async {
      final spec = await resolveWith(
        tester,
        const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      );
      expect(spec, same(ExomMotionSpec.reduced));
    });

    testWidgets('accessibleNavigation resolves the reduced variant', (
      tester,
    ) async {
      final spec = await resolveWith(
        tester,
        const MediaQueryData(size: Size(390, 844), accessibleNavigation: true),
      );
      expect(spec, same(ExomMotionSpec.reduced));
    });

    testWidgets('a narrow screen alone keeps full motion (D8)', (tester) async {
      final spec = await resolveWith(
        tester,
        const MediaQueryData(size: Size(320, 568)),
      );
      expect(spec, same(ExomMotionSpec.standard));
    });
  });
}
