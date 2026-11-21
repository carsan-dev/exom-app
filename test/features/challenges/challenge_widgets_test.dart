// Screen components of L5-B2 «Retos» (sketch b-cuenta.html «B4 · Retos",
// direccion.css): the milestone mark with bands at ±12° (`.x-mark`), the
// 50-mark rule of the main goal (`.x-ticks`) and the flat achievement tiles
// with the lock (`.x-tiles`).
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/challenges/presentation/widgets/achievement_tiles.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_icons.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_milestone_mark.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_tick_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../core/widgets/exom_component_harness.dart';
import '../../core/widgets/expect_no_lime_ink.dart';

const _tiles = [
  AchievementTileData(name: 'Primer entreno', unlocked: true),
  AchievementTileData(name: 'Racha de 7 días', unlocked: true),
  AchievementTileData(name: '50 sesiones', unlocked: false),
];

ExomThemePalette _palette(WidgetTester tester) =>
    tester.element(find.byType(Scaffold)).exomPalette;

void main() {
  group('ChallengeMilestoneMark (.x-mark)', () {
    for (final brightness in Brightness.values) {
      testWidgets('two bands at ±12° behind the numeral, ${brightness.name}', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const ChallengeMilestoneMark(value: '12', semanticsLabel: '12 días'),
          brightness: brightness,
        );
        final angles =
            tester
                .widgetList<Transform>(
                  find.descendant(
                    of: find.byType(ChallengeMilestoneMark),
                    matching: find.byType(Transform),
                  ),
                )
                .map(
                  (t) => math.atan2(
                    t.transform.entry(1, 0),
                    t.transform.entry(0, 0),
                  ),
                )
                .where((a) => a.abs() > 1e-6)
                .map((a) => (a * 180 / math.pi).round())
                .toList()
              ..sort();
        expect(angles, [-12, 12]);

        final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
        expect(numeral.value, '12');
        expect(numeral.size, ExomNumeralSize.hero140);
        // The milestone numeral is text coloured: the data colour is the goal's.
        expect(numeral.isData, isFalse);

        final front = tester.widget<DecoratedBox>(
          find.byKey(ChallengeMilestoneMark.frontBandKey),
        );
        final border = (front.decoration as BoxDecoration).border! as Border;
        expect(border.top.color, _palette(tester).data);
        expect(border.top.width, 2);
        expect(
          tester.getSemantics(find.byType(ChallengeMilestoneMark)).label,
          contains('12 días'),
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        expectNoOverflow(tester);
      });
    }
  });

  group('ChallengeTickRule (.x-ticks)', () {
    testWidgets('50 marks, floor(value × 50) filled in data', (tester) async {
      await pumpComponent(
        tester,
        const Padding(
          padding: EdgeInsets.all(20),
          child: ChallengeTickRule(value: 0.68, semanticsLabel: '34 / 50 km'),
        ),
        brightness: Brightness.light,
      );
      final on = find.byKey(ChallengeTickRule.onKey);
      final off = find.byKey(ChallengeTickRule.offKey);
      final major = find.byKey(ChallengeTickRule.majorKey);
      expect(on, findsNWidgets(34));
      expect(off.evaluate().length + major.evaluate().length, 16);
      final palette = _palette(tester);
      final rule = tester.getSize(find.byType(ChallengeTickRule));
      expect(rule.height, 32);
      expect(tester.getSize(on.first).height, 32);
      expect(tester.getSize(off.first).height, 16);
      // Every fifth mark that is not filled is taller and muted.
      expect(major, findsWidgets);
      expect(tester.getSize(major.first).height, closeTo(32 * 0.72, 0.01));
      expect((tester.widget<ColoredBox>(on.first)).color, palette.data);
      final semantics = tester.getSemantics(find.byType(ChallengeTickRule));
      expect(semantics.label, '34 / 50 km');
      expect(semantics.value, isNotEmpty);
      expectNoLimeInk(tester);
    });

    testWidgets('value is clamped', (tester) async {
      await pumpComponent(
        tester,
        const ChallengeTickRule(value: 1.7, semanticsLabel: 'x'),
      );
      expect(find.byKey(ChallengeTickRule.onKey), findsNWidgets(50));
    });
  });

  group('AchievementTiles (.x-tiles)', () {
    testWidgets('flat tiles: medal in data, lock and outline when locked', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const AchievementTiles(items: _tiles),
        brightness: Brightness.light,
      );
      final palette = _palette(tester);
      final medal = tester.widget<Icon>(
        find.byIcon(ChallengeIcons.achievement).first,
      );
      expect(medal.color, palette.data);
      final lock = tester.widget<Icon>(find.byIcon(ChallengeIcons.locked));
      expect(lock.color, palette.textSecondary);
      expect(find.byIcon(ChallengeIcons.locked), findsOneWidget);
      expect(find.byIcon(ChallengeIcons.achievement), findsNWidgets(2));
      // No rounded cards, no shadows: square tiles.
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(AchievementTiles),
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.borderRadius, isNull);
          expect(decoration.boxShadow, isNull);
        }
      }
      expectNoLimeInk(tester);
    });

    // Round 3 (orchestrator decision): the rule measures the content. Two
    // columns when the longest word of the names and descriptions fits the text
    // width of a two-column tile (same styles, same text scaler); one column
    // otherwise.
    Future<bool> twoColumns(
      WidgetTester tester, {
      required double width,
      required double scale,
      List<AchievementTileData> items = _tiles,
    }) async {
      await pumpComponent(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: AndroidNonlinearTextScaler(scale),
          ),
          child: SingleChildScrollView(child: AchievementTiles(items: items)),
        ),
        width: width,
      );
      expectNoOverflow(tester);
      final first = tester.getTopLeft(find.text(items[0].name));
      final second = tester.getTopLeft(find.text(items[1].name));
      return (second.dy - first.dy).abs() < 0.5;
    }

    testWidgets('two columns while the words fit', (tester) async {
      for (final width in const [320.0, 360.0, 390.0]) {
        for (final scale in const [1.0, 1.3]) {
          expect(
            await twoColumns(tester, width: width, scale: scale),
            isTrue,
            reason: '$width dp, ${scale}x',
          );
        }
      }
    });

    testWidgets('one column when the longest word does not fit in two', (
      tester,
    ) async {
      const long = [
        AchievementTileData(
          name: 'Primer entreno',
          description: 'Sobreentrenamientoextraordinario',
          unlocked: true,
        ),
        AchievementTileData(name: 'Racha de 7 días', unlocked: true),
      ];
      expect(
        await twoColumns(tester, width: 390, scale: 1.0, items: long),
        isFalse,
      );
      expect(await twoColumns(tester, width: 320, scale: 2.0), isFalse);
    });

    testWidgets('each tile is at least 56 high and reads its name', (
      tester,
    ) async {
      await pumpComponent(tester, const AchievementTiles(items: _tiles));
      for (final item in _tiles) {
        final tile = find.ancestor(
          of: find.text(item.name),
          matching: find.byKey(AchievementTiles.tileKey),
        );
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(56));
      }
    });
  });
}
