import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';

class WeeklyShoppingListBuilder {
  const WeeklyShoppingListBuilder();

  List<ShoppingListItem> build({
    required DietPeriodEntity week,
    Iterable<WeeklyMealSelection> selections = const [],
    required String locale,
  }) {
    final selectedByKey = {
      for (final item in selections) item.key: item.selectedMealId,
    };
    final groups = <String, _IngredientGroup>{};

    for (final day in week.days) {
      for (final meal in day.diet?.meals ?? const <MealEntity>[]) {
        final selectedId =
            selectedByKey[WeeklyMealSelection.selectionKey(day.date, meal.id)];
        final selected =
            meal.variants.cast<MealEntity?>().firstWhere(
              (variant) => variant?.id == selectedId,
              orElse: () => meal,
            ) ??
            meal;
        for (final ingredient in selected.ingredients) {
          final key = ingredient.id.isNotEmpty
              ? 'id:${ingredient.id}'
              : 'name:${normalizeName(ingredient.name)}';
          final group = groups.putIfAbsent(
            key,
            () => _IngredientGroup(key, ingredient.name),
          );
          group.add(ingredient);
        }
      }
    }

    final items = groups.values.expand((group) => group.items()).toList();
    items.sort(
      (a, b) => normalizeName(a.name).compareTo(normalizeName(b.name)),
    );
    return items;
  }

  static String normalizeName(String value) {
    const accented = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const plain = 'aaaaaeeeeiiiiooooouuuunc';
    var normalized = value.trim().toLowerCase();
    for (var i = 0; i < accented.length; i++) {
      normalized = normalized.replaceAll(accented[i], plain[i]);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _IngredientGroup {
  final String key;
  final String name;
  final Map<String, _Amount> amounts = {};
  bool toTaste = false;

  _IngredientGroup(this.key, this.name);

  void add(MealIngredientEntity ingredient) {
    if (ingredient.unit == 'to_taste') {
      toTaste = true;
      return;
    }
    amounts.putIfAbsent(ingredient.unit, _Amount.new).add(ingredient);
  }

  Iterable<ShoppingListItem> items() {
    if (amounts.isEmpty) {
      return [
        ShoppingListItem(
          ingredientKey: key,
          name: name,
          quantity: null,
          unit: null,
          gramsEquivalent: null,
          toTaste: true,
        ),
      ];
    }
    final allConvertible =
        amounts.length > 1 &&
        amounts.values.every((amount) => amount.allHaveGrams);
    if (allConvertible) {
      return [
        ShoppingListItem(
          ingredientKey: key,
          name: name,
          quantity: amounts.values.fold<double>(
            0,
            (sum, amount) => sum + amount.grams,
          ),
          unit: 'g',
          gramsEquivalent: null,
          toTaste: toTaste,
        ),
      ];
    }
    var tastePending = toTaste;
    return amounts.entries.map((entry) {
      final amount = entry.value;
      final item = ShoppingListItem(
        ingredientKey: key,
        name: name,
        quantity: amount.quantity,
        unit: entry.key,
        gramsEquivalent: amount.allHaveGrams ? amount.grams : null,
        toTaste: tastePending,
      );
      tastePending = false;
      return item;
    });
  }
}

class _Amount {
  double quantity = 0;
  double grams = 0;
  bool allHaveGrams = true;

  void add(MealIngredientEntity ingredient) {
    quantity += ingredient.quantity;
    final equivalent = ingredient.gramsEquivalent;
    if (equivalent == null || equivalent <= 0) {
      allHaveGrams = false;
    } else {
      grams += equivalent;
    }
  }
}
