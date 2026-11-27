// Redesign L2: the restyled shared widgets keep their API and paint V4 tokens.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/exom_panel.dart';
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

/// State widgets sit on the shared V4 raised panel (`ExomPanel`), not on a
/// bespoke rounded card.
void _expectRaisedPanel(WidgetTester tester, ExomThemePalette palette) {
  final panel = tester.widget<ExomPanel>(find.byType(ExomPanel));
  expect(panel.raised, isTrue);
  final decoration = _firstDecoration(tester, find.byType(ExomPanel));
  expect(decoration.color, palette.surfaceElevated);
  expect(decoration.borderRadius, isNull);
}

void main() {
  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;

    testWidgets(
      'static background is the flat theme background (${brightness.name})',
      (tester) async {
        await pumpComponent(
          tester,
          const ExomStaticBackground(child: Text('Estático')),
          brightness: brightness,
        );
        final boxes = tester.widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(ExomStaticBackground),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(boxes.map((b) => b.color).toSet(), {palette.background});
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
                  icon: const Icon(ExomIcons.profile),
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

    testWidgets('state widgets use theme tokens (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        ErrorWidget2(message: 'Algo falló', onRetry: () {}),
        brightness: brightness,
      );
      final icon = tester.widget<Icon>(find.byIcon(ExomIcons.error));
      expect(icon.color, palette.error);
      _expectRaisedPanel(tester, palette);
      await pumpComponent(
        tester,
        NoConnectionWidget(onRetry: () {}),
        brightness: brightness,
      );
      final wifi = tester.widget<Icon>(find.byIcon(ExomIcons.wifiOff));
      expect(
        wifi.color,
        themeFor(brightness).extension<ExomSemanticPalette>()!.warning,
      );
      _expectRaisedPanel(tester, palette);
      await pumpComponent(
        tester,
        const LoadingWidget(),
        brightness: brightness,
      );
      _expectRaisedPanel(tester, palette);
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
