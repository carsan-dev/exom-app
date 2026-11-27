// L5-E8 «Lista de la compra» (docs/plans/rediseno-app-l5-contrato-v2.md, E8;
// sketch e-migradas.html frames f-compra and f-compra-lista): the
// configuration is a screen (not a sheet), «Generar lista» pushes the result
// screen with one mark per product, and the marks are kept on this device
// per owner and environment until the period or the chosen alternatives
// change (L5-D25, exception EX-Q4).
//
// Entered through `startWeeklyShoppingList`, the flow of the Dietas row. The
// preferences store is an in-memory LocalStorage (same `saveSetting` /
// `getSetting` contract as the Hive `settings_box`); the Hive-backed store is
// covered by shopping_list_checks_store_test.dart.
import 'dart:typed_data';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/presentation/widgets/weekly_shopping_list_flow.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

MealIngredientEntity _ingredient(String id, String name) =>
    MealIngredientEntity(id: id, name: name, quantity: 100, unit: 'g');

MealEntity _meal(
  String id,
  String name, {
  List<MealEntity> variants = const [],
  List<MealIngredientEntity> ingredients = const [],
}) => MealEntity(
  id: id,
  type: 'LUNCH',
  name: name,
  nutritionalBadges: const [],
  ingredients: ingredients,
  variants: variants,
);

/// Week of Monday [monday]: Wednesday's lunch (rice and chicken) with one
/// alternative (pasta).
WeeklyDietEntity _week(DateTime monday) => WeeklyDietEntity(
  weekStart: monday,
  weekEnd: monday.add(const Duration(days: 6)),
  days: [
    WeeklyDietDayEntity(
      date: monday.add(const Duration(days: 2)),
      diet: DietEntity(
        id: 'd',
        name: 'D',
        meals: [
          _meal(
            'a',
            'A',
            ingredients: [
              _ingredient('i-a', 'Arroz'),
              _ingredient('i-c', 'Pollo'),
            ],
            variants: [
              _meal('b', 'B', ingredients: [_ingredient('i-b', 'Pasta')]),
            ],
          ),
        ],
      ),
    ),
  ],
);

class _DietRepository extends Fake implements DietRepository {
  @override
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart) async =>
      _week(DateTime.parse(weekStart));
}

class _FakePdfService extends Fake implements WeeklyDietPdfService {
  final calls = <List<ShoppingListItem>>[];

  @override
  Future<Uint8List> buildShoppingList({
    required DietPeriodEntity week,
    required List<ShoppingListItem> items,
    required String locale,
    required WeeklyShoppingListPdfLabels labels,
  }) async {
    calls.add(items);
    return Uint8List(0);
  }
}

/// The preferences contract of [LocalStorage] in memory: `saveSetting` /
/// `getSetting` over a map, the session from [session].
class _MemoryStorage extends LocalStorage {
  _MemoryStorage(LocalAuthSession? Function() session, {super.environment})
    : super(currentSession: session);

  final values = <String, Object?>{};
  int writes = 0;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    writes++;
    values[key] = value;
  }

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;
}

LocalAuthSession? _session = const LocalAuthSession(uid: 'A', generation: 1);

