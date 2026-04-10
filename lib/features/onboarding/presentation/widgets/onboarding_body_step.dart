import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/glass_card.dart';

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

  @override
  State<OnboardingBodyStep> createState() => _OnboardingBodyStepState();
}

class _OnboardingBodyStepState extends State<OnboardingBodyStep> {
  late double _height; // cm
  late double _weight; // kg
  bool _useManualHeight = false;
  bool _useManualWeight = false;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _height = (widget.initialData['height'] as num?)?.toDouble() ?? 170.0;
    _weight =
        (widget.initialData['current_weight'] as num?)?.toDouble() ?? 70.0;
    _heightController.text = _height.toStringAsFixed(0);
    _weightController.text = _weight.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final data = <String, dynamic>{};
    final parsedHeight = _useManualHeight
        ? double.tryParse(_heightController.text)
        : _height;
    final parsedWeight = _useManualWeight
        ? double.tryParse(_weightController.text)
        : _weight;

    if (parsedHeight != null && parsedHeight > 0) {
      data['height'] = parsedHeight;
    }
    if (parsedWeight != null && parsedWeight > 0) {
      data['current_weight'] = parsedWeight;
    }
    widget.onNext(data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

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
                      l10n.onboardingBodyTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Text(
                          l10n.onboardingHeightLabel,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(
                            () => _useManualHeight = !_useManualHeight,
                          ),
                          child: Text(
                            l10n.manualEntryToggle,
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_useManualHeight)
                      TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(suffixText: 'cm'),
                      )
                    else ...[
                      Slider(
                        value: _height.clamp(140.0, 220.0),
                        min: 140,
                        max: 220,
                        divisions: 80,
                        label: '${_height.toStringAsFixed(0)} cm',
                        activeColor: palette.primary,
                        onChanged: (v) => setState(() {
                          _height = v;
                          _heightController.text = v.toStringAsFixed(0);
                        }),
                      ),
                      Center(
                        child: Text(
                          '${_height.toStringAsFixed(0)} cm',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Text(
                          l10n.onboardingWeightLabel,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(
                            () => _useManualWeight = !_useManualWeight,
                          ),
                          child: Text(
                            l10n.manualEntryToggle,
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_useManualWeight)
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(suffixText: 'kg'),
                      )
                    else ...[
                      Slider(
                        value: _weight.clamp(40.0, 200.0),
                        min: 40,
                        max: 200,
                        divisions: 160,
                        label: '${_weight.toStringAsFixed(1)} kg',
                        activeColor: palette.primary,
                        onChanged: (v) => setState(() {
                          _weight = v;
                          _weightController.text = v.toStringAsFixed(1);
                        }),
                      ),
                      Center(
                        child: Text(
                          '${_weight.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _StepButtons(onNext: _submit, onSkip: widget.onSkip),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StepButtons extends StatelessWidget {
  const _StepButtons({required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.exomPalette;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onNext,
            child: Text(l10n.onboardingNextButton),
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
