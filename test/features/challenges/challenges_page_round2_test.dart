// L5-B2 «Retos», round 2 (independent review): the description of every
// achievement in the sheet, accessibility guidelines (CC 4), 320 dp and 2.0x
// with a normal screen height (CC 3), pull-to-refresh, the two-column rule of
// the achievement tiles and the «locked» announcement.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/presentation/widgets/achievement_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import 'challenges_test_support.dart';

const AchievementEntity _longAchievement = AchievementEntity(
  id: 'a9',
  name: 'Constancia',
  description:
      'Completa cuarenta y dos entrenamientos distintos durante tres meses '
      'seguidos sin saltarte ninguna semana del plan asignado por tu '
      'entrenador para conseguir este logro.',
);

Finder _sheetText(String text) => find.descendant(
  of: find.byKey(const Key('exom-sheet-panel')),
  matching: findTextCi(text),
);

/// Distinct left edges of the tiles in [scope]: one per column.
int _columns(WidgetTester tester, {bool sheet = false}) {
  final tiles = sheet
      ? find.descendant(
          of: find.byKey(const Key('exom-sheet-panel')),
          matching: find.byKey(AchievementTiles.tileKey),
        )
      : find.byKey(AchievementTiles.tileKey);
  return {
    for (var i = 0; i < tiles.evaluate().length; i++)
      tester.getTopLeft(tiles.at(i)).dx.round(),
  }.length;
}

String _viewAll(Locale locale) =>
    locale.languageCode == 'es' ? 'Ver todos' : 'View all';

