import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';

class RecapStartView extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String weekLabel;
  final VoidCallback onStart;
  final VoidCallback onReviewAndSend;
  final VoidCallback onCancel;

  const RecapStartView({
    super.key,
    required this.formData,
    required this.weekLabel,
    required this.onStart,
    required this.onReviewAndSend,
    required this.onCancel,
  });

  bool _isStepComplete(int step) {
    switch (step) {
      case 0:
        return formData['training_effort'] != null;
      case 1:
        return formData['nutrition_quality'] != null;
      case 2:
        return formData['sleep_hours_range'] != null;
      case 3:
        return formData['mood'] != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    final sections = [
      (icon: Icons.fitness_center_rounded, label: l10n.recapTraining),
      (icon: Icons.restaurant_rounded, label: l10n.recapNutrition),
      (icon: Icons.bedtime_rounded, label: l10n.recapRecovery),
      (icon: Icons.mood_rounded, label: l10n.recapGeneral),
    ];

    final allComplete = List.generate(
      4,
      (i) => _isStepComplete(i),
    ).every((c) => c);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: GlassDecoration.accentCard(
              palette.primary,
              borderRadius: 14,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: palette.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  weekLabel,
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.recapStartTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.recapStartDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Sections list
          GlassCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            borderRadius: 22,
            child: Column(
              children: List.generate(sections.length, (index) {
                final section = sections[index];
                final isComplete = _isStepComplete(index);
                final isLast = index == sections.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: isComplete
                                ? GlassDecoration.accentCard(
                                    palette.primary,
                                    borderRadius: 12,
                                  )
                                : GlassDecoration.card(borderRadius: 12),
                            child: Icon(
                              section.icon,
                              size: 18,
                              color: isComplete
                                  ? palette.primary
                                  : palette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}. ${section.label}',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isComplete
                                  ? palette.primary
                                  : Colors.transparent,
                              border: isComplete
                                  ? null
                                  : Border.all(
                                      color: palette.glassBorder,
                                      width: 1.2,
                                    ),
                            ),
                            child: isComplete
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 18,
                        endIndent: 18,
                        color: palette.divider,
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: allComplete ? onReviewAndSend : onStart,
              icon: Icon(
                allComplete ? Icons.send_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                allComplete
                    ? l10n.recapReviewAndSendButton
                    : l10n.recapStartButton,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
          ),
        ],
      ),
    );
  }
}
