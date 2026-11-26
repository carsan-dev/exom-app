// Shared scene of the L5-E8 «Lista de la compra» goldens and overflow tests
// (docs/plans/rediseno-app-l5-contrato-v2.md, E8; sketch e-migradas.html,
// frames f-compra and f-compra-lista): the week of 16-22 November 2026 with
// three meals that have an alternative and a breakfast every day; the list
// with the main options and two products marked. Not a test file: no `main`.
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/presentation/pages/shopping_list_pages.dart';
import 'package:exom_app/features/diets/services/shopping_list_checks_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/widgets/exom_component_harness.dart';

MealIngredientEntity _ing(String id, String name, double qty, String unit) =>
    MealIngredientEntity(id: id, name: name, quantity: qty, unit: unit);

MealEntity _meal(
  String id,
  String type,
  String name,
  List<MealIngredientEntity> ingredients, {
  List<MealEntity> variants = const [],
}) => MealEntity(
  id: id,
  type: type,
  name: name,
  nutritionalBadges: const [],
  ingredients: ingredients,
  variants: variants,
);

MealEntity _breakfast(int day) => _meal('b$day', 'BREAKFAST', 'Avena', [
  _ing('i-oat', 'Avena', 40, 'g'),
  _ing('i-yog', 'Yogur griego', 200, 'g'),
  _ing('i-fru', 'Fruta', 1, 'piece'),
]);

MealEntity _lunch(int day) => _meal(
  'l$day',
  'LUNCH',
  'Arroz, pollo y verduras',
  [
    _ing('i-ric', 'Arroz basmati', 80, 'g'),
    _ing('i-chk', 'Pechuga de pollo', 150, 'g'),
    _ing('i-veg', 'Verduras salteadas', 200, 'g'),
    _ing('i-oil', 'Aceite de oliva', 10, 'ml'),
  ],
  variants: [
    _meal('l$day-v', 'LUNCH', 'Pasta, atún y tomate', [
      _ing('i-pas', 'Pasta', 90, 'g'),
      _ing('i-tun', 'Atún', 80, 'g'),
    ]),
  ],
);

MealEntity _dinner(int day) => _meal(
  'd$day',
  'DINNER',
  'Salmón, quinoa y brócoli',
  [
    _ing('i-sal', 'Salmón', 150, 'g'),
    _ing('i-qui', 'Quinoa', 70, 'g'),
    _ing('i-bro', 'Brócoli', 120, 'g'),
  ],
  variants: [
    _meal('d$day-v', 'DINNER', 'Salmón con quinoa', [
      _ing('i-sal', 'Salmón', 150, 'g'),
      _ing('i-qui', 'Quinoa', 70, 'g'),
    ]),
  ],
);

/// The week of the sketch: lunch with an alternative on Monday and
/// Wednesday, dinner with an alternative on Friday, breakfast every day.
DietPeriodEntity shoppingWeek() => DietPeriodEntity(
  start: DateTime(2026, 11, 16),
  end: DateTime(2026, 11, 22),
  days: [
    for (var day = 16; day <= 22; day++)
      DietPeriodDayEntity(
        date: DateTime(2026, 11, day),
        diet: DietEntity(
          id: 'diet-$day',
          name: 'Definición',
          meals: [
            _breakfast(day),
            if (day == 16 || day == 18) _lunch(day),
            if (day == 20) _dinner(day),
          ],
        ),
      ),
  ],
);

/// Main option of every meal with an alternative.
List<WeeklyMealSelection> mainSelections(DietPeriodEntity period) => [
  for (final day in period.days)
    for (final meal in day.diet?.meals ?? const <MealEntity>[])
      if (meal.variants.isNotEmpty)
        WeeklyMealSelection(
          date: day.date,
          parentMealId: meal.id,
          selectedMealId: meal.id,
        ),
];

const Map<String, String> _mealTypesEs = {
  'BREAKFAST': 'Desayuno',
  'LUNCH': 'Almuerzo',
  'SNACK': 'Merienda',
  'DINNER': 'Cena',
};

const Map<String, String> _mealTypesEn = {
  'BREAKFAST': 'Breakfast',
  'LUNCH': 'Lunch',
  'SNACK': 'Snack',
  'DINNER': 'Dinner',
};

/// Preferences in memory, signed in as «A».
class _SceneStorage extends LocalStorage {
  _SceneStorage()
    : super(currentSession: () => const LocalAuthSession(uid: 'A'));

  final _values = <String, Object?>{};

  @override
  Future<void> saveSetting(String key, dynamic value) async =>
      _values[key] = value;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] as T?) ?? defaultValue;
}

/// «Elige tus alternativas» (f-compra).
Future<void> pumpShoppingSetupScene(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  double width = 390,
  double height = 844,
}) async {
  await initializeDateFormatting(locale.languageCode);
  await pumpComponent(
    tester,
    ShoppingListSetupPage(
      period: shoppingWeek(),
      calendarMonth: false,
      mealTypes: locale.languageCode == 'en' ? _mealTypesEn : _mealTypesEs,
    ),
    brightness: brightness,
    textScale: textScale,
    textScaler: textScaler,
    locale: locale,
    width: width,
    height: height,
    disableAnimations: true,
    wrapInScaffold: false,
  );
  await tester.pumpAndSettle();
}

/// «Tu lista. / Esta semana.» (f-compra-lista) with rice and chicken marked.
Future<void> pumpShoppingListScene(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  double width = 390,
  double height = 844,
  DateTime? today,
}) async {
  await initializeDateFormatting(locale.languageCode);
  final period = shoppingWeek();
  // Wednesday 18 of the scene week, so the headline is «Esta semana.».
  final now = today ?? DateTime(2026, 11, 18, 10);
  final selections = mainSelections(period);
  final store = ShoppingListChecksStore(_SceneStorage());
  await store.write(
    store.currentOwner()!,
    ShoppingListScope(
      periodStart: period.start,
      kind: ShoppingListPeriodKind.week,
      selectionSignature: ShoppingListChecksStore.selectionSignature(
        selections,
      ),
    ),
    {'id:i-ric|g', 'id:i-chk|g'},
  );
  await pumpComponent(
    tester,
    ShoppingListPage(
      period: period,
      calendarMonth: false,
      selections: selections,
      store: store,
      now: () => now,
    ),
    brightness: brightness,
    textScale: textScale,
    textScaler: textScaler,
    locale: locale,
    width: width,
    height: height,
    disableAnimations: true,
    wrapInScaffold: false,
  );
  await tester.pumpAndSettle();
}
