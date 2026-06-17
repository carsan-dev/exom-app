import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';

void main() {
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
        home: Scaffold(body: TodayTrainingCard(summary: summary)),
      ),
    );

    expect(find.text('Comenzar'), findsOneWidget);
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
      homeCardHarness(TodayTrainingCard(summary: summary)),
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
        home: Scaffold(body: TodayDietCard(summary: summary)),
      ),
    );

    expect(find.text('Siguiente comida'), findsOneWidget);
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

    await tester.pumpWidget(homeCardHarness(TodayDietCard(summary: summary)));

    expect(tester.takeException(), isNull);
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
