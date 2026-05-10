class MealIngredientEntity {
  final String name;
  final double quantity;
  final String unit;
  final double? gramsEquivalent;
  final String? icon;

  const MealIngredientEntity({
    required this.name,
    required this.quantity,
    required this.unit,
    this.gramsEquivalent,
    this.icon,
  });
}

class MealEntity {
  final String id;
  final String type;
  final String name;
  final String? imageUrl;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final List<String> nutritionalBadges;
  final List<MealIngredientEntity> ingredients;
  final List<MealEntity> variants;

  const MealEntity({
    required this.id,
    required this.type,
    required this.name,
    this.imageUrl,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.nutritionalBadges,
    required this.ingredients,
    required this.variants,
  });
}

class DietEntity {
  final String id;
  final String name;
  final int? totalCalories;
  final double? totalProteinG;
  final double? totalCarbsG;
  final double? totalFatG;
  final List<MealEntity> meals;

  const DietEntity({
    required this.id,
    required this.name,
    this.totalCalories,
    this.totalProteinG,
    this.totalCarbsG,
    this.totalFatG,
    required this.meals,
  });
}
