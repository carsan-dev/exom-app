// L5-B2 «Retos» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-B2; sketch
// b-cuenta.html «B4 · Retos»): copy (D15), the straight «all achievements»
// sheet (CC 11), the numbered weekly challenges with their percentage, the
// locked achievements, no lime ink in light (D13), large text with the Android
// nonlinear scaler (CC 3) and a sheet that follows a live theme change (the
// captured-colour defect fixed in E7).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../core/widgets/expect_no_lime_ink.dart';
import 'challenges_test_support.dart';

bool _anyTextEquals(WidgetTester tester, String text) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => (t.data ?? t.textSpan?.toPlainText() ?? '') == text);

bool _hasHeadline(WidgetTester tester, String first, String second) => tester
    .widgetList<ExomTwoLineHeadline>(find.byType(ExomTwoLineHeadline))
    .any((h) => h.first == first && h.second == second);

Finder _sheetText(String text) => find.descendant(
  of: find.byKey(const Key('exom-sheet-panel')),
  matching: findTextCi(text),
);

void main() {
  group('copy (D15)', () {
    testWidgets('es: no «Supera tus límites cada día», two new headlines', (
      tester,
    ) async {
      await pumpChallengesPage(tester, FakeChallengesRepository());
      expect(findTextCi('Supera tus límites cada día'), findsNothing);
      expect(_hasHeadline(tester, 'Días', 'seguidos.'), isTrue);
      expect(_hasHeadline(tester, 'Tu semana.', 'También cuenta.'), isTrue);
    });

    testWidgets('en: no «Push your limits every day», two new headlines', (
      tester,
    ) async {
      await pumpChallengesPage(
        tester,
        FakeChallengesRepository(),
        locale: const Locale('en'),
      );
      expect(findTextCi('Push your limits every day'), findsNothing);
      expect(_hasHeadline(tester, 'Days', 'in a row.'), isTrue);
      expect(_hasHeadline(tester, 'Your week.', 'It counts too.'), isTrue);
    });
  });

  group('all achievements sheet (CC 11)', () {
    testWidgets(
      'is a straight EXOM sheet with every achievement of the catalog',
      (tester) async {
        await pumpChallengesPage(tester, FakeChallengesRepository());
        await openAchievementsBoard(tester, 'Ver todos');

        final route = ModalRoute.of(tester.element(_sheetText('50 sesiones')));
        expect(route, isA<ExomSheetRoute<void>>());
        for (final achievement in kCatalog) {
          expect(_sheetText(achievement.name), findsOneWidget);
        }
        expect(_sheetText('Todos los logros'), findsOneWidget);
        // Same counter as today: unlocked of the catalog.
        expect(_anyTextEquals(tester, '3/5'), isTrue);
      },
    );

    testWidgets('«Cerrar» closes it', (tester) async {
      await pumpChallengesPage(tester, FakeChallengesRepository());
      await openAchievementsBoard(tester, 'Ver todos');
      final close = find.descendant(
        of: find.byKey(const Key('exom-sheet-actions')),
        matching: findTextCi('Cerrar'),
      );
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(findTextCi('50 sesiones'), findsNothing);
    });

    testWidgets('a router location change closes it', (tester) async {
      final router = await pumpChallengesPage(
        tester,
        FakeChallengesRepository(),
      );
      await openAchievementsBoard(tester, 'Ver todos');
      expect(findTextCi('50 sesiones'), findsOneWidget);

      router.go('/other');
      await tester.pumpAndSettle();
      expect(findTextCi('50 sesiones'), findsNothing);
      expect(find.text('Otra'), findsOneWidget);
    });

    testWidgets('locked achievements carry the lock, unlocked the medal', (
      tester,
    ) async {
      await pumpChallengesPage(tester, FakeChallengesRepository());
      await openAchievementsBoard(tester, 'Ver todos');
      final panel = find.byKey(const Key('exom-sheet-panel'));
      expect(
        find.descendant(
          of: panel,
          matching: find.byIcon(ChallengeIcons.locked),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: panel,
          matching: find.byIcon(ChallengeIcons.achievement),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('follows a theme change while open (captured colour)', (
      tester,
    ) async {
      final router = await pumpChallengesPage(
        tester,
        FakeChallengesRepository(),
      );
      await openAchievementsBoard(tester, 'Ver todos');
      final darkSurface = tester
          .element(findTextCi('50 sesiones'))
          .exomPalette
          .surface;

      await tester.pumpWidget(
        ChallengesHost(router: router, mode: ThemeMode.light),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final sheetText = findTextCi('50 sesiones');
      final lightSurface = tester.element(sheetText).exomPalette.surface;
      expect(lightSurface, isNot(darkSurface));
      final colors = find
          .ancestor(of: sheetText, matching: find.byType(Material))
          .evaluate()
          .map((e) => (e.widget as Material).color)
          .toSet();
      expect(colors, contains(lightSurface));
      expect(colors, isNot(contains(darkSurface)));
    });
  });

  group('weekly challenges', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets(
        'numbered 01-03 with the percentage, ${locale.languageCode}',
        (tester) async {
          await pumpChallengesPage(
            tester,
            FakeChallengesRepository(),
            locale: locale,
          );
          final numbers = tester
              .widgetList<ExomIndexNumber>(find.byType(ExomIndexNumber))
              .map((n) => n.n)
              .toList();
          expect(numbers, [1, 2, 3]);
          expect(_anyTextEquals(tester, '75%'), isTrue);
          expect(_anyTextEquals(tester, '71%'), isTrue);
          // One rule per weekly challenge (the main goal has the 50-mark rule).
          expect(find.byType(ExomProgressRule), findsNWidgets(kWeekly.length));
        },
      );
    }

    testWidgets('a completed challenge shows the check and «Completado»', (
      tester,
    ) async {
      await pumpChallengesPage(tester, FakeChallengesRepository());
      expect(find.byIcon(ChallengeIcons.done), findsOneWidget);
      expect(find.text('Completado'), findsOneWidget);
      expect(_anyTextEquals(tester, '100%'), isFalse);
    });
  });

  testWidgets('light: no lime ink on the page nor in the sheet (D13)', (
    tester,
  ) async {
    await pumpChallengesPage(
      tester,
      FakeChallengesRepository(),
      mode: ThemeMode.light,
    );
    expectNoLimeInk(tester);
    await openAchievementsBoard(tester, 'Ver todos');
    expectNoLimeInk(tester);
  });

  group('large text (CC 3, Android nonlinear scaler)', () {
    for (final width in const [360.0, 390.0]) {
      for (final scale in const [1.3, 1.6, 2.0]) {
        for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
          for (final locale in const [Locale('es'), Locale('en')]) {
            final name =
                '${width.toInt()} dp, $scale, ${mode.name}, '
                '${locale.languageCode}';
            testWidgets('no overflow nor broken words: $name', (tester) async {
              await pumpChallengesPage(
                tester,
                realisticRepository(locale),
                width: width,
                height: 6000,
                mode: mode,
                locale: locale,
                textScaler: AndroidNonlinearTextScaler(scale),
              );
              expect(tester.takeException(), isNull);
              expectNoBrokenWords(tester);

              await openAchievementsBoard(
                tester,
                locale.languageCode == 'es' ? 'Ver todos' : 'View all',
              );
              expect(tester.takeException(), isNull);
              expectNoBrokenWords(tester);
            });
          }
        }
      }
    }
  });
}
