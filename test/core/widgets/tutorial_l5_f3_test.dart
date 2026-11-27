// L5-F3 «Tutorial» (contract rediseno-app-l5-contrato-v2.md, f-resto.html
// frames f3-aviso, f3-paso-nav, f3-paso-hdr and f3-paso-menu). Written red
// before the repaint: the bubble shows «02 / 08» instead of eight dots, is a
// flat radius-4 panel with a data top bar, «Siguiente» is the only lime and
// «Listo» carries a check; the prompt is a flat radius-4 dialog with no icon.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/tutorial_overlay.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'expect_no_lime_ink.dart';

const _bubbleKey = Key('tutorial-bubble');
const _promptCardKey = Key('tutorial-prompt-card');

Finder _counter(String text) => find.text(text, findRichText: true);

Future<void> _pumpOverlay(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  bool disableAnimations = false,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  List<GlobalKey> drawerItemKeys = const [],
}) => pumpComponent(
  tester,
  TutorialOverlay(
    onNavigate: (_) {},
    onOpenDrawer: () {},
    onCloseDrawer: () {},
    onComplete: () {},
    drawerItemKeys: drawerItemKeys,
  ),
  brightness: brightness,
  disableAnimations: disableAnimations,
  width: width,
  height: height,
  textScale: textScale,
  locale: locale,
  wrapInScaffold: false,
);

