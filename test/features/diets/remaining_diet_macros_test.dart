import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';

void main() {
  const variant = MealEntity(
    id: 'breakfast-variant',
    type: 'BREAKFAST',
    name: 'Variant',
    calories: 500,
    proteinG: 30,
    carbsG: 45,
    fatG: 20,
    nutritionalBadges: [],
    ingredients: [],
    variants: [],
  );
  const diet = DietEntity(
    id: 'diet',
    name: 'Diet',
    totalCalories: 2000,
    totalProteinG: 150,
    totalCarbsG: 220,
    totalFatG: 70,
    meals: [
      MealEntity(
        id: 'breakfast',
        type: 'BREAKFAST',
        name: 'Breakfast',
        calories: 350,
        proteinG: 20,
        carbsG: 40,
        fatG: 10,
        nutritionalBadges: [],
        ingredients: [],
        variants: [variant],
      ),
    ],
  );

  test('returns totals when no meal is completed', () {
    final remaining = diet.remainingMacros({});
    expect(remaining.calories, 2000);
    expect(remaining.proteinG, 150);
    expect(remaining.carbsG, 220);
    expect(remaining.fatG, 70);
  });

  test('subtracts exact completed variant', () {
    final remaining = diet.remainingMacros({'breakfast-variant'});
    expect(remaining.calories, 1500);
    expect(remaining.proteinG, 120);
    expect(remaining.carbsG, 175);
    expect(remaining.fatG, 50);
  });

  test('clamps inconsistent totals at zero', () {
    const smallDiet = DietEntity(
      id: 'small',
      name: 'Small',
      totalCalories: 100,
      totalProteinG: 10,
      totalCarbsG: 10,
      totalFatG: 10,
      meals: [variant],
    );
    final remaining = smallDiet.remainingMacros({'breakfast-variant'});
    expect(remaining.calories, 0);
    expect(remaining.proteinG, 0);
    expect(remaining.carbsG, 0);
    expect(remaining.fatG, 0);
  });
}
