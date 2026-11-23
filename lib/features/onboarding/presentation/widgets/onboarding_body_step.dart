import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'onboarding_progress_indicator.dart';
import 'onboarding_step_layout.dart';

/// Height and weight of the onboarding (L5-D2, D14-4): two
/// [ExomNumeralStepper]s that keep the validation of the former sliders and
/// manual fields (contract table «Rangos de los steppers»):
///
/// * ± move by 1 inside 140-220 cm and 40-200 kg; untouched, the starting
///   value (the loaded one, else 170 cm and 70 kg) is sent unchanged.
/// * Typing accepts any value greater than 0 without a cap, with the decimal
///   separator of the language (L4-I19; the stepper also reads the other
///   one, at most one separator and never thousands grouping).
/// * Text that does not parse, and a value of 0, show an inline error and
///   «Siguiente» does not advance: nothing different from what is typed is
///   ever sent.
///
/// The onboarding is metric (contract 1.2): cm and kg, whatever the unit
/// preference.
class OnboardingBodyStep extends StatefulWidget {
  const OnboardingBodyStep({
    super.key,
    required this.initialData,
    required this.onNext,
    required this.onSkip,
  });

  final Map<String, dynamic> initialData;
  final void Function(Map<String, dynamic> data) onNext;
  final VoidCallback onSkip;

  static const double heightMin = 140;
  static const double heightMax = 220;
  static const double weightMin = 40;
  static const double weightMax = 200;
  static const double step = 1;

  @override
  State<OnboardingBodyStep> createState() => _OnboardingBodyStepState();
}

class _OnboardingBodyStepState extends State<OnboardingBodyStep> {
  late double _height; // cm
  late double _weight; // kg

  /// False while the typed text of that stepper does not parse.
  bool _heightParses = true;
  bool _weightParses = true;

  /// Errors are shown once «Siguiente» was tried, then follow the text.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _height = (widget.initialData['height'] as num?)?.toDouble() ?? 170.0;
    _weight =
        (widget.initialData['current_weight'] as num?)?.toDouble() ?? 70.0;
  }

  bool _isValid(bool parses, double value) => parses && value > 0;

  String? _errorFor(AppLocalizations l10n, bool parses, double value) {
    if (!_showErrors) return null;
    if (!parses) return l10n.onboardingNumberInvalid;
    if (value <= 0) return l10n.onboardingNumberNotPositive;
    return null;
  }

  void _submit() {
    if (!_isValid(_heightParses, _height) ||
        !_isValid(_weightParses, _weight)) {
      setState(() => _showErrors = true);
      return;
    }
    widget.onNext({'height': _height, 'current_weight': _weight});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cm = lengthUnitSymbol(UnitSystem.metric);
    final kg = weightUnitSymbol(UnitSystem.metric);
    String stepText(String unit) =>
        '${formatFigure(context, OnboardingBodyStep.step)} $unit';

    return OnboardingStepLayout(
      footer: OnboardingStepActions(
        primaryKey: const Key('onboarding-body-next'),
        primaryLabel: l10n.onboardingNextButton,
        onPrimary: _submit,
        quietLabel: l10n.onboardingSkipButton,
        onQuiet: widget.onSkip,
      ),
      children: [
        OnboardingStepHeading(
          step: 2,
          total: 4,
          first: l10n.onboardingBodyHeadlineFirst,
          second: l10n.onboardingBodyHeadlineSecond,
        ),
        const SizedBox(height: ExomSpacing.xxl),
        OnboardingQuestion(
          n: 1,
          label: l10n.height,
          labelInControl: true,
          child: ExomNumeralStepper(
            key: const Key('onboarding-height'),
            value: _height,
            min: OnboardingBodyStep.heightMin,
            max: OnboardingBodyStep.heightMax,
            step: OnboardingBodyStep.step,
            unit: cm,
            label: l10n.height,
            decrementLabel: l10n.onboardingStepDecrease(stepText(cm)),
            incrementLabel: l10n.onboardingStepIncrease(stepText(cm)),
            acceptsTypedOutOfRange: true,
            errorText: _errorFor(l10n, _heightParses, _height),
            onChanged: (value) => setState(() {
              _height = value;
              _heightParses = true;
            }),
            onInvalidInput: (_) => setState(() => _heightParses = false),
          ),
        ),
        OnboardingQuestion(
          n: 2,
          label: l10n.weight,
          labelInControl: true,
          bottomRule: true,
          child: ExomNumeralStepper(
            key: const Key('onboarding-weight'),
            value: _weight,
            min: OnboardingBodyStep.weightMin,
            max: OnboardingBodyStep.weightMax,
            step: OnboardingBodyStep.step,
            unit: kg,
            label: l10n.weight,
            decrementLabel: l10n.onboardingStepDecrease(stepText(kg)),
            incrementLabel: l10n.onboardingStepIncrease(stepText(kg)),
            acceptsTypedOutOfRange: true,
            errorText: _errorFor(l10n, _weightParses, _weight),
            onChanged: (value) => setState(() {
              _weight = value;
              _weightParses = true;
            }),
            onInvalidInput: (_) => setState(() => _weightParses = false),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kOnboardingSidePadding,
            ExomSpacing.sm,
            kOnboardingSidePadding,
            0,
          ),
          child: Text(
            l10n.onboardingNumeralHint,
            style: onboardingSecondaryStyle(context),
          ),
        ),
      ],
    );
  }
}
