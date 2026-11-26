// L5-F5 «Cuenta atrás de inicio» (docs/plans/rediseno-app-l5-contrato-v2.md,
// sketch `f-resto.html`, frames f5-cuenta, f5-demo and f5-160): flat dialog of
// radius 4, the figure at 140 in the data colour with its unit «s», five
// segments (one per remaining second) that go off at once, a 180 ms fade per
// figure (cut with reduced motion) and a quiet «Cancelar» of at least 48 dp.
//
// Timing invariant (P-L5-ANIM-1): the countdown is driven by a wall-clock
// deadline and a Timer, never by an AnimationController, so Android's
// «Remove animations» (which scales normal controllers by 0.05) cannot
// shorten it. The timing test below runs the same scenario with and without
// `disableAnimations` in the platform accessibility features.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_start_countdown.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Wall clock shared by the countdown and the test: [advance] moves it and
/// pumps the same amount of fake time.
class CountdownClock {
  DateTime value = DateTime(2026, 11, 26, 9);
  DateTime call() => value;

  Future<void> advance(WidgetTester tester, Duration by) async {
    value = value.add(by);
    await tester.pump(by);
  }
}

/// Opens the countdown the way `execution_timer.dart` does (a non-dismissible
/// [DialogRoute] awaited until `completed`) over a plain page. Returns the
/// route; [onResult] receives the popped value once the route completed.
Future<DialogRoute<bool>> pumpStartCountdown(
  WidgetTester tester, {
  required CountdownClock clock,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 390,
  double height = 844,
  bool? disableAnimations,
  bool Function()? isValid,
  void Function(bool? result)? onResult,
  Locale locale = const Locale('es'),
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late DialogRoute<bool> route;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations ?? media.disableAnimations,
          ),
          child: app!,
        );
      },
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                route = DialogRoute<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ExecutionStartCountdown(
                    isValid: isValid ?? () => true,
                    now: clock.call,
                  ),
                );
                final result = await Navigator.of(context).push(route);
                await route.completed;
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  return route;
}

Finder _segments(String state) =>
    find.byKey(ValueKey('exom-rule-segment-$state'));

