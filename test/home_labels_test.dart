import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';

void main() {
  testWidgets('TodayTrainingCard shows the mockup CTA label', (tester) async {
    const summary = HomeSummaryEntity(
      trainingId: 'training-1',
      trainingName: 'Full Body',
      trainingType: 'FUERZA',
      trainingDurationMin: 45,
      exercisesCompleted: 0,
      totalExercises: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: TodayTrainingCard(summary: summary)),
      ),
    );

    expect(find.text('Comenzar'), findsOneWidget);
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
        home: Scaffold(body: TodayDietCard(summary: summary)),
      ),
    );

    expect(find.text('Siguiente comida'), findsOneWidget);
  });

  testWidgets('NoConnectionWidget exposes the offline CTA label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoConnectionWidget(onRetry: () {}, onViewOffline: () {}),
        ),
      ),
    );

    expect(find.text('Ver offline'), findsOneWidget);
  });
}
