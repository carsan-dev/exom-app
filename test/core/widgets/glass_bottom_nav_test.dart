import 'dart:ui' show Tristate;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/glass_bottom_nav.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

const _labelsEs = ['Retos', 'Entrenar', 'Inicio', 'Dietas', 'Calendario'];
const _labelsEn = ['Challenges', 'Train', 'Home', 'Diets', 'Calendar'];
// Spoken names equal the visible labels (WCAG 2.5.3 label-in-name). They
// used to be «Entrenamientos»/«Trainings» while the bar was icon-only; now the
// labels are visible (D6), so the spoken name must contain the visible text.
const _a11yEs = _labelsEs;
const _a11yEn = _labelsEn;

Widget _nav({int selected = 2, ValueChanged<int>? onTap, bool? showLabels}) {
  final nav = showLabels == null
      ? GlassBottomNav(selectedIndex: selected, onTap: onTap ?? (_) {})
      : GlassBottomNav(
          selectedIndex: selected,
          onTap: onTap ?? (_) {},
          showLabels: showLabels,
        );
  return Scaffold(body: const SizedBox.expand(), bottomNavigationBar: nav);
}

void main() {
  testWidgets('the label-scale search is computed once per input set', (
    tester,
  ) async {
    const labels = ['Aa', 'Bbb', 'Cccc', 'Dd', 'Eeeee'];
    final before = GlassBottomNav.labelLayoutCount;
    TextScaler call(double width) => GlassBottomNav.labelTextScalerFor(
      system: const TextScaler.linear(1.3),
      slotWidth: width,
      labels: labels,
      textDirection: TextDirection.ltr,
    );
    final first = call(78);
    final afterFirst = GlassBottomNav.labelLayoutCount;
    expect(afterFirst, greaterThan(before));
    for (var i = 0; i < 20; i++) {
      expect(call(78), first);
    }
    expect(GlassBottomNav.labelLayoutCount, afterFirst, reason: 'cached');
    call(80);
    expect(
      GlassBottomNav.labelLayoutCount,
      greaterThan(afterFirst),
      reason: 'a new width recomputes',
    );
  });

  testWidgets('labels are shown by default (D6 approved)', (tester) async {
    await pumpComponent(tester, _nav(), wrapInScaffold: false);
    for (final label in _labelsEs) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('home tab glyph is the exom_balance symbol (L5-LOGO)', (
    tester,
  ) async {
    await pumpComponent(tester, _nav(), wrapInScaffold: false);
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = picture.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, 'assets/images/exom_balance.svg');
    expect(picture.fit, BoxFit.contain);
    expect(tester.getSize(find.byType(SvgPicture)), const Size(24, 24));
  });

  testWidgets('showLabels: false keeps the icon-only bar', (tester) async {
    await pumpComponent(tester, _nav(showLabels: false), wrapInScaffold: false);
    for (final label in _labelsEs) {
      expect(find.text(label), findsNothing);
    }
    expect(
      tester.getSize(find.byType(GlassBottomNav)).height,
      GlassBottomNav.totalHeight,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'flat bar, rule on top, no lime, no blur (${brightness.name})',
      (tester) async {
        await pumpComponent(
          tester,
          _nav(),
          brightness: brightness,
          wrapInScaffold: false,
        );
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        expect(
          find.descendant(
            of: find.byType(GlassBottomNav),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        final bar = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(GlassBottomNav),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = bar.decoration as BoxDecoration;
        expect(decoration.color, palette.surface);
        expect((decoration.border! as Border).top.color, palette.borderSoft);
        expect((decoration.border! as Border).top.width, 1);
        // Nothing in the bar is painted lime or with the accent.
        final colours = <Color?>[
          ...tester
              .widgetList<Icon>(
                find.descendant(
                  of: find.byType(GlassBottomNav),
                  matching: find.byType(Icon),
                ),
              )
              .map((i) => i.color),
          ...tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byType(GlassBottomNav),
                  matching: find.byType(Text),
                ),
              )
              .map((t) => t.style?.color),
          ...tester
              .widgetList<ColoredBox>(
                find.descendant(
                  of: find.byType(GlassBottomNav),
                  matching: find.byType(ColoredBox),
                ),
              )
              .map((b) => b.color),
        ];
        expect(colours, isNotEmpty);
        for (final colour in colours) {
          expect(colour, isNot(AppColors.primary));
          expect(colour, isNot(palette.primary));
        }
        // Active tab: text colour + weight 600; others muted.
        final active = tester.widget<Text>(find.text('Inicio'));
        expect(active.style?.color, palette.textPrimary);
        expect(active.style?.fontWeight, FontWeight.w600);
        final inactive = tester.widget<Text>(find.text('Retos'));
        expect(inactive.style?.color, palette.textSecondary);
        expect(inactive.style?.fontSize, 13);
        expect(inactive.style?.fontFamily, AppTheme.bodyFontFamily);
        await expectTapTargetGuidelines(tester);
      },
    );
  }

  testWidgets('tab order and callback; active bar above the selected tab', (
    tester,
  ) async {
    final taps = <int>[];
    await pumpComponent(
      tester,
      _nav(selected: 3, onTap: taps.add),
      wrapInScaffold: false,
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(_labelsEs[i]));
    }
    expect(taps, [0, 1, 2, 3, 4]);
    final indicator = find.descendant(
      of: find.byType(GlassBottomNav),
      matching: find.byType(ColoredBox),
    );
    expect(indicator, findsOneWidget);
    final indicatorRect = tester.getRect(indicator);
    final dietas = tester.getRect(find.text('Dietas'));
    expect(indicatorRect.height, 2);
    expect(indicatorRect.center.dx, closeTo(dietas.center.dx, 0.5));
    expect(indicatorRect.bottom, lessThan(dietas.top));
  });

  for (final locale in const [Locale('es'), Locale('en')]) {
    testWidgets('localized accessible labels (${locale.languageCode})', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        _nav(),
        locale: locale,
        wrapInScaffold: false,
      );
      final labels = locale.languageCode == 'es' ? _a11yEs : _a11yEn;
      for (final label in labels) {
        expect(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}\$')),
          findsOneWidget,
          reason: label,
        );
      }
      final home = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^${labels[2]}\$')),
      );
      expect(home.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });
  }

  for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final scale in const [1.0, 1.3, 1.6]) {
        testWidgets(
          '320 dp, ${platform.name}, ${locale.languageCode}, ${scale}x: '
          'single line, no overflow, no collisions',
          (tester) async {
            debugDefaultTargetPlatformOverride = platform;
            for (final selected in [0, 4]) {
              await pumpComponent(
                tester,
                _nav(selected: selected),
                width: 320,
                height: 640,
                textScale: scale,
                locale: locale,
                wrapInScaffold: false,
              );
              expectNoOverflow(tester);
              final labels = locale.languageCode == 'es'
                  ? _labelsEs
                  : _labelsEn;
              final rects = <Rect>[];
              for (final label in labels) {
                final finder = find.text(label);
                final text = tester.widget<Text>(finder);
                expect(text.maxLines, 1);
                // Rendered at 13 regardless of the system scale (capped).
                final paragraph = tester.renderObject<RenderParagraph>(finder);
                expect(paragraph.didExceedMaxLines, isFalse, reason: label);
                expect(
                  paragraph.textScaler.scale(13),
                  13,
                  reason: 'label scale is capped at 1.0',
                );
                final rect = tester.getRect(finder);
                // Visible margin at the screen edges (round 2).
                expect(rect.left, greaterThanOrEqualTo(4), reason: label);
                expect(rect.right, lessThanOrEqualTo(316), reason: label);
                rects.add(rect);
              }
              for (var i = 1; i < rects.length; i++) {
                expect(
                  rects[i].left - rects[i - 1].right,
                  greaterThanOrEqualTo(2),
                  reason: '${labels[i - 1]} / ${labels[i]} collide',
                );
              }
              // Every tab keeps a >= 48 x 48 target.
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
            }
            debugDefaultTargetPlatformOverride = null;
          },
        );
      }
    }
  }

  testWidgets('visible labels equal the spoken names (label-in-name)', (
    tester,
  ) async {
    for (final locale in const [Locale('es'), Locale('en')]) {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        _nav(),
        locale: locale,
        wrapInScaffold: false,
      );
      final labels = locale.languageCode == 'es' ? _labelsEs : _labelsEn;
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')),
          findsOneWidget,
          reason: 'spoken name starts with the visible «$label»',
        );
      }
      handle.dispose();
    }
  });

  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets(
        '390 dp, ${locale.languageCode}, ${scale}x: label scale up to 1.3, '
        'edge margin, no collisions',
        (tester) async {
          for (final selected in [0, 4]) {
            await pumpComponent(
              tester,
              _nav(selected: selected),
              width: 390,
              height: 640,
              textScale: scale,
              locale: locale,
              wrapInScaffold: false,
            );
            expectNoOverflow(tester);
            final labels = locale.languageCode == 'es' ? _labelsEs : _labelsEn;
            final rects = <Rect>[];
            for (final label in labels) {
              final finder = find.text(label);
              final paragraph = tester.renderObject<RenderParagraph>(finder);
              expect(paragraph.didExceedMaxLines, isFalse, reason: label);
              final rendered = paragraph.textScaler.scale(13);
              expect(rendered, greaterThanOrEqualTo(13));
              expect(rendered, lessThanOrEqualTo(13 * 1.3 + 0.001));
              if (scale > 1.0) {
                expect(rendered, greaterThan(13), reason: 'scales at 390 dp');
              }
              // The full label is painted, not ellipsized.
              expect(
                paragraph.getMinIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(paragraph.size.width + 0.5),
                reason: '$label is truncated',
              );
              final rect = tester.getRect(finder);
              expect(rect.left, greaterThanOrEqualTo(4), reason: label);
              expect(rect.right, lessThanOrEqualTo(386), reason: label);
              rects.add(rect);
            }
            for (var i = 1; i < rects.length; i++) {
              expect(
                rects[i].left - rects[i - 1].right,
                greaterThanOrEqualTo(2),
                reason: '${labels[i - 1]} / ${labels[i]} collide',
              );
            }
          }
        },
      );
    }
  }
}
