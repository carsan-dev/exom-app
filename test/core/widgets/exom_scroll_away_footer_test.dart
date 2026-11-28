// L5-D63: rules of the pinned footer that scrolls away with large text.
import 'package:exom_app/core/widgets/exom_scroll_away_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

FixedScrollMetrics _metrics(double pixels, {double max = 1000}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: max,
      pixels: pixels,
      viewportDimension: 500,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

void main() {
  late BuildContext context;
  late ExomScrollAwayFooterController controller;
  var pixels = 100.0;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    controller = ExomScrollAwayFooterController();
    addTearDown(controller.dispose);
    pixels = 100;
  }

  void user(ScrollDirection direction) => controller.handleScrollNotification(
    UserScrollNotification(
      metrics: _metrics(pixels),
      context: context,
      direction: direction,
    ),
  );

  void scroll(double delta, {double max = 1000}) {
    pixels += delta;
    controller.handleScrollNotification(
      ScrollUpdateNotification(
        metrics: _metrics(pixels, max: max),
        context: context,
        scrollDelta: delta,
      ),
    );
  }

  testWidgets('hides after 8 dp toward the end, shows when going back', (
    tester,
  ) async {
    await pumpHost(tester);
    user(ScrollDirection.reverse);
    scroll(3);
    scroll(4);
    expect(controller.value, isTrue);
    scroll(1);
    expect(controller.value, isFalse);
    user(ScrollDirection.idle);
    user(ScrollDirection.forward);
    expect(controller.value, isTrue);
  });

  testWidgets('a direction change restarts the 8 dp count', (tester) async {
    await pumpHost(tester);
    user(ScrollDirection.reverse);
    scroll(6);
    user(ScrollDirection.forward);
    scroll(-1);
    user(ScrollDirection.reverse);
    scroll(6);
    expect(controller.value, isTrue);
    scroll(2);
    expect(controller.value, isFalse);
  });

  testWidgets('programmatic scrolls never hide it', (tester) async {
    await pumpHost(tester);
    scroll(300);
    expect(controller.value, isTrue);
    user(ScrollDirection.reverse);
    user(ScrollDirection.idle);
    scroll(300);
    expect(controller.value, isTrue);
  });

  testWidgets('shows at the end of the content', (tester) async {
    await pumpHost(tester);
    user(ScrollDirection.reverse);
    scroll(100);
    expect(controller.value, isFalse);
    scroll(800);
    expect(pixels, 1000);
    expect(controller.value, isTrue);
  });

  testWidgets('shows when the content stops scrolling', (tester) async {
    await pumpHost(tester);
    user(ScrollDirection.reverse);
    scroll(100);
    expect(controller.value, isFalse);
    controller.handleMetricsNotification(
      ScrollMetricsNotification(metrics: _metrics(0, max: 0), context: context),
    );
    expect(controller.value, isTrue);
  });

  group('footer motion', () {
    Future<ExomScrollAwayFooterController> pumpFooter(
      WidgetTester tester, {
      bool disableAnimations = false,
    }) async {
      final visibility = ExomScrollAwayFooterController();
      addTearDown(visibility.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ExomScrollAwayFooter(
                controller: visibility,
                child: const SizedBox(height: 80, width: 200),
              ),
            ),
          ),
        ),
      );
      return visibility;
    }

    double opacity(WidgetTester tester) =>
        tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

    testWidgets('hides in 160 ms and shows in 200 ms', (tester) async {
      final visibility = await pumpFooter(tester);
      expect(opacity(tester), 1);
      visibility.handleScrollNotification(
        UserScrollNotification(
          metrics: _metrics(100),
          context: tester.element(find.byType(SizedBox)),
          direction: ScrollDirection.reverse,
        ),
      );
      visibility.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(120),
          context: tester.element(find.byType(SizedBox)),
          scrollDelta: 20,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(opacity(tester), 0);
      expect(
        tester.widget<IgnorePointer>(find.byType(IgnorePointer).first).ignoring,
        isTrue,
      );

      visibility.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 40));
      expect(opacity(tester), 1);
    });

    testWidgets('no animation when the platform disables them', (
      tester,
    ) async {
      final visibility = await pumpFooter(tester, disableAnimations: true);
      visibility.handleScrollNotification(
        UserScrollNotification(
          metrics: _metrics(100),
          context: tester.element(find.byType(SizedBox)),
          direction: ScrollDirection.reverse,
        ),
      );
      visibility.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(120),
          context: tester.element(find.byType(SizedBox)),
          scrollDelta: 20,
        ),
      );
      await tester.pump();
      expect(opacity(tester), 0);
      visibility.show();
      await tester.pump();
      expect(opacity(tester), 1);
    });
  });
}
