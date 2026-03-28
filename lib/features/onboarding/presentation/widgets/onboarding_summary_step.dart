import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class OnboardingSummaryStep extends StatelessWidget {
  const OnboardingSummaryStep({
    super.key,
    required this.accumulatedData,
    required this.avatarUrl,
    required this.onConfirm,
    required this.onEdit,
  });

  final Map<String, dynamic> accumulatedData;
  final String? avatarUrl;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  int _completionPercent() {
    const fields = [
      'first_name',
      'last_name',
      'birth_date',
      'height',
      'current_weight',
      'level',
      'main_goal',
    ];
    final filled = fields.where((f) => accumulatedData[f] != null).length;
    var total = fields.length;
    if (avatarUrl != null) total++;
    final withAvatar = avatarUrl != null ? filled + 1 : filled;
    return (withAvatar / total * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;
    final percent = _completionPercent();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.onboardingSummaryTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),

          // Completion card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              children: [
                // Avatar + name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: palette.surfaceVariant,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl == null
                          ? Icon(Icons.person, color: palette.textDisabled, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              accumulatedData['first_name'],
                              accumulatedData['last_name'],
                            ].where((v) => v != null).join(' '),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.onboardingProgressComplete(percent),
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    backgroundColor: palette.surfaceVariant,
                    color: palette.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),

                // Data summary
                if (accumulatedData['height'] != null ||
                    accumulatedData['current_weight'] != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (accumulatedData['height'] != null)
                        _StatTile(
                          label: l10n.height,
                          value: '${(accumulatedData['height'] as num).toStringAsFixed(0)} cm',
                          palette: palette,
                        ),
                      if (accumulatedData['current_weight'] != null)
                        _StatTile(
                          label: l10n.weight,
                          value: '${(accumulatedData['current_weight'] as num).toStringAsFixed(1)} kg',
                          palette: palette,
                        ),
                      if (accumulatedData['level'] != null)
                        _StatTile(
                          label: l10n.onboardingLevelLabel,
                          value: _localizedLevel(context, accumulatedData['level'] as String),
                          palette: palette,
                        ),
                    ],
                  ),
              ],
            ),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              child: Text(l10n.onboardingConfirmButton),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onEdit,
              child: Text(l10n.onboardingEditButton),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _localizedLevel(BuildContext context, String level) {
    final l10n = AppLocalizations.of(context)!;
    switch (level.toUpperCase()) {
      case 'BEGINNER':
        return l10n.beginnerLevel;
      case 'INTERMEDIATE':
        return l10n.intermediateLevel;
      case 'ADVANCED':
        return l10n.advancedLevel;
      default:
        return level;
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final ExomThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: palette.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
