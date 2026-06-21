enum WeeklyDietExportFormat { menu, shoppingList }

class WeeklyMealSelection {
  final DateTime date;
  final String parentMealId;
  final String selectedMealId;

  const WeeklyMealSelection({
    required this.date,
    required this.parentMealId,
    required this.selectedMealId,
  });

  String get key => selectionKey(date, parentMealId);

  static String selectionKey(DateTime date, String parentMealId) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}|$parentMealId';
}

class ShoppingListItem {
  final String ingredientKey;
  final String name;
  final double? quantity;
  final String? unit;
  final double? gramsEquivalent;
  final bool toTaste;

  const ShoppingListItem({
    required this.ingredientKey,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.gramsEquivalent,
    required this.toTaste,
  });
}
