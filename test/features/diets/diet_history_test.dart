import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/presentation/widgets/diet_history_button.dart';
import 'package:exom_app/l10n/app_localizations.dart';

const ingredient = MealIngredientEntity(
  id: 'oats',
  name: 'Avena original',
  quantity: 2,
  unit: 'cup',
  gramsEquivalent: 80,
);
const variant = MealEntity(
  id: 'variant',
  type: 'BREAKFAST',
  name: 'Alternativa original',
  calories: 300,
  nutritionalBadges: [],
  ingredients: [],
  variants: [],
);
const meal = MealEntity(
  id: 'meal',
  type: 'BREAKFAST',
  name: 'Desayuno original',
  calories: 350,
  proteinG: 20,
  carbsG: 40,
  fatG: 10,
  nutritionalBadges: [],
  ingredients: [ingredient],
  variants: [variant],
);
const diet = DietEntity(
  id: 'diet',
  name: 'Dieta original',
  totalCalories: 700,
  meals: [meal],
);

// This fake deliberately throws on every unexpected repository operation.
class HistoryRepository extends Fake implements DietRepository {
  String? requestedDate;
  int catalogReads = 0;
  DietEntity? assigned = diet;

  @override
  Future<DietEntity?> getTodayDiet({String? date}) async {
    requestedDate = date;
    return assigned;
  }

  @override
  Future<MealEntity> getMeal(String mealId) async {
    catalogReads++;
    throw StateError('Mutable catalog must not be consulted');
  }
}

void main() {
  test(
    'date-specific detail and variants use frozen assignment, never live catalog',
    () async {
      final repository = HistoryRepository();
      final useCase = GetMealUseCase(repository);
      expect(await useCase('meal', date: '2000-01-03'), same(meal));
      expect(await useCase('variant', date: '2000-01-03'), same(variant));
      expect(repository.requestedDate, '2000-01-03');
      expect(repository.catalogReads, 0);
      repository.assigned = null;
      await expectLater(useCase('meal', date: '2000-01-03'), throwsStateError);
      expect(repository.catalogReads, 0);
    },
  );

  test(
    'history survives JSON cache round trip; unknown IDs and legacy stay explicit',
    () {
      final payload = <String, dynamic>{
        'meals_completed': ['meal', 'variant', 'lost'],
        'diet_history': [
          {
            'version': 1,
            'provenance': 'legacy_available',
            'diet': {
              'id': 'diet',
              'name': 'Dieta original',
              'meals': [
                {
                  'id': 'meal',
                  'name': 'Desayuno original',
                  'type': 'BREAKFAST',
                  'calories': 350,
                  'protein_g': 20,
                  'carbs_g': 40,
                  'fat_g': 10,
                  'ingredients': [
                    {
                      'ingredient': {'id': 'oats', 'name': 'Avena original'},
                      'quantity': 2,
                      'unit': 'cup',
                      'grams_equivalent': 80,
                    },
                  ],
                  'variants': [
                    {
                      'id': 'variant',
                      'name': 'Alternativa original',
                      'type': 'BREAKFAST',
                      'calories': 300,
                    },
                  ],
                },
              ],
            },
          },
        ],
      };
      final model = DietHistoryModel.fromProgress(
        jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
      );
      expect(model.entries.single.legacyAvailable, isTrue);
      final preserved = model.entries.single.diet.meals.single;
      expect(preserved.name, 'Desayuno original');
      expect(preserved.calories, 350);
      expect(preserved.ingredients.single.name, 'Avena original');
      expect(preserved.ingredients.single.quantity, 2);
      expect(preserved.ingredients.single.gramsEquivalent, 80);
      expect(preserved.variants.single.id, 'variant');
      expect(model.unresolvedMealIds, ['lost']);
      // Old payload without history remains parseable, not fabricated as a snapshot.
      expect(
        DietHistoryModel.fromProgress({
          'meals_completed': ['lost'],
        }).entries,
        isEmpty,
      );
      expect(
        () => DietHistoryEntryModel.fromJson({'version': 2}),
        throwsFormatException,
      );
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('read-only preserved details in ${brightness.name} theme', (
      tester,
    ) async {
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: DietHistoryButton(
              load: () async {
                reads++;
                return const DietHistory(
                  entries: [
                    DietHistoryEntry(diet: diet, legacyAvailable: true),
                  ],
                  unresolvedMealIds: ['lost'],
                );
              },
            ),
          ),
        ),
      );
      expect(reads, 0);
      await tester.tap(find.text('Histórico de dietas'));
      await tester.pumpAndSettle();
      expect(reads, 1);
      await tester.tap(find.text('Dieta original'));
      await tester.pumpAndSettle();
      expect(find.text('Desayuno original'), findsOneWidget);
      expect(find.textContaining('Avena original'), findsOneWidget);
      expect(
        find.textContaining('puede no reflejar ediciones anteriores'),
        findsOneWidget,
      );
      expect(find.text('lost'), findsOneWidget);
      expect(find.textContaining('Solo lectura'), findsOneWidget);
      expect(find.text('Completar'), findsNothing);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
