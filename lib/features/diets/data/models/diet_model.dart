class MealIngredientModel {
  final String name;
  final double quantity;
  final String unit;

  const MealIngredientModel({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory MealIngredientModel.fromJson(Map<String, dynamic> json) {
    // Backend returns MealIngredient JOIN row with nested ingredient object
    final ingredient = json['ingredient'] as Map<String, dynamic>?;
    return MealIngredientModel(
      name: ingredient?['name'] as String? ?? json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
    );
  }
}

class MealModel {
  final String id;
  final String type;
  final String name;
  final String? imageUrl;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final List<String> nutritionalBadges;
  final List<MealIngredientModel> ingredients;

  const MealModel({
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
  });

  factory MealModel.fromJson(Map<String, dynamic> json) {
    return MealModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      calories: json['calories'] as int?,
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      nutritionalBadges:
          (json['nutritional_badges'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => MealIngredientModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DietModel {
  final String id;
  final String name;
  final int? totalCalories;
  final double? totalProteinG;
  final double? totalCarbsG;
  final double? totalFatG;
  final List<MealModel> meals;

  const DietModel({
    required this.id,
    required this.name,
    this.totalCalories,
    this.totalProteinG,
    this.totalCarbsG,
    this.totalFatG,
    required this.meals,
  });

  factory DietModel.fromJson(Map<String, dynamic> json) {
    return DietModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      totalCalories: json['total_calories'] as int?,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble(),
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble(),
      totalFatG: (json['total_fat_g'] as num?)?.toDouble(),
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => MealModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
