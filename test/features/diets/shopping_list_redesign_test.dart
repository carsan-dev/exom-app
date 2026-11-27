// L5-E8 «Lista de la compra», presentation criteria of the contract v2 (CC 3,
// CC 10 and CC 11): the bought mark is data (D19), both screens scroll to
// their end at 2.0x, the row reads as one checked/unchecked node, and the
// screens close when the router location changes, like the EXOM sheets.
import 'dart:ui' show CheckedState;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/diets/presentation/pages/shopping_list_pages.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'shopping_list_scene.dart';

Finder _row(String productId) => find.byKey(ShoppingListPage.itemKey(productId));

/// The 48 dp mark of a row: the only 48x48 decorated box with a border.
BoxDecoration _markOf(WidgetTester tester, String productId) {
  final box = tester
      .widgetList<Container>(
        find.descendant(of: _row(productId), matching: find.byType(Container)),
      )
      .firstWhere((c) => c.decoration is BoxDecoration);
  return box.decoration! as BoxDecoration;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  for (final brightness in Brightness.values) {
    testWidgets('D19: bought mark and check in data, the rest in text '
        '(${brightness.name})', (tester) async {
      await pumpShoppingListScene(tester, brightness: brightness);
      final palette = tester.element(find.byType(ShoppingListPage)).exomPalette;
      expect(
        Theme.of(tester.element(find.byType(ShoppingListPage))).brightness,
        brightness,
      );
      final checked = _markOf(tester, 'id:i-ric|g');
      expect((checked.border! as Border).top.color, palette.data);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: _row('id:i-ric|g'),
          matching: find.byIcon(ExomIcons.check),
        ),
      );
      expect(icon.color, palette.data);
      final unchecked = _markOf(tester, 'id:i-oil|ml');
      expect((unchecked.border! as Border).top.color, palette.textPrimary);
      expect(unchecked.color, isNull, reason: 'never a lime fill');
    });
  }

  testWidgets('row semantics: one node, checked state, tap toggles', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpShoppingListScene(tester);
    final rice = tester.getSemantics(_row('id:i-ric|g'));
    expect(rice.label, 'Arroz basmati, 160 g');
    expect(rice.flagsCollection.isChecked, CheckedState.isTrue);
    final oil = tester.getSemantics(_row('id:i-oil|ml'));
    expect(oil.flagsCollection.isChecked, CheckedState.isFalse);
    await tester.tap(_row('id:i-oil|ml'));
    await tester.pump();
    expect(
      tester.getSemantics(_row('id:i-oil|ml')).flagsCollection.isChecked,
      CheckedState.isTrue,
    );
    expect(tester.getSize(_row('id:i-oil|ml')).height, greaterThanOrEqualTo(56));
    handle.dispose();
  });

  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final setup in [true, false]) {
      final name = setup ? 'choice' : 'list';
      testWidgets('2.0x: the $name scrolls to its end (${locale.languageCode})',
          (tester) async {
        if (setup) {
          await pumpShoppingSetupScene(
            tester,
            textScale: 2.0,
            locale: locale,
            width: 320,
            height: 640,
          );
        } else {
          await pumpShoppingListScene(
            tester,
            textScale: 2.0,
            locale: locale,
            width: 320,
            height: 640,
          );
        }
        expect(tester.takeException(), isNull);
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        var steps = 0;
        while (position.pixels < position.maxScrollExtent) {
          await tester.drag(scrollable, const Offset(0, -250));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(++steps, lessThan(100));
        }
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ListView)),
        );
        // The last line of each screen is reachable.
        final last = setup
            ? find.text(l10n.shoppingListSetupNote)
            : find.text('Yogur griego');
        expect(tester.getRect(last).bottom, lessThanOrEqualTo(640));
      });
    }
  }

  testWidgets('CC 11: a router location change closes both screens', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => pushShoppingListRoute<void>(
                context,
                (_) => ShoppingListSetupPage(
                  period: shoppingWeek(),
                  calendarMonth: false,
                  mealTypes: const {},
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/avisos',
          builder: (_, _) => const Scaffold(body: Text('avisos')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('shopping-list-generate')));
    await tester.tap(find.byKey(const Key('shopping-list-generate')));
    await tester.pumpAndSettle();
    expect(find.byKey(ShoppingListPage.pageKey), findsOneWidget);
    router.go('/avisos');
    await tester.pumpAndSettle();
    expect(find.byKey(ShoppingListPage.pageKey), findsNothing);
    expect(find.byKey(ShoppingListSetupPage.pageKey), findsNothing);
    expect(find.text('avisos'), findsOneWidget);
  });

  group('r3: the headline says «Esta semana.» only for the current week', () {
    testWidgets('current week (es)', (tester) async {
      await pumpShoppingListScene(tester, today: DateTime(2026, 11, 18, 10));
      expect(find.text('ESTA SEMANA.'), findsOneWidget);
      expect(find.text('SEMANA DEL 16 NOV.'), findsNothing);
    });

    testWidgets('first and last instant of the week are current', (
      tester,
    ) async {
      await pumpShoppingListScene(tester, today: DateTime(2026, 11, 16));
      expect(find.text('ESTA SEMANA.'), findsOneWidget);
      await pumpShoppingListScene(
        tester,
        today: DateTime(2026, 11, 22, 23, 59, 59),
      );
      expect(find.text('ESTA SEMANA.'), findsOneWidget);
    });

    testWidgets('a later week names the start date (es)', (tester) async {
      await pumpShoppingListScene(tester, today: DateTime(2026, 11, 23));
      expect(find.text('ESTA SEMANA.'), findsNothing);
      expect(find.text('SEMANA DEL 16 NOV.'), findsOneWidget);
    });

    testWidgets('an earlier week names the start date (en)', (tester) async {
      await pumpShoppingListScene(
        tester,
        locale: const Locale('en'),
        today: DateTime(2026, 11, 15, 23, 59),
      );
      expect(find.text('THIS WEEK.'), findsNothing);
      expect(find.text('WEEK OF NOV 16.'), findsOneWidget);
    });
  });
}
