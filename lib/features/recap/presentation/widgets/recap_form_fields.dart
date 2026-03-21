import 'package:flutter/material.dart';

import 'package:exom_app/core/theme/app_theme.dart';

String formatRecapOption(String value) {
  return value
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class RecapSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const RecapSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class RecapSliderField extends StatelessWidget {
  final String label;
  final String helperText;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value) valueLabelBuilder;
  final ValueChanged<double> onChanged;

  const RecapSliderField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.valueLabelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.surfaceVariant,
                label: valueLabelBuilder(value),
                onChanged: onChanged,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                valueLabelBuilder(value),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class RecapChoiceChipsField extends StatelessWidget {
  final String label;
  final String helperText;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const RecapChoiceChipsField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = value == option;
            return ChoiceChip(
              selected: isSelected,
              onSelected: (_) => onSelected(option),
              backgroundColor: AppColors.surfaceVariant,
              selectedColor: AppColors.primary.withValues(alpha: 0.18),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.divider,
              ),
              label: Text(
                formatRecapOption(option),
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class RecapMultiSelectField extends StatelessWidget {
  final String label;
  final String helperText;
  final List<String> values;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  const RecapMultiSelectField({
    super.key,
    required this.label,
    required this.helperText,
    required this.values,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = values.contains(option);
            return FilterChip(
              selected: isSelected,
              onSelected: (selected) {
                final nextValues = List<String>.from(values);
                if (selected) {
                  nextValues.add(option);
                } else {
                  nextValues.remove(option);
                }
                onChanged(nextValues);
              },
              backgroundColor: AppColors.surfaceVariant,
              selectedColor: AppColors.secondary.withValues(alpha: 0.18),
              side: BorderSide(
                color: isSelected ? AppColors.secondary : AppColors.divider,
              ),
              label: Text(
                formatRecapOption(option),
                style: TextStyle(
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class RecapTextAreaField extends StatefulWidget {
  final String label;
  final String hintText;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const RecapTextAreaField({
    super.key,
    required this.label,
    required this.hintText,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<RecapTextAreaField> createState() => _RecapTextAreaFieldState();
}

class _RecapTextAreaFieldState extends State<RecapTextAreaField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant RecapTextAreaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller
        ..text = widget.initialValue
        ..selection = TextSelection.collapsed(
          offset: widget.initialValue.length,
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: AppColors.textDisabled),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
