import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';

class OnboardingGoalsStep extends StatefulWidget {
  const OnboardingGoalsStep({
    super.key,
    required this.initialData,
    required this.onNext,
    required this.onSkip,
  });

  final Map<String, dynamic> initialData;
  final void Function(Map<String, dynamic> data) onNext;
  final VoidCallback onSkip;

  @override
  State<OnboardingGoalsStep> createState() => _OnboardingGoalsStepState();
}

class _OnboardingGoalsStepState extends State<OnboardingGoalsStep> {
  String? _level;
  late final TextEditingController _goalController;
  late final TextEditingController _muscleMassController;
  late final TextEditingController _caloriesController;
  var _goalInitialized = false;

  static const _levels = ['PRINCIPIANTE', 'INTERMEDIO', 'AVANZADO'];

  @override
  void initState() {
    super.initState();
    _level = widget.initialData['level'] as String?;
    _goalController = TextEditingController();
    final muscleGoal = widget.initialData['muscle_mass_goal'];
    _muscleMassController = TextEditingController(
      text: muscleGoal != null ? muscleGoal.toString() : '',
    );
    final calories = widget.initialData['target_calories'];
    _caloriesController = TextEditingController(
      text: calories != null ? calories.toString() : '',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_goalInitialized) {
      return;
    }

    final initialGoal = widget.initialData['main_goal'] as String?;
    _goalController.text = _normalizedGoalText(context, initialGoal);
    _goalInitialized = true;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _muscleMassController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _submit() {
    final data = <String, dynamic>{};
    if (_level != null) data['level'] = _level;
    if (_goalController.text.trim().isNotEmpty) {
      data['main_goal'] = _goalController.text.trim();
    }
    final muscle = double.tryParse(_muscleMassController.text);
    if (muscle != null) data['muscle_mass_goal'] = muscle;
    final calories = int.tryParse(_caloriesController.text);
    if (calories != null) data['target_calories'] = calories;
    widget.onNext(data);
  }

  String _normalizedGoalText(BuildContext context, String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'hola') {
      return _defaultGoalText(context);
    }
    return trimmed;
  }

  String _defaultGoalText(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'es'
        ? 'Mejorar mi salud y sentirme mejor cada semana'
        : 'Improve my health and feel better each week';
  }

  String _levelLabel(BuildContext context, String level) {
    final l10n = AppLocalizations.of(context);
    switch (level) {
      case 'BEGINNER':
      case 'PRINCIPIANTE':
        return l10n.beginnerLevel;
      case 'INTERMEDIATE':
      case 'INTERMEDIO':
        return l10n.intermediateLevel;
      case 'ADVANCED':
      case 'AVANZADO':
        return l10n.advancedLevel;
      default:
        return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(24),
                borderRadius: 28,
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingGoalsTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      l10n.onboardingLevelLabel,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _levels.map((level) {
                        final isSelected = _level == level;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => setState(() => _level = level),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: isSelected
                                    ? GlassDecoration.accentCard(
                                        palette.primary,
                                        borderRadius: 14,
                                      )
                                    : GlassDecoration.card(borderRadius: 14),
                                child: Text(
                                  _levelLabel(context, level),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? palette.primary
                                        : palette.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _goalController,
                      decoration: InputDecoration(
                        labelText: l10n.onboardingMainGoalLabel,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _muscleMassController,
                      decoration: InputDecoration(
                        labelText: l10n.onboardingMuscleMassGoalLabel,
                        suffixText: 'kg',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _caloriesController,
                      decoration: InputDecoration(
                        labelText: l10n.onboardingTargetCaloriesLabel,
                        suffixText: 'kcal',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _CompleteButtons(onComplete: _submit, onSkip: widget.onSkip),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CompleteButtons extends StatelessWidget {
  const _CompleteButtons({required this.onComplete, required this.onSkip});

  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onComplete,
            child: Text(l10n.onboardingCompleteProfileButton),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              l10n.onboardingSkipButton,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
