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

  group('ExomMotion L5 patterns M1-M9 (contract T0.5, ESPEC §4)', () {
    const enter = Cubic(0.22, 0.75, 0.18, 1);
    const exit = Cubic(0.4, 0, 1, 1);

    test('constants', () {
      // M1 push and back.
      expect(ExomMotion.pushIn, const Duration(milliseconds: 240));
      expect(ExomMotion.pushOut, const Duration(milliseconds: 200));
      expect(ExomMotion.pushOffset, 24.0);
      expect(ExomMotion.pushPreviousOpacity, 0.6);
      // L5-D35: the push enters on easeOutCubic, not on the ESPEC curve.
      expect(ExomMotion.pushEnterCurve, Curves.easeOutCubic);
      expect(ExomMotion.pushExitCurve, exit);
      // M2 tabs.
      expect(ExomMotion.tabFadeOut, const Duration(milliseconds: 60));
      expect(ExomMotion.tabFadeIn, const Duration(milliseconds: 100));
      expect(ExomMotion.navIndicatorSlide, const Duration(milliseconds: 200));
      expect(ExomMotion.navIndicatorCurve, Curves.easeOut);
      // M3 arrival.
      expect(ExomMotion.arrivalFade, const Duration(milliseconds: 160));
      expect(ExomMotion.arrivalRise, 8.0);
      expect(ExomMotion.arrivalStagger, const Duration(milliseconds: 30));
      expect(ExomMotion.arrivalRiseRows, 6);
      expect(ExomMotion.arrivalCurve, enter);
      // M4 in place.
      expect(ExomMotion.inPlaceSwitch, const Duration(milliseconds: 160));
      expect(ExomMotion.selectionSlide, const Duration(milliseconds: 200));
      expect(ExomMotion.inPlaceCurve, Curves.easeOut);
      // M5 progress and figures.
      expect(ExomMotion.growBar, const Duration(milliseconds: 300));
      expect(ExomMotion.growBarCurve, Curves.easeOut);
      expect(ExomMotion.countUp, const Duration(milliseconds: 600));
      expect(ExomMotion.countUpCurve, Curves.easeOut);
      // M7 expand.
      expect(ExomMotion.expandHeight, const Duration(milliseconds: 200));
      expect(ExomMotion.expandCurve, Curves.easeOut);
      expect(ExomMotion.expandChevronTurns, 0.5);
      expect(ExomMotion.expandContentFade, const Duration(milliseconds: 120));
      // M9 form step.
      expect(ExomMotion.step, const Duration(milliseconds: 240));
      expect(ExomMotion.stepOffset, 24.0);
      expect(ExomMotion.stepCurve, enter);
      expect(ExomMotion.stepProgressRule, const Duration(milliseconds: 300));
      expect(ExomMotion.stepProgressRuleCurve, Curves.easeOut);
      // Rule: nothing but the milestone lasts more than 600 ms.
      expect(ExomMotion.ordinaryMax, const Duration(milliseconds: 600));
    });

    test('L5-D35 changes only the push entry: the sheet and the other '
        'entering patterns keep the ESPEC curve', () {
      expect(ExomMotion.sheetEnterCurve, enter);
      expect(ExomMotion.milestoneBandCurve, enter);
      expect(ExomMotion.arrivalCurve, enter);
      expect(ExomMotion.stepCurve, enter);
      expect(ExomMotionSpec.standard.sheetEnterCurve, enter);
      expect(ExomMotion.pushEnterCurve, isNot(ExomMotion.sheetEnterCurve));
      // The push durations, offset and dimming do not change.
      expect(ExomMotion.pushIn, const Duration(milliseconds: 240));
      expect(ExomMotion.pushOut, const Duration(milliseconds: 200));
      expect(ExomMotion.pushOffset, 24.0);
      expect(ExomMotion.pushPreviousOpacity, 0.6);
    });

    test('standard spec', () {
      const s = ExomMotionSpec.standard;
      expect(s.pushSlides, isTrue);
      expect(s.pushIn, const Duration(milliseconds: 240));
      expect(s.pushOut, const Duration(milliseconds: 200));
      expect(s.pushOffset, 24.0);
      expect(s.pushPreviousOpacity, 0.6);
      expect(s.tabFades, isTrue);
      expect(s.tabFadeIn, const Duration(milliseconds: 100));
      expect(s.tabFadeOut, const Duration(milliseconds: 60));
      expect(s.navIndicatorSlide, const Duration(milliseconds: 200));
      expect(s.arrivalFade, const Duration(milliseconds: 160));
      expect(s.arrivalRise, 8.0);
      expect(s.arrivalStagger, const Duration(milliseconds: 30));
      expect(s.inPlaceSwitch, const Duration(milliseconds: 160));
      expect(s.selectionSlides, isTrue);
      expect(s.selection, const Duration(milliseconds: 200));
      expect(s.growBar, const Duration(milliseconds: 300));
      expect(s.countUp, const Duration(milliseconds: 600));
      expect(s.expandAnimatesHeight, isTrue);
      expect(s.expandHeight, const Duration(milliseconds: 200));
      expect(s.expandChevron, const Duration(milliseconds: 200));
      expect(s.expandContentFade, const Duration(milliseconds: 120));
      expect(s.stepSlides, isTrue);
      expect(s.step, const Duration(milliseconds: 240));
      expect(s.stepOffset, 24.0);
      expect(s.stepProgressRule, const Duration(milliseconds: 300));
    });

    test('reduced spec: each pattern uses its reduced variant', () {
      const r = ExomMotionSpec.reduced;
      // M1: 100 ms fade, no offset, no dimming.
      expect(r.pushSlides, isFalse);
      expect(r.pushIn, const Duration(milliseconds: 100));
      expect(r.pushOut, const Duration(milliseconds: 100));
      expect(r.pushOffset, 0.0);
      expect(r.pushPreviousOpacity, 1.0);
      // M2: cut.
      expect(r.tabFades, isFalse);
      expect(r.tabFadeIn, Duration.zero);
      expect(r.tabFadeOut, Duration.zero);
      expect(r.navIndicatorSlide, Duration.zero);
      // M3: 120 ms fade, no rise.
      expect(r.arrivalFade, const Duration(milliseconds: 120));
      expect(r.arrivalRise, 0.0);
      expect(r.arrivalStagger, Duration.zero);
      // M4: 120 ms fade.
      expect(r.inPlaceSwitch, const Duration(milliseconds: 120));
      expect(r.selectionSlides, isFalse);
      expect(r.selection, const Duration(milliseconds: 120));
      // M5: final value directly.
      expect(r.growBar, Duration.zero);
      expect(r.countUp, Duration.zero);
      // M7: no animated height; fade.
      expect(r.expandAnimatesHeight, isFalse);
      expect(r.expandHeight, Duration.zero);
      expect(r.expandChevron, Duration.zero);
      expect(r.expandContentFade, const Duration(milliseconds: 120));
      // M9: 100 ms fade; the progress rule jumps to its value.
      expect(r.stepSlides, isFalse);
      expect(r.step, const Duration(milliseconds: 100));
      expect(r.stepOffset, 0.0);
      expect(r.stepProgressRule, Duration.zero);
    });

    test('nothing ordinary lasts more than 600 ms', () {
      for (final s in [ExomMotionSpec.standard, ExomMotionSpec.reduced]) {
        for (final d in [
          s.pushIn,
          s.pushOut,
          s.tabFadeIn,
          s.tabFadeOut,
          s.navIndicatorSlide,
          s.arrivalFade + s.arrivalStagger * (ExomMotion.arrivalRiseRows - 1),
          s.inPlaceSwitch,
          s.selection,
          s.growBar,
          s.countUp,
          s.expandHeight,
          s.expandChevron,
          s.expandContentFade,
          s.step,
          s.stepProgressRule,
        ]) {
          expect(d, lessThanOrEqualTo(ExomMotion.ordinaryMax));
        }
      }
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
