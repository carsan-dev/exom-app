// The meal detail sheet must follow the live theme while it is open.
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
import 'package:go_router/go_router.dart';

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

class _Host extends StatelessWidget {
  const _Host({required this.mode, required this.router});

  final ThemeMode mode;
  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  tearDown(sl.reset);

  testWidgets('sheet background follows a theme change while open', (
    tester,
  ) async {
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
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showMealDetailSheet(context, mealId: 'm-1'),
              child: const Text('open'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_Host(mode: ThemeMode.light, router: router));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Set<Color?> sheetColors() => find
        .ancestor(
          of: find.byType(MealDetailSheet),
          matching: find.byType(Material),
        )
        .evaluate()
        .map((e) => (e.widget as Material).color)
        .toSet();

    final sheetContext = tester.element(find.byType(MealDetailSheet));
    final lightSurface = sheetContext.exomPalette.surface;
    expect(sheetColors(), contains(lightSurface));

    await tester.pumpWidget(_Host(mode: ThemeMode.dark, router: router));
    await tester.pump(const Duration(milliseconds: 600));

    final darkSurface = tester
        .element(find.byType(MealDetailSheet))
        .exomPalette
        .surface;
    expect(darkSurface, isNot(lightSurface));
    expect(sheetColors(), contains(darkSurface));
    expect(sheetColors(), isNot(contains(lightSurface)));
  });
}