void main() {
  testWidgets('figure with its unit «s» in the data colour at 140 and five '
      'segments, one per remaining second', (tester) async {
    final clock = CountdownClock();
    await pumpStartCountdown(tester, clock: clock);
    await clock.advance(tester, const Duration(milliseconds: 300));

    final palette = AppTheme.dark.extension<ExomThemePalette>()!;
    expect(find.text('5'), findsOneWidget);
    final digit = tester.widget<Text>(find.text('5'));
    expect(digit.style?.fontSize, 140);
    expect(digit.style?.color, palette.data);
    expect(find.text('s'), findsOneWidget);
    expect(tester.widget<Text>(find.text('s')).style?.fontSize, 56);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final rule = tester.widget<ExomProgressRule>(find.byType(ExomProgressRule));
    expect(rule.segments, 5);
    expect(_segments('on'), findsNWidgets(5));
    expect(_segments('off'), findsNothing);

    // 2.5 s later three seconds remain: three segments stay lit; the two that
    // went off did so at once (no growth animation).
    await clock.advance(tester, const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('3'), findsOneWidget);
    expect(_segments('on'), findsNWidgets(3));
    expect(_segments('off'), findsNWidgets(2));
    expect(find.byKey(ExomProgressRule.growthKey), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flat dialog of radius 4 with a hairline and no shadow; quiet '
      '«Cancelar» of at least 48 dp and no lime action', (tester) async {
    final clock = CountdownClock();
    await pumpStartCountdown(
      tester,
      clock: clock,
      brightness: Brightness.light,
    );
    await clock.advance(tester, const Duration(milliseconds: 300));

    final palette = AppTheme.light.extension<ExomThemePalette>()!;
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(4));
    expect(shape.side.color, palette.borderSoft);
    expect(shape.side.width, 1);
    expect(dialog.elevation, 0);
    expect(dialog.backgroundColor, palette.surface);
    final shadows = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
    expect(shadows, isEmpty);

    // The title is the sketch's uppercase display title, read as written.
    expect(find.text('PREPÁRATE'), findsOneWidget);
    expect(find.bySemanticsLabel('Prepárate'), findsOneWidget);

    expect(find.byType(FilledButton), findsNothing);
    final cancel = find.widgetWithText(TextButton, 'Cancelar');
    expect(cancel, findsOneWidget);
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    final label = tester.widget<Text>(
      find.descendant(of: cancel, matching: find.text('Cancelar')),
    );
    final style = DefaultTextStyle.of(
      tester.element(find.text('Cancelar')),
    ).style.merge(label.style);
    expect(style.decoration, TextDecoration.underline);
    expect(style.color, palette.textPrimary);

    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byType(ExecutionStartCountdown), findsNothing);
  });

  testWidgets('each figure enters with a 180 ms fade; reduced motion cuts', (
    tester,
  ) async {
    final clock = CountdownClock();
    await pumpStartCountdown(tester, clock: clock);
    await clock.advance(tester, const Duration(milliseconds: 300));
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      const Duration(milliseconds: 180),
    );
    // Mid-fade after 4 -> the new figure is still partly transparent.
    await clock.advance(tester, const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('4'), findsOneWidget);
    final fading = tester.widget<FadeTransition>(
      find
          .ancestor(of: find.text('4'), matching: find.byType(FadeTransition))
          .first,
    );
    expect(fading.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpWidget(const SizedBox());

    final reducedClock = CountdownClock();
    await pumpStartCountdown(
      tester,
      clock: reducedClock,
      disableAnimations: true,
    );
    await reducedClock.advance(tester, const Duration(milliseconds: 300));
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
    await reducedClock.advance(tester, const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final removeAnimations in [false, true]) {
    testWidgets('fires exactly at the 5 s deadline '
        '(Android «Remove animations»: $removeAnimations)', (tester) async {
      if (removeAnimations) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final clock = CountdownClock();
      final opened = clock.value;
      var completed = false;
      bool? result;
      final route = await pumpStartCountdown(
        tester,
        clock: clock,
        onResult: (value) {
          completed = true;
          result = value;
        },
      );
      expect(
        tester
            .element(find.byType(ExecutionStartCountdown))
            .dependOnInheritedWidgetOfExactType<MediaQuery>()!
            .data
            .disableAnimations,
        removeAnimations,
      );
      // The countdown keeps running, second by second, until the deadline.
      for (var ms = 50; ms < 5000; ms += 50) {
        await clock.advance(tester, const Duration(milliseconds: 50));
        expect(route.isActive, isTrue, reason: 'closed early at $ms ms');
        expect(
          find.text('${((5000 - ms) / 1000).ceil()}'),
          findsOneWidget,
          reason: 'figure at $ms ms',
        );
      }
      expect(clock.value.difference(opened).inMilliseconds, 4950);
      expect(completed, isFalse);
      // The tick that reaches the deadline pops with «start».
      await clock.advance(tester, const Duration(milliseconds: 50));
      expect(route.isCurrent, isFalse);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isTrue);
      expect(find.byType(ExecutionStartCountdown), findsNothing);
    });
  }

  for (final locale in const [Locale('es'), Locale('en')]) {
    testWidgets('at 320 dp and 160 % the figure fits the phone and the dialog '
        'scrolls instead of overflowing (${locale.languageCode})', (
      tester,
    ) async {
      final clock = CountdownClock();
      final cancelLabel = locale.languageCode == 'es' ? 'Cancelar' : 'Cancel';
      await pumpStartCountdown(
        tester,
        clock: clock,
        width: 320,
        height: 640,
        textScale: 1.6,
        locale: locale,
      );
      await clock.advance(tester, const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final dialogRect = tester.getRect(find.byType(Dialog));
      expect(dialogRect.left, greaterThanOrEqualTo(0));
      expect(dialogRect.right, lessThanOrEqualTo(320));
      final digit = tester.getRect(find.text('5'));
      expect(digit.right, lessThanOrEqualTo(dialogRect.right));
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.widgetWithText(TextButton, cancelLabel)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
