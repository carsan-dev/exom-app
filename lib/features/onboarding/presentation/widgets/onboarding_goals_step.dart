import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'onboarding_progress_indicator.dart';
import 'onboarding_step_layout.dart';

/// Goals of the onboarding: level, main goal and the optional targets.
///
/// The muscle mass goal accepts the decimal separator of the language
/// (L4-I19; [ExomNumeralStepper.parse]: digits with at most one «,» or «.»,
/// no grouping). Its loaded value is shown with that separator and, while the
/// text is left as shown, the loaded number is sent unchanged. Text that does
/// not parse shows an inline error and «Siguiente» does not advance; an empty
/// field sends nothing, as before. The calories keep their whole-number rule.
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
  final _formKey = GlobalKey<FormState>();
  String? _level;
  late final TextEditingController _goalController;
  late final TextEditingController _muscleMassController;
  late final TextEditingController _caloriesController;
  var _localeInitialized = false;

  /// Loaded muscle mass goal and the text it was shown as.
  double? _loadedMuscle;
  String? _loadedMuscleText;

  static const _levels = ['PRINCIPIANTE', 'INTERMEDIO', 'AVANZADO'];

  @override
  void initState() {
    super.initState();
    _level = widget.initialData['level'] as String?;
    _goalController = TextEditingController();
    final muscleGoal = widget.initialData['muscle_mass_goal'];
    _loadedMuscle = muscleGoal is num ? muscleGoal.toDouble() : null;
    _muscleMassController = TextEditingController();
    final calories = widget.initialData['target_calories'];
    _caloriesController = TextEditingController(
      text: calories != null ? calories.toString() : '',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localeInitialized) {
      return;
    }

    final initialGoal = widget.initialData['main_goal'] as String?;
    _goalController.text = _normalizedGoalText(context, initialGoal);
    final loaded = _loadedMuscle;
    if (loaded != null) {
      final text = formatDisplayDecimal(
        loaded,
        decimalSeparator: decimalSeparatorFor(
          Localizations.localeOf(context).languageCode,
        ),
      );
      _loadedMuscleText = text;
      _muscleMassController.text = text;
    }
    _localeInitialized = true;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _muscleMassController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  String? _validateMuscle(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty || raw == _loadedMuscleText) return null;
    return ExomNumeralStepper.parse(raw) == null
        ? AppLocalizations.of(context).onboardingNumberInvalid
        : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{};
    if (_level != null) data['level'] = _level;
    if (_goalController.text.trim().isNotEmpty) {
      data['main_goal'] = _goalController.text.trim();
    }
    final muscleText = _muscleMassController.text.trim();
    final loaded = _loadedMuscle;
    if (muscleText.isNotEmpty) {
      // Left as shown: the loaded number, not its rounded text.
      final muscle = loaded != null && muscleText == _loadedMuscleText
          ? loaded
          : ExomNumeralStepper.parse(muscleText);
      if (muscle != null) data['muscle_mass_goal'] = muscle;
    }
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
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final fieldStyle = TextStyle(color: palette.textPrimary);

    // The labels are painted above the fields so they wrap (O3).
    final muscleField = OnboardingLabeledField(
      label: l10n.onboardingMuscleMassGoalLabel,
      field: TextFormField(
        key: const Key('onboarding-muscle-goal'),
        controller: _muscleMassController,
        style: fieldStyle,
        decoration: InputDecoration(
          suffixText: weightUnitSymbol(UnitSystem.metric),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _validateMuscle,
        autovalidateMode: AutovalidateMode.onUserInteractionIfError,
        errorBuilder: onboardingFieldError,
      ),
    );
    final caloriesField = OnboardingLabeledField(
      label: l10n.onboardingTargetCaloriesLabel,
      field: TextFormField(
        key: const Key('onboarding-target-calories'),
        controller: _caloriesController,
        style: fieldStyle,
        decoration: const InputDecoration(suffixText: 'kcal'),
        keyboardType: TextInputType.number,
      ),
    );

    return Form(
      key: _formKey,
      child: OnboardingStepLayout(
        footer: OnboardingStepActions(
          primaryKey: const Key('onboarding-goals-next'),
          primaryLabel: l10n.onboardingNextButton,
          onPrimary: _submit,
          quietLabel: l10n.onboardingSkipButton,
          onQuiet: widget.onSkip,
        ),
        children: [
          OnboardingStepHeading(
            step: 3,
            total: 4,
            first: l10n.onboardingGoalsHeadlineFirst,
            second: l10n.onboardingGoalsHeadlineSecond,
          ),
          const SizedBox(height: ExomSpacing.xxl),
          OnboardingQuestion(
            n: 1,
            label: l10n.onboardingLevelLabel,
            child: ExomChoiceChips<String>(
              key: const Key('onboarding-level'),
              options: _levels,
              selected: _level,
              labelOf: (level) => _levelLabel(context, level),
              onSelected: (level) => setState(() => _level = level),
            ),
          ),
          OnboardingQuestion(
            n: 2,
            label: l10n.onboardingMainGoalLabel,
            labelInControl: true,
            child: TextFormField(
              key: const Key('onboarding-main-goal'),
              controller: _goalController,
              style: fieldStyle,
              decoration: InputDecoration(
                labelText: l10n.onboardingMainGoalLabel,
              ),
              maxLines: 2,
            ),
          ),
          OnboardingQuestion(
            n: 3,
            label: l10n.onboardingTargetsLabel,
            bottomRule: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Side by side while each field keeps 10 em (sketch `.d-two`);
                // stacked otherwise.
                final em = MediaQuery.textScalerOf(context).scale(16);
                final sideBySide =
                    constraints.maxWidth >= 2 * 10 * em + ExomSpacing.md;
                if (!sideBySide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      muscleField,
                      const SizedBox(height: ExomSpacing.lg),
                      caloriesField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: muscleField),
                    const SizedBox(width: ExomSpacing.md),
                    Expanded(child: caloriesField),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
