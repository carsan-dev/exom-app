// Shared scene of the L5-E7 «Nutrición» and «Detalle de comida» tests: a plan
// with four meals (one with options and badges, one done, one queued to sync),
// the real bloc over a fake repository, and the L2 component harness (real
// theme, bundled fonts, width / text scale / locale).
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/pages/diets_page.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart';

const sceneDate = '2026-11-18';

/// Fixed «now» of the scene (local time, so it does not depend on the time
/// zone). The date line of «Nutrición» shows a relative label against today
/// («Hace 3 días · …»), so the real clock made the goldens drift daily.
final sceneNow = DateTime(2026, 11, 21, 12);

MealEntity _meal(
  String id,
  String type,
  String name, {
  required int calories,
  required double protein,
  required double carbs,
  required double fat,
  List<String> badges = const [],
  List<MealEntity> variants = const [],
  List<MealIngredientEntity> ingredients = const [],
}) => MealEntity(
  id: id,
  type: type,
  name: name,
  calories: calories,
  proteinG: protein,
  carbsG: carbs,
  fatG: fat,
  nutritionalBadges: badges,
  ingredients: ingredients,
  variants: variants,
);

MealIngredientEntity _ingredient(String id, String name, double q, String u) =>
    MealIngredientEntity(id: id, name: name, quantity: q, unit: u);

/// Plan of the sketch «Nutrición»: 2150 kcal, four meals.
final sceneDiet = DietEntity(
  id: 'diet-1',
  name: 'Definición',
  totalCalories: 2150,
  totalProteinG: 160,
  totalCarbsG: 220,
  totalFatG: 70,
  meals: [
    _meal(
      'm-breakfast',
      'BREAKFAST',
      'Avena, yogur griego y fruta',
      calories: 520,
      protein: 27,
      carbs: 38,
      fat: 14,
    ),
    _meal(
      'm-lunch',
      'LUNCH',
      'Arroz, pollo y verduras',
      calories: 780,
      protein: 41,
      carbs: 70,
      fat: 37,
      badges: const ['Proteína', 'Fibra'],
      variants: [
        _meal(
          'm-lunch-b',
          'LUNCH',
          'Pasta, atún y tomate',
          calories: 740,
          protein: 38,
          carbs: 82,
          fat: 21,
        ),
      ],
      ingredients: [
        _ingredient('i-1', 'Arroz basmati', 80, 'g'),
        _ingredient('i-2', 'Pechuga de pollo', 150, 'g'),
        _ingredient('i-3', 'Verduras salteadas', 200, 'g'),
        _ingredient('i-4', 'Aceite de oliva', 10, 'ml'),
      ],
    ),
    _meal(
      'm-snack',
      'SNACK',
      'Tostada integral con pavo',
      calories: 300,
      protein: 18,
      carbs: 29,
      fat: 8,
    ),
    _meal(
      'm-dinner',
      'DINNER',
      'Merluza, patata y ensalada',
      calories: 550,
      protein: 57,
      carbs: 37,
      fat: 11,
    ),
  ],
);

class SceneDietRepository extends Fake implements DietRepository {
  SceneDietRepository({this.diet, this.completed = const {}});

  final DietEntity? diet;
  final Set<String> completed;
  final marked = <String>[];

  @override
  Future<DietEntity?> getTodayDiet({String? date}) async => diet;

  @override
  Future<Set<String>> getCompletedMealIds({String? date}) async => {
    ...completed,
  };

  @override
  Future<void> markMealCompleted(String mealId, String date) async {
    marked.add('$mealId@$date');
  }
}

class _SceneStorage extends LocalStorage {
  _SceneStorage(this.actions);

  final List<Map<String, dynamic>> actions;

  @override
  String? get sessionStamp => 'owner:1:test';

  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [...actions];
}

class _SceneSync extends OfflineSyncService {
  _SceneSync(LocalStorage storage) : super(ApiClient(useAuth: false), storage);

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

/// Queue action of a mark queued for [mealId] on [sceneDate].
Map<String, dynamic> sceneQueuedMark(String mealId) => {
  'id': 'op-$mealId',
  'type': 'mark_meal_completed',
  'meal_id': mealId,
  'date': sceneDate,
  'status': 'queued',
};

Future<SceneDietRepository> _register({
  required DietEntity? diet,
  required Set<String> completed,
  required List<Map<String, dynamic>> actions,
}) async {
  await sl.reset();
  final repository = SceneDietRepository(diet: diet, completed: completed);
  final storage = _SceneStorage(actions);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(_SceneSync(storage));
  sl.registerSingleton<DietRepository>(repository);
  sl.registerFactory<DietBloc>(
    () => DietBloc(
      getTodayDietUseCase: GetTodayDietUseCase(repository),
      getMealUseCase: GetMealUseCase(repository),
      markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
      unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
      getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
    ),
  );
  return repository;
}

/// The «Nutrición» screen. Default: breakfast done, lunch queued to sync.
Future<SceneDietRepository> pumpDietsScene(
  WidgetTester tester, {
  DietEntity? diet,
  bool noPlan = false,
  Set<String> completed = const {'m-breakfast', 'm-lunch'},
  List<Map<String, dynamic>>? actions,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
}) async {
  final repository = await _register(
    diet: noPlan ? null : (diet ?? sceneDiet),
    completed: completed,
    actions: actions ?? [sceneQueuedMark('m-lunch')],
  );
  addTearDown(sl.reset);
  await pumpComponent(
    tester,
    HomeClock(
      now: () => sceneNow,
      child: const DietsPage(selectedDate: sceneDate),
    ),
    brightness: brightness,
    width: width,
    height: height,
    textScale: textScale,
    locale: locale,
    disableAnimations: true,
  );
  await tester.pump(const Duration(milliseconds: 500));
  return repository;
}

/// The meal detail (the content of the bottom sheet) of the lunch, which has
/// options, badges and ingredients.
Future<SceneDietRepository> pumpMealSheetScene(
  WidgetTester tester, {
  DietEntity? diet,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
}) async {
  final repository = await _register(
    diet: diet ?? sceneDiet,
    completed: const {},
    actions: const [],
  );
  addTearDown(sl.reset);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await pumpComponent(
    tester,
    MealDetailSheet(
      mealId: 'm-lunch',
      selectedDate: sceneDate,
      scrollController: scroll,
    ),
    brightness: brightness,
    width: width,
    height: height,
    textScale: textScale,
    locale: locale,
    disableAnimations: true,
  );
  await tester.pump(const Duration(milliseconds: 500));
  return repository;
}
