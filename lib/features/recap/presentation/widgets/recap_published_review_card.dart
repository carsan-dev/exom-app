import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:flutter/material.dart';

/// Read-only publication, independent of the legacy feedback read marker.
///
/// Flat (no card): each published section is a header and its text behind the
/// 2 px data edge of the trainer reply (`ExomReplyBlock`'s edge).
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
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
            DecoratedBox(
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: palette.data,
                    width: ExomRule.replyEdge,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Text(
                  sections[index].$2!.trim(),
                  softWrap: true,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
