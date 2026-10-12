import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

/// Read-only publication, independent of the legacy feedback read marker.
class RecapPublishedReviewCard extends StatelessWidget {
  const RecapPublishedReviewCard({super.key, required this.recap});

  final RecapEntity recap;

  @override
  Widget build(BuildContext context) {
    if (!recap.hasPublishedReview) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final sections = <(String, String?)>[
      ('Resumen del coach', recap.publishedCoachSummary),
      ('Cambios realizados', recap.publishedChanges),
      ('Objetivos próxima semana', recap.publishedNextWeekGoals),
    ].where((section) => section.$2?.trim().isNotEmpty ?? false).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: GlassDecoration.card(borderRadius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                sections[index].$1,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sections[index].$2!.trim(),
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
