import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';

void main() {
  final selectedDate = DateTime(2026, 9, 5);

  Widget homeCardHarness(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(393, 852),
        textScaler: TextScaler.linear(2),
      ),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );
  }

  Future<Uri> openCardRoute(
    WidgetTester tester, {
    required Widget child,
    required String tapText,
    required String destinationPath,
  }) async {
    Uri? openedUri;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: child),
        ),
        GoRoute(
          path: destinationPath,
          builder: (context, state) {
            openedUri = state.uri;
            return const Scaffold(body: Text('Destino'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text(tapText));
    await tester.pumpAndSettle();

    return openedUri!;
  }

  testWidgets('TodayTrainingCard shows the mockup CTA label', (tester) async {
    const summary = HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: 'Full Body',
      trainingTypes: ['FUERZA'],
      trainingDurationMin: 45,
      exercisesCompleted: 0,
      totalExercises: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: TodayTrainingCard(summary: summary, selectedDate: selectedDate),
        ),
      ),
    );

    expect(find.text('Comenzar'), findsOneWidget);
  });

  testWidgets('TodayTrainingCard hides when day only has a diet', (
    tester,
  ) async {
    const summary = HomeSummaryEntity(
      dietId: 'diet-1',
      dietName: 'Plan diario',
    );

    await tester.pumpWidget(
      homeCardHarness(
        TodayTrainingCard(summary: summary, selectedDate: selectedDate),
      ),
    );

    expect(find.text('Entrenamiento de hoy'), findsNothing);
    expect(find.text('Sin nombre'), findsNothing);
  });

  testWidgets('TodayTrainingCard keeps selected date when opening training', (
    tester,
  ) async {
    const summary = HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: 'Full Body',
      trainingTypes: ['FUERZA'],
    );
    final uri = await openCardRoute(
      tester,
      child: TodayTrainingCard(summary: summary, selectedDate: selectedDate),
      tapText: 'Comenzar',
      destinationPath: '/trainings/:id',
    );

    expect(uri.queryParameters['date'], '2026-09-05');
  });

  testWidgets('TodayTrainingCard keeps date for secondary training', (
    tester,
  ) async {
    const summary = HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: 'Primero',
      trainings: [
        HomeTrainingItemEntity(
          id: 'training-1',
          name: 'Primero',
          completed: false,
        ),
        HomeTrainingItemEntity(
          id: 'training-2',
          name: 'Segundo',
          completed: false,
        ),
      ],
    );
    final uri = await openCardRoute(
      tester,
      child: TodayTrainingCard(summary: summary, selectedDate: selectedDate),
      tapText: 'Segundo',
      destinationPath: '/trainings/:id',
    );

    expect(uri.path, '/trainings/training-2');
    expect(uri.queryParameters['date'], '2026-09-05');
  });

  testWidgets('TodayTrainingCard handles long text with large fonts', (
    tester,
  ) async {
    const summary = HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: 'Entrenamiento de hoy Circuito 2 Lola con nombre largo',
      trainingTypes: ['FUERZA', 'CADENA_POSTERIOR', 'MOVILIDAD', 'CORE'],
      trainingDurationMin: 115,
      exercisesCompleted: 3,
      totalExercises: 3,
      trainingCompleted: true,
    );

    await tester.pumpWidget(
      homeCardHarness(
        TodayTrainingCard(summary: summary, selectedDate: selectedDate),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayDietCard shows the next meal CTA label', (tester) async {
    const summary = HomeSummaryEntity(
      dietId: 'diet-1',
      dietName: 'Plan diario',
      nextMealId: 'meal-1',
      nextMealName: 'Almuerzo',
      totalCalories: 2000,
      mealsCompleted: 1,
      totalMeals: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: TodayDietCard(summary: summary, selectedDate: selectedDate),
        ),
      ),
    );

    expect(find.text('Siguiente comida'), findsOneWidget);
  });

  testWidgets('TodayDietCard hides when day only has training', (tester) async {
    const summary = HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: 'Full Body',
    );

    await tester.pumpWidget(
      homeCardHarness(
        TodayDietCard(summary: summary, selectedDate: selectedDate),
      ),
    );

    expect(find.text('Dieta de hoy'), findsNothing);
    expect(find.text('Plan nutricional'), findsNothing);
  });

  testWidgets('TodayDietCard handles long text with large fonts', (
    tester,
  ) async {
    const summary = HomeSummaryEntity(
      dietId: 'diet-1',
      dietName: 'Plan diario de nutricion personalizado con descripcion larga',
      nextMealId: 'meal-1',
      nextMealName: 'Almuerzo con proteina, verduras y carbohidratos',
      totalCalories: 2450,
      mealsCompleted: 4,
      totalMeals: 4,
    );

    await tester.pumpWidget(
      homeCardHarness(
        TodayDietCard(summary: summary, selectedDate: selectedDate),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayDietCard keeps selected date when opening full diet', (
    tester,
  ) async {
    const summary = HomeSummaryEntity(
      dietId: 'diet-1',
      dietName: 'Plan diario',
    );
    final uri = await openCardRoute(
      tester,
      child: TodayDietCard(summary: summary, selectedDate: selectedDate),
      tapText: 'Ver dieta completa',
      destinationPath: '/diets',
    );

    expect(uri.queryParameters['date'], '2026-09-05');
  });

  testWidgets('NoConnectionWidget exposes the offline CTA label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: NoConnectionWidget(onRetry: () {}, onViewOffline: () {}),
        ),
      ),
    );

    expect(find.text('Ver offline'), findsOneWidget);
  });
}