void main() {
  group('achievement description in the sheet', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets(
        'name and description, unlocked and locked, ${locale.languageCode}',
        (tester) async {
          await pumpChallengesPage(
            tester,
            FakeChallengesRepository(),
            locale: locale,
          );
          await openAchievementsBoard(tester, _viewAll(locale));
          for (final achievement in kCatalog) {
            expect(_sheetText(achievement.name), findsOneWidget);
            expect(
              _sheetText(achievement.description),
              findsOneWidget,
              reason: 'description of ${achievement.name}',
            );
          }
        },
      );
    }

    testWidgets('a long description is read whole, never truncated', (
      tester,
    ) async {
      await pumpChallengesPage(
        tester,
        FakeChallengesRepository(catalog: [...kUnlocked, _longAchievement]),
        height: 844,
        textScaler: const AndroidNonlinearTextScaler(1.3),
      );
      await openAchievementsBoard(tester, 'Ver todos');
      final text = tester.widget<Text>(
        _sheetText(_longAchievement.description),
      );
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });

  group('locked achievements are announced', () {
    for (final entry in const [
      (Locale('es'), 'Bloqueado'),
      (Locale('en'), 'Locked'),
    ]) {
      testWidgets('semantics ${entry.$2}, ${entry.$1.languageCode}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpChallengesPage(
          tester,
          FakeChallengesRepository(),
          locale: entry.$1,
        );
        await openAchievementsBoard(tester, _viewAll(entry.$1));
        // The two locked ones (50 sesiones, Racha de 30 días) say so.
        expect(find.bySemanticsLabel(RegExp(entry.$2)), findsNWidgets(2));
        expect(
          find.bySemanticsLabel(RegExp('${entry.$2}[\\s\\S]*50 sesiones')),
          findsOneWidget,
        );
        // An unlocked one does not.
        expect(
          find.bySemanticsLabel(RegExp('${entry.$2}[\\s\\S]*Primer entreno')),
          findsNothing,
        );
        semantics.dispose();
      });
    }
  });

  group('accessibility guidelines (CC 4)', () {
    // Tap targets and labels come from the framework guidelines. Contrast of
    // the sheet and of the tiles comes from `expectParagraphContrast`, which
    // reads the painted text by identity: `textContrastGuideline` works on
    // semantics nodes, so it cannot see text merged into a tile's node and it
    // also samples the page dimmed under the scrim.
    for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
      for (final locale in const [Locale('es'), Locale('en')]) {
        for (final sheet in const [false, true]) {
          testWidgets('${sheet ? 'open sheet' : 'page'}, ${mode.name}, '
              '${locale.languageCode}', (tester) async {
            final semantics = tester.ensureSemantics();
            await pumpChallengesPage(
              tester,
              realisticRepository(locale),
              height: 844,
              mode: mode,
              locale: locale,
            );
            if (sheet) {
              await openAchievementsBoard(tester, _viewAll(locale));
            }
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            if (!sheet) {
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }
            if (!sheet) {
              // The list builds lazily: lay the whole page out to read the
              // text of the tiles at its end.
              tester.view.physicalSize = const Size(390, 6000);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
            }
            final scope = sheet
                ? find.byKey(const Key('exom-sheet-panel'))
                : find.byType(Scaffold).first;
            expectParagraphContrast(
              tester,
              scope,
              fallback: tester.element(scope).exomPalette.surface,
            );
            semantics.dispose();
          });
        }
      }
    }
  });

  group('large text at 320 dp (CC 3)', () {
    for (final scale in const [1.3, 1.6]) {
      for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
        for (final locale in const [Locale('es'), Locale('en')]) {
          testWidgets(
            'no overflow nor broken words: 320 dp, $scale, ${mode.name}, '
            '${locale.languageCode}',
            (tester) async {
              await pumpChallengesPage(
                tester,
                realisticRepository(locale),
                width: 320,
                height: 6000,
                mode: mode,
                locale: locale,
                textScaler: AndroidNonlinearTextScaler(scale),
              );
              expect(tester.takeException(), isNull);
              expectNoBrokenWords(tester);
              await openAchievementsBoard(tester, _viewAll(locale));
              expect(tester.takeException(), isNull);
              expectNoBrokenWords(tester);
            },
          );
        }
      }
    }

    for (final width in const [320.0, 360.0]) {
      testWidgets(
        '2.0x on a normal screen scrolls to the end, ${width.toInt()} dp',
        (tester) async {
          await pumpChallengesPage(
            tester,
            realisticRepository(const Locale('es')),
            width: width,
            height: 780,
            textScaler: const AndroidNonlinearTextScaler(2.0),
          );
          final list = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(
            findTextCi('Ver todos'),
            400,
            scrollable: list,
          );
          await tester.drag(list, const Offset(0, -4000));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final position = tester.state<ScrollableState>(list).position;
          expect(position.pixels, position.maxScrollExtent);
          expectNoBrokenWords(tester);
        },
      );
    }
  });

  group('pull to refresh', () {
    testWidgets('reloads the challenges through the bloc', (tester) async {
      final repository = FakeChallengesRepository();
      await pumpChallengesPage(tester, repository, height: 844);
      expect(repository.loads, 1);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repository.loads, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('achievement tile columns (the rule measures the content)', () {
    Future<void> openAt(
      WidgetTester tester,
      FakeChallengesRepository repository, {
      required double width,
      required double scale,
      Locale locale = const Locale('es'),
    }) async {
      await pumpChallengesPage(
        tester,
        repository,
        width: width,
        height: 6000,
        locale: locale,
        textScaler: AndroidNonlinearTextScaler(scale),
      );
      expect(tester.takeException(), isNull);
    }

    testWidgets('two columns at 360 dp, 1.0x, with normal descriptions', (
      tester,
    ) async {
      for (final locale in const [Locale('es'), Locale('en')]) {
        await openAt(
          tester,
          realisticRepository(locale),
          width: 360,
          scale: 1.0,
          locale: locale,
        );
        expect(_columns(tester), 2, reason: locale.languageCode);
        await openAchievementsBoard(tester, _viewAll(locale));
        expect(_columns(tester, sheet: true), 2, reason: locale.languageCode);
      }
    });

    testWidgets('one column when the longest word does not fit in two', (
      tester,
    ) async {
      const longWord = AchievementEntity(
        id: 'a1',
        name: 'Constancia',
        description: 'Sobreentrenamientoextraordinario',
      );
      await openAt(
        tester,
        FakeChallengesRepository(
          achievements: const [longWord],
          catalog: const [longWord],
        ),
        width: 390,
        scale: 1.0,
      );
      expect(_columns(tester), 1);
      // The same width holds two columns with ordinary words.
      await openAt(
        tester,
        realisticRepository(const Locale('es')),
        width: 390,
        scale: 1.0,
      );
      expect(_columns(tester), 2);
    });

    testWidgets('«entrenamientos» at 1.3x and 2.0x does not fit two columns', (
      tester,
    ) async {
      for (final (width, scale) in const [
        (320.0, 1.3),
        (360.0, 1.3),
        (360.0, 2.0),
      ]) {
        await openAt(
          tester,
          realisticRepository(const Locale('es')),
          width: width,
          scale: scale,
        );
        // The page tiles carry only names, so only the sheet is measured with
        // the descriptions.
        await openAchievementsBoard(tester, 'Ver todos');
        expect(
          _columns(tester, sheet: true),
          1,
          reason: 'sheet $width dp, ${scale}x',
        );
      }
    });

    for (final width in const [300.0, 320.0, 360.0, 390.0]) {
      for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
        for (final locale in const [Locale('es'), Locale('en')]) {
          testWidgets('no broken words: ${width.toInt()} dp, ${scale}x, '
              '${locale.languageCode}', (tester) async {
            await openAt(
              tester,
              realisticRepository(locale),
              width: width,
              scale: scale,
              locale: locale,
            );
            expectNoBrokenWords(tester);
            await openAchievementsBoard(tester, _viewAll(locale));
            expect(tester.takeException(), isNull);
            expectNoBrokenWords(tester);
          });
        }
      }
    }
  });
}