Future<_FakePdfService> _mount(
  WidgetTester tester, {
  LocalStorage? storage,
  Locale locale = const Locale('es'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await sl.reset();
  final pdf = _FakePdfService();
  sl.registerSingleton<GetWeeklyDietUseCase>(
    GetWeeklyDietUseCase(_DietRepository()),
  );
  sl.registerSingleton<WeeklyDietPdfService>(pdf);
  if (storage != null) sl.registerSingleton<LocalStorage>(storage);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () =>
                    startWeeklyShoppingList(context, DateTime(2026, 11, 18)),
                child: const Text('dietas'),
              ),
              TextButton(
                onPressed: () =>
                    startWeeklyShoppingList(context, DateTime(2026, 11, 25)),
                child: const Text('otra semana'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return pdf;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _open(WidgetTester tester, {String entry = 'dietas'}) async {
  await tester.tap(find.text(entry));
  await _settle(tester);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).last));

final _setup = find.byKey(const Key('shopping-list-setup'));
final _result = find.byKey(const Key('shopping-list-result'));

Finder _item(String productId) =>
    find.byKey(ValueKey<String>('shopping-item:$productId'));

bool _isChecked(WidgetTester tester, String productId) => find
    .descendant(of: _item(productId), matching: find.byIcon(ExomIcons.check))
    .evaluate()
    .isNotEmpty;

Future<void> _generate(WidgetTester tester) async {
  final button = find.text(_l10n(tester).weeklyGenerateShoppingList.toUpperCase());
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester);
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _settle(tester);
}

Future<void> _toggle(WidgetTester tester, String productId) async {
  await tester.ensureVisible(_item(productId));
  await tester.tap(_item(productId));
  await tester.pump();
}

/// Opens the list of [entry] with the main option and returns on the result.
Future<void> _openList(WidgetTester tester, {String entry = 'dietas'}) async {
  await _open(tester, entry: entry);
  await _generate(tester);
  expect(_result, findsOneWidget);
}

/// Back from the result and from the configuration, to the origin.
Future<void> _leave(WidgetTester tester) async {
  await _back(tester);
  await _back(tester);
  expect(_setup, findsNothing);
  expect(_result, findsNothing);
}

const _rice = 'id:i-a|g';
const _chicken = 'id:i-c|g';
const _pasta = 'id:i-b|g';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  setUp(() => _session = const LocalAuthSession(uid: 'A', generation: 1));
  tearDown(sl.reset);

  group('D16: configuration as a screen', () {
    testWidgets('opens a pushed screen, not a sheet; back returns to origin', (
      tester,
    ) async {
      await _mount(tester);
      await _open(tester);
      expect(_setup, findsOneWidget);
      final route = ModalRoute.of(tester.element(_setup));
      expect(route, isA<PageRoute<dynamic>>());
      expect(route, isNot(isA<PopupRoute<dynamic>>()));
      // The «Volver» of the bar goes back to Dietas.
      await tester.tap(find.byIcon(ExomIcons.back));
      await _settle(tester);
      expect(_setup, findsNothing);
      expect(find.text('dietas'), findsOneWidget);
    });

    testWidgets('L4-I25b: each question carries weekday and date (es)', (
      tester,
    ) async {
      await _mount(tester);
      await _open(tester);
      expect(find.text('Miércoles 18 · Almuerzo'), findsOneWidget);
    });

    testWidgets('L4-I25b: each question carries weekday and date (en)', (
      tester,
    ) async {
      await _mount(tester, locale: const Locale('en'));
      await _open(tester);
      expect(find.text('Wednesday 18 · Lunch'), findsOneWidget);
    });
  });

  group('L5-D25: result screen with marks', () {
    testWidgets('«Generar lista» pushes the list; back returns to the choice', (
      tester,
    ) async {
      final pdf = await _mount(tester);
      await _open(tester);
      await _generate(tester);
      final l10n = _l10n(tester);
      expect(_result, findsOneWidget);
      expect(ModalRoute.of(tester.element(_result)), isA<PageRoute<dynamic>>());
      // The week of 16 November 2026 runs with the real clock here: «Esta
      // semana.» only while it is the current week, otherwise its start date
      // (r3; both cases are pinned with a fixed clock in
      // shopping_list_redesign_test.dart).
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final current =
          !today.isBefore(DateTime(2026, 11, 16)) &&
          !today.isAfter(DateTime(2026, 11, 22));
      final second = current
          ? l10n.shoppingListResultSecondWeek
          : l10n.shoppingListResultSecondWeekOf(
              DateFormat.MMMd('es').format(DateTime(2026, 11, 16)),
            );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ExomTwoLineHeadline &&
              w.first == l10n.shoppingListResultFirst &&
              w.second == second,
        ),
        findsOneWidget,
      );
      expect(_item(_rice), findsOneWidget);
      expect(_item(_chicken), findsOneWidget);
      expect(_item(_pasta), findsNothing);
      expect(find.text(l10n.shoppingListCheckedCount(0)), findsOneWidget);
      // No PDF until «Compartir lista».
      expect(pdf.calls, isEmpty);
      await _back(tester);
      expect(_result, findsNothing);
      expect(_setup, findsOneWidget);
    });

    testWidgets('«Compartir lista» builds the same PDF and offers print/share', (
      tester,
    ) async {
      final pdf = await _mount(tester);
      await _openList(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.text(l10n.shoppingListShare.toUpperCase()));
      await _settle(tester);
      expect(pdf.calls.single.map((i) => i.name), ['Arroz', 'Pollo']);
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
      expect(find.text(l10n.weeklyDietShare), findsOneWidget);
    });

    testWidgets('marking updates the count; the alternative changes items', (
      tester,
    ) async {
      await _mount(tester);
      await _openList(tester);
      final l10n = _l10n(tester);
      await _toggle(tester, _rice);
      expect(_isChecked(tester, _rice), isTrue);
      expect(find.text(l10n.shoppingListCheckedCount(1)), findsOneWidget);
      await _toggle(tester, _rice);
      expect(_isChecked(tester, _rice), isFalse);
      // Back to the choice, pick «B»: the list is the pasta.
      await _back(tester);
      await tester.tap(find.text('B'));
      await tester.pump();
      await _generate(tester);
      expect(_item(_pasta), findsOneWidget);
      expect(_item(_rice), findsNothing);
    });
  });

  group('L5-D25: marks kept on this device', () {
    testWidgets('two marks survive leaving and coming back', (tester) async {
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      await _toggle(tester, _rice);
      await _toggle(tester, _chicken);
      await _leave(tester);
      await _openList(tester);
      expect(_isChecked(tester, _rice), isTrue);
      expect(_isChecked(tester, _chicken), isTrue);
      expect(
        find.text(_l10n(tester).shoppingListCheckedCount(2)),
        findsOneWidget,
      );
    });

    testWidgets('another period starts without marks', (tester) async {
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      await _toggle(tester, _rice);
      await _leave(tester);
      await _openList(tester, entry: 'otra semana');
      expect(_isChecked(tester, _rice), isFalse);
    });

    testWidgets('other alternatives start without marks', (tester) async {
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      await _toggle(tester, _rice);
      await _leave(tester);
      // Same week, alternative «B» and back to the main: a new choice.
      await _open(tester);
      await tester.tap(find.text('B'));
      await tester.pump();
      await _generate(tester);
      await _toggle(tester, _pasta);
      await _leave(tester);
      await _openList(tester);
      expect(_isChecked(tester, _rice), isFalse);
    });

    testWidgets('user B sees none of A; A gets hers back', (tester) async {
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      await _toggle(tester, _rice);
      await _leave(tester);
      _session = const LocalAuthSession(uid: 'B', generation: 2);
      await _openList(tester);
      expect(_isChecked(tester, _rice), isFalse);
      await _toggle(tester, _chicken);
      await _leave(tester);
      _session = const LocalAuthSession(uid: 'A', generation: 3);
      await _openList(tester);
      expect(_isChecked(tester, _rice), isTrue);
      expect(_isChecked(tester, _chicken), isFalse);
    });

    testWidgets('another environment starts without marks', (tester) async {
      final values = <String, Object?>{};
      final first = _MemoryStorage(() => _session, environment: 'env-1');
      await _mount(tester, storage: first);
      await _openList(tester);
      await _toggle(tester, _rice);
      await _leave(tester);
      values.addAll(first.values);
      final second = _MemoryStorage(() => _session, environment: 'env-2')
        ..values.addAll(values);
      await _mount(tester, storage: second);
      await _openList(tester);
      expect(_isChecked(tester, _rice), isFalse);
    });

    testWidgets('session changed after opening: the mark is not written', (
      tester,
    ) async {
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      _session = const LocalAuthSession(uid: 'B', generation: 2);
      await _toggle(tester, _rice);
      await tester.pump();
      expect(storage.writes, 0);
      expect(storage.values, isEmpty);
    });

    testWidgets('signed out: nothing is read or written', (tester) async {
      _session = null;
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      await _toggle(tester, _rice);
      await tester.pump();
      expect(storage.writes, 0);
    });

    testWidgets('unknown format or unexpected shape: no marks, no exception', (
      tester,
    ) async {
      final storage = _MemoryStorage(() => _session);
      await _mount(tester, storage: storage);
      await _openList(tester);
      await _toggle(tester, _rice);
      await _leave(tester);
      final key = storage.values.keys.single;
      final valid = Map<String, Object?>.from(storage.values[key]! as Map);
      for (final broken in <Object?>[
        {...valid, 'format_version': 99},
        {...valid, 'checked': 'id:i-a|g'},
        {...valid, 'checked': [1, 2]},
        'not a map',
        [1, 2, 3],
      ]) {
        storage.values[key] = broken;
        await _openList(tester);
        expect(tester.takeException(), isNull, reason: '$broken');
        expect(_isChecked(tester, _rice), isFalse, reason: '$broken');
        await _leave(tester);
      }
    });
  });
}
