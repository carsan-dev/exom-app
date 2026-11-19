// Macro chips of the meal detail use the decimal separator of the locale.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _date = '2026-11-18';

final _meal = MealEntity(
  id: 'm-1',
  type: 'LUNCH',
  name: 'Arroz con pollo',
  calories: 520,
  proteinG: 26.9,
  carbsG: 60.25,
  fatG: 12,
  nutritionalBadges: const [],
  ingredients: const [],
  variants: const [],
);

class _Repository extends Fake implements DietRepository {
  @override
  Future<DietEntity?> getTodayDiet({String? date}) async =>
      DietEntity(id: 'd', name: 'D', meals: [_meal]);

  @override
  Future<Set<String>> getCompletedMealIds({String? date}) async => {};
}

Future<void> _mount(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final repository = _Repository();
  sl.registerFactory<DietBloc>(
    () => DietBloc(
      getTodayDietUseCase: GetTodayDietUseCase(repository),
      getMealUseCase: GetMealUseCase(repository),
      markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
      unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
      getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
    ),
  );
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MealDetailSheet(
          mealId: 'm-1',
          selectedDate: _date,
          scrollController: scroll,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  tearDown(sl.reset);

  testWidgets('Spanish macros use the decimal comma', (tester) async {
    await _mount(tester, const Locale('es'));
    expect(find.text('P 26,9 g'), findsOneWidget);
    expect(find.text('C 60,25 g'), findsOneWidget);
    expect(find.text('G 12 g'), findsOneWidget);
    expect(find.textContaining('26.9'), findsNothing);
  });

  testWidgets('English macros keep the decimal point', (tester) async {
    await _mount(tester, const Locale('en'));
    expect(find.text('P 26.9 g'), findsOneWidget);
    expect(find.text('C 60.25 g'), findsOneWidget);
  });
}
