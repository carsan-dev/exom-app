// Isolated synthetic entrypoint for a later authorized build/smoke.
// Never imports main.dart, injection_container, bootstrap, Firebase or HTTP.
import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_published_review_card.dart';

void main() => runApp(const RecapUiHarness());

class RecapUiHarness extends StatelessWidget {
  const RecapUiHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        appBar: AppBar(title: const Text('Recap · datos sintéticos')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RecapPublishedReviewCard(
            recap: RecapEntity(
              id: 'synthetic-publication',
              weekStartDate: DateTime(2026, 10, 5),
              weekEndDate: DateTime(2026, 10, 11),
              status: 'REVIEWED',
              createdAt: DateTime(2026, 10, 5),
              publishedCoachSummary: 'Resumen confirmado.\n\nSegunda línea.',
              publishedChanges: 'Cambios realizados para la semana.',
              publishedNextWeekGoals:
                  'Objetivos próximos.\n${'Palabralarga' * 60}\nÚltimo objetivo.',
            ),
          ),
        ),
      ),
    );
  }
}
