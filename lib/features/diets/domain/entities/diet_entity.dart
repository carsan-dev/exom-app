class MealIngredientEntity {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double? gramsEquivalent;
  final String? icon;

  const MealIngredientEntity({
    required this.id,
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

class RemainingDietMacros {
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  const RemainingDietMacros({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });
}

extension RemainingDietMacrosCalculation on DietEntity {
  RemainingDietMacros remainingMacros(Set<String> completedMealIds) {
    var caloriesConsumed = 0;
    var proteinConsumed = 0.0;
    var carbsConsumed = 0.0;
    var fatConsumed = 0.0;

    for (final meal in meals) {
      for (final option in [meal, ...meal.variants]) {
        if (completedMealIds.contains(option.id)) {
          caloriesConsumed += option.calories ?? 0;
          proteinConsumed += option.proteinG ?? 0;
          carbsConsumed += option.carbsG ?? 0;
          fatConsumed += option.fatG ?? 0;
          break;
        }
      }
    }

    return RemainingDietMacros(
      calories: totalCalories == null
          ? null
          : (totalCalories! - caloriesConsumed)
                .clamp(0, totalCalories!)
                .toInt(),
      proteinG: totalProteinG == null
          ? null
          : (totalProteinG! - proteinConsumed)
                .clamp(0, totalProteinG!)
                .toDouble(),
      carbsG: totalCarbsG == null
          ? null
          : (totalCarbsG! - carbsConsumed).clamp(0, totalCarbsG!).toDouble(),
      fatG: totalFatG == null
          ? null
          : (totalFatG! - fatConsumed).clamp(0, totalFatG!).toDouble(),
    );
  }
}