Future<void> _advance(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byType(ExomPrimaryButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

void main() {
  group('bubble', () {
    testWidgets('numbering «01 / 08» … «08 / 08», no dots', (tester) async {
      await _pumpOverlay(tester);
      expect(_counter('01 / 08'), findsOneWidget);
      await _advance(tester, 1);
      expect(_counter('02 / 08'), findsOneWidget);
      expect(_counter('01 / 08'), findsNothing);
      await _advance(tester, 6);
      expect(_counter('08 / 08'), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('screen readers hear «Paso 2 de 8» / «Step 2 of 8»', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpOverlay(tester);
      await _advance(tester, 1);
      expect(find.bySemanticsLabel('Paso 2 de 8'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('English step label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpOverlay(tester, locale: const Locale('en'));
      expect(find.bySemanticsLabel('Step 1 of 8'), findsOneWidget);
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('flat radius-4 panel, 1 px rule, 3 px data top bar '
          '(${brightness.name})', (tester) async {
        await _pumpOverlay(tester, brightness: brightness);
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        final bubble = find.byKey(_bubbleKey);
        final clip = tester.widget<ClipRRect>(
          find.ancestor(of: bubble, matching: find.byType(ClipRRect)).first,
        );
        expect(clip.borderRadius, BorderRadius.circular(4));
        final decoration =
            tester.widget<DecoratedBox>(bubble).decoration as BoxDecoration;
        expect(decoration.boxShadow, anyOf(isNull, isEmpty));
        expect(decoration.color, palette.surface);
        final border = decoration.border! as Border;
        expect(border.top.color, palette.data);
        expect(border.top.width, 3);
        expect(border.left.color, palette.borderSoft);
        expect(border.left.width, 1);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
      });
    }

    testWidgets('«Siguiente» is the only lime, with an arrow; no icon circle', (
      tester,
    ) async {
      await _pumpOverlay(tester);
      expect(find.byType(ExomPrimaryButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      final button = tester.widget<ExomPrimaryButton>(
        find.byType(ExomPrimaryButton),
      );
      expect(button.trailingIcon, ExomIcons.forward);
      expect(find.byIcon(ExomIcons.home), findsNothing);
    });

    testWidgets('last step: «Listo» with a check', (tester) async {
      await _pumpOverlay(tester);
      await _advance(tester, 7);
      final button = tester.widget<ExomPrimaryButton>(
        find.byType(ExomPrimaryButton),
      );
      expect(button.label, 'Listo');
      expect(button.trailingIcon, ExomIcons.check);
    });

    testWidgets('description at 16', (tester) async {
      await _pumpOverlay(tester);
      final text = tester.widget<Text>(
        find.text(
          'Tu panel diario. Consulta el entreno, dieta y estadísticas del '
          'día de un vistazo.',
        ),
      );
      expect(text.style?.fontSize, 16);
    });

    testWidgets('reduced motion: the bubble swaps in a 120 ms fade', (
      tester,
    ) async {
      await _pumpOverlay(tester, disableAnimations: true);
      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(_counter('01 / 08'), findsNothing);
      expect(_counter('02 / 08'), findsOneWidget);
    });

    testWidgets('normal motion: the bubble swaps in a 160 ms fade', (
      tester,
    ) async {
      await _pumpOverlay(tester);
      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pump();
      // Past the reduced 120 ms, still inside 160 ms: the old step stays.
      await tester.pump(const Duration(milliseconds: 140));
      expect(_counter('01 / 08'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 30));
      expect(_counter('01 / 08'), findsNothing);
      expect(_counter('02 / 08'), findsOneWidget);
    });

    testWidgets('last step: bubble anchored under the Feedback row, inside '
        'the panel', (tester) async {
      final keys = List.generate(7, (_) => GlobalKey());
      // A stand-in drawer: 304 wide on the right, labels 60 dp apart.
      await pumpComponent(
        tester,
        Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 304,
              child: Column(
                children: [
                  const SizedBox(height: 150),
                  for (var i = 0; i < 7; i++)
                    SizedBox(
                      height: 60,
                      child: Center(child: Text('item $i', key: keys[i])),
                    ),
                ],
              ),
            ),
            TutorialOverlay(
              onNavigate: (_) {},
              onOpenDrawer: () {},
              onCloseDrawer: () {},
              onComplete: () {},
              drawerItemKeys: keys,
            ),
          ],
        ),
        wrapInScaffold: false,
      );
      await _advance(tester, 7);
      final bubble = tester.getRect(find.byKey(_bubbleKey));
      final target = tester.getRect(find.byKey(keys[3]));
      expect(bubble.left, greaterThanOrEqualTo(390 - 304));
      expect(bubble.right, lessThanOrEqualTo(390));
      expect(bubble.top, greaterThan(target.bottom));
      expect(bubble.bottom, lessThanOrEqualTo(844));
    });
  });

  group('long text', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, height) in const [(320.0, 640.0), (360.0, 800.0)]) {
        for (final scale in const [1.0, 1.6]) {
          testWidgets('every step fits on screen, ${locale.languageCode} '
              '${width.toInt()} dp x$scale', (tester) async {
            await _pumpOverlay(
              tester,
              locale: locale,
              width: width,
              height: height,
              textScale: scale,
            );
            for (var i = 0; i < 8; i++) {
              expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
              final bubble = tester.getRect(find.byKey(_bubbleKey));
              expect(bubble.top, greaterThanOrEqualTo(0));
              expect(bubble.bottom, lessThanOrEqualTo(height));
              expect(bubble.left, greaterThanOrEqualTo(0));
              expect(bubble.right, lessThanOrEqualTo(width));
              // The action stays reachable (the bubble scrolls if needed).
              await tester.ensureVisible(find.byType(ExomPrimaryButton));
              if (i < 7) await _advance(tester, 1);
            }
          });
        }
      }
    }

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('prompt with the checkbox at 320 dp x1.6 '
          '(${locale.languageCode})', (tester) async {
        await pumpComponent(
          tester,
          TutorialPromptDialog(
            redesigned: true,
            icon: null,
            onStart: () {},
            onSkip: () {},
            onDontShowAgainChanged: (_) {},
          ),
          width: 320,
          height: 640,
          textScale: 1.6,
          locale: locale,
          wrapInScaffold: false,
        );
        expectNoOverflow(tester);
        await tester.ensureVisible(find.byType(ExomQuietButton));
        expect(find.byType(Checkbox), findsOneWidget);
      });
    }
  });

  group('prompt', () {
    for (final brightness in Brightness.values) {
      testWidgets('flat radius-4 dialog without icon, title at 28 '
          '(${brightness.name})', (tester) async {
        await pumpComponent(
          tester,
          TutorialPromptDialog(
            redesigned: true,
            icon: null,
            onStart: () {},
            onSkip: () {},
          ),
          brightness: brightness,
          wrapInScaffold: false,
        );
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        expect(find.byIcon(ExomIcons.explore), findsNothing);
        final decoration = _decorationOf(tester, find.byKey(_promptCardKey));
        expect(decoration.borderRadius, BorderRadius.circular(4));
        expect(decoration.boxShadow, anyOf(isNull, isEmpty));
        expect(decoration.color, palette.surface);
        final border = decoration.border! as Border;
        expect(border.top.color, palette.borderSoft);
        expect(border.top.width, 1);
        final title = tester.widget<Text>(
          find.text('¿QUIERES UN RECORRIDO RÁPIDO?'),
        );
        expect(title.style?.fontSize, 28);
        expect(find.byType(ExomPrimaryButton), findsOneWidget);
        expect(find.byType(ExomQuietButton), findsOneWidget);
        expect(find.byType(ElevatedButton), findsNothing);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await expectTapTargetGuidelines(tester);
      });
    }

    testWidgets('screen readers keep the title in its original case', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        TutorialPromptDialog(
          redesigned: true,
          icon: null,
          onStart: () {},
          onSkip: () {},
        ),
        wrapInScaffold: false,
      );
      expect(
        find.bySemanticsLabel('¿Quieres un recorrido rápido?'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
