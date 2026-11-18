import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D8 (approved 2026-11-18): narrow screen and reduced motion are separate.
/// Motion follows only disableAnimations/accessibleNavigation; the width rule
/// (shortestSide <= 360) governs only the economy rendering measures.
typedef _Probe = ({
  bool reducedMotion,
  bool economy,
  bool reducedEffects,
  Duration duration,
  double blur,
  int imageWidth,
  double cacheExtent,
});

Future<_Probe> _probe(
  WidgetTester tester, {
  required Size size,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) async {
  late _Probe result;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 2,
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
      ),
      child: Builder(
        builder: (context) {
          result = (
            reducedMotion: PerformanceProfile.prefersReducedMotion(context),
            economy: PerformanceProfile.prefersEconomyRendering(context),
            reducedEffects: PerformanceProfile.prefersReducedEffects(context),
            duration: PerformanceProfile.animationDuration(
              context,
              const Duration(milliseconds: 240),
            ),
            blur: PerformanceProfile.blurSigma(context, 25),
            imageWidth: PerformanceProfile.imageCacheWidth(context, 600),
            cacheExtent: PerformanceProfile.scrollCacheExtent(context),
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  const wide = Size(390, 844);
  const narrow = Size(320, 640);

  testWidgets('wide + normal motion: full motion, full rendering', (
    tester,
  ) async {
    final p = await _probe(tester, size: wide);
    expect(p.reducedMotion, isFalse);
    expect(p.economy, isFalse);
    expect(p.reducedEffects, isFalse);
    expect(p.duration, const Duration(milliseconds: 240));
    expect(p.blur, 12);
    expect(p.imageWidth, 960);
    expect(p.cacheExtent, 640);
  });

  testWidgets('narrow + normal motion: animates, economy rendering', (
    tester,
  ) async {
    final p = await _probe(tester, size: narrow);
    expect(p.reducedMotion, isFalse);
    expect(p.economy, isTrue);
    // Legacy union getter keeps its documented meaning.
    expect(p.reducedEffects, isTrue);
    // D8: narrow phones now animate.
    expect(p.duration, const Duration(milliseconds: 240));
    expect(p.blur, 0);
    expect(p.imageWidth, 640);
    expect(p.cacheExtent, 320);
  });

  testWidgets('wide + reduced motion: no motion, full rendering', (
    tester,
  ) async {
    final p = await _probe(tester, size: wide, disableAnimations: true);
    expect(p.reducedMotion, isTrue);
    expect(p.economy, isFalse);
    expect(p.reducedEffects, isTrue);
    expect(p.duration, Duration.zero);
    expect(p.blur, 0);
    expect(p.imageWidth, 960);
    expect(p.cacheExtent, 640);
  });

  testWidgets('narrow + reduced motion: no motion, economy rendering', (
    tester,
  ) async {
    final p = await _probe(tester, size: narrow, disableAnimations: true);
    expect(p.reducedMotion, isTrue);
    expect(p.economy, isTrue);
    expect(p.reducedEffects, isTrue);
    expect(p.duration, Duration.zero);
    expect(p.blur, 0);
    expect(p.imageWidth, 640);
    expect(p.cacheExtent, 320);
  });

  testWidgets('accessibleNavigation counts as reduced motion', (tester) async {
    final p = await _probe(tester, size: wide, accessibleNavigation: true);
    expect(p.reducedMotion, isTrue);
    expect(p.economy, isFalse);
  });

  testWidgets('default 800x600 test view: full motion and rendering', (
    tester,
  ) async {
    late bool motion;
    late bool economy;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            motion = PerformanceProfile.prefersReducedMotion(context);
            economy = PerformanceProfile.prefersEconomyRendering(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(motion, isFalse);
    expect(economy, isFalse);
  });
}
