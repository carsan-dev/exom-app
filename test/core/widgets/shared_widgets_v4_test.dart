// Redesign L2: the restyled shared widgets keep their API and paint V4 tokens.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

BoxDecoration _firstDecoration(WidgetTester tester, Finder of) {
  final widget = tester.widget(
    find
        .descendant(
          of: of,
          matching: find.byWidgetPredicate(
            (w) =>
                (w is DecoratedBox && w.decoration is BoxDecoration) ||
                (w is Container && w.decoration is BoxDecoration),
          ),
        )
        .first,
  );
  return (widget is DecoratedBox
          ? widget.decoration
          : (widget as Container).decoration)
      as BoxDecoration;
}

void main() {
  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;

    testWidgets(
      'backgrounds are the flat theme background (${brightness.name})',
      (tester) async {
        await pumpComponent(
          tester,
          const Column(
            children: [
              Expanded(child: ExomStaticBackground(child: Text('Estático'))),
              Expanded(child: ExomAnimatedBackground(child: Text('Animado'))),
            ],
          ),
          brightness: brightness,
        );
        final boxes = tester.widgetList<ColoredBox>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is ExomStaticBackground || w is ExomAnimatedBackground,
            ),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(boxes.map((b) => b.color).toSet(), {palette.background});
        expect(
          find.descendant(
            of: find.byType(ExomAnimatedBackground),
            matching: find.byType(CustomPaint),
          ),
          findsNothing,
        );
        // No animation is left running (the splash can settle).
        await tester.pumpAndSettle();
        expect(find.text('Animado'), findsOneWidget);
      },
    );

    testWidgets(
      'GlassAppBar is flat, opaque, rule at the bottom (${brightness.name})',
      (tester) async {
        await pumpComponent(
          tester,
          Scaffold(
            appBar: GlassAppBar(
              title: const Text('Detalle'),
              actions: [
                IconButton(
                  tooltip: 'Perfil',
                  onPressed: () {},
                  icon: const Icon(Icons.person_outline),
                ),
              ],
            ),
            body: const SizedBox.expand(),
          ),
          brightness: brightness,
          wrapInScaffold: false,
        );
        expect(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        final decoration = _firstDecoration(tester, find.byType(GlassAppBar));
        expect(decoration.color, palette.background);
        final border = decoration.border! as Border;
        expect(border.bottom.color, palette.borderSoft);
        expect(border.bottom.width, 1);
        expect(border.top, BorderSide.none);
        await expectTapTargetGuidelines(tester);
      },
    );

    testWidgets(
      'GlassCard: radius 0 by default, explicit radius kept (${brightness.name})',
      (tester) async {
        await pumpComponent(
          tester,
          const Column(
            children: [
              GlassCard(key: Key('default'), child: Text('Por defecto')),
              GlassCard(
                key: Key('explicit'),
                borderRadius: 16,
                padding: EdgeInsets.all(8),
                elevated: true,
                child: Text('Explícita'),
              ),
            ],
          ),
          brightness: brightness,
        );
        final byDefault = _firstDecoration(
          tester,
          find.byKey(const Key('default')),
        );
        expect(byDefault.color, palette.surface);
        expect(byDefault.borderRadius, BorderRadius.circular(0));
        expect((byDefault.border! as Border).top.color, palette.borderSoft);
        expect((byDefault.border! as Border).top.width, 1);
        expect(byDefault.boxShadow, isNull);
        final explicit = _firstDecoration(
          tester,
          find.byKey(const Key('explicit')),
        );
        expect(explicit.color, palette.surfaceElevated);
        expect(explicit.borderRadius, BorderRadius.circular(16));
        expect(
          find.descendant(
            of: find.byKey(const Key('explicit')),
            matching: find.byWidgetPredicate(
              (w) => w is Padding && w.padding == const EdgeInsets.all(8),
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('state widgets use theme tokens (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        ErrorWidget2(message: 'Algo falló', onRetry: () {}),
        brightness: brightness,
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, palette.error);
      await pumpComponent(
        tester,
        NoConnectionWidget(onRetry: () {}),
        brightness: brightness,
      );
      final wifi = tester.widget<Icon>(find.byIcon(Icons.wifi_off_outlined));
      expect(
        wifi.color,
        themeFor(brightness).extension<ExomSemanticPalette>()!.warning,
      );
    });
  }

  testWidgets('TappableScale: .97 at 80 ms on press, 120 ms on release', (
    tester,
  ) async {
    var taps = 0;
    await pumpComponent(
      tester,
      Center(
        child: TappableScale(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TappableScale)),
    );
    await tester.pump();
    var scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 0.97);
    expect(scale.duration, const Duration(milliseconds: 80));
    expect(scale.curve, Curves.easeOut);
    await gesture.up();
    await tester.pump();
    scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);
    expect(scale.duration, const Duration(milliseconds: 120));
    expect(taps, 1);
  });

  testWidgets('TappableScale: reduced motion has no scale', (tester) async {
    await pumpComponent(
      tester,
      Center(
        child: TappableScale(
          onTap: () {},
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
      disableAnimations: true,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TappableScale)),
    );
    await tester.pump();
    expect(find.byType(AnimatedScale), findsNothing);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      lessThan(1),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('TappableScale: narrow screen alone still scales (D8)', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      Center(
        child: TappableScale(
          onTap: () {},
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
      width: 320,
      height: 568,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TappableScale)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
