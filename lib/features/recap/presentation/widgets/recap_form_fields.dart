import 'package:flutter/material.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';

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

String recapCopy(BuildContext context, String value) {
  const translations = <String, List<String>>{
    'ENTRENO': ['Entreno', 'Training'],
    'NUTRICION': ['Nutricion', 'Nutrition'],
    'RECUPERACION': ['Recuperacion', 'Recovery'],
    'GENERAL': ['General', 'General'],
    'REVIEWED': ['Revisado', 'Reviewed'],
    'SUBMITTED': ['Enviado', 'Submitted'],
    'DRAFT': ['Borrador', 'Draft'],
    'MAL': ['Mal', 'Bad'],
    'NO': ['No', 'No'],
    'REGULAR': ['Regular', 'Fair'],
    'SI': ['Si', 'Yes'],
    'NORMAL': ['Normal', 'Normal'],
    'BIEN': ['Bien', 'Good'],
    'MUY_BIEN': ['Muy bien', 'Very good'],
    'MUY_MAL': ['Muy mal', 'Very bad'],
    'ENTRENAMIENTO': ['Entrenamiento', 'Training'],
    'ADHERENCIA': ['Adherencia', 'Consistency'],
    'APP': ['App', 'App'],
    'NADA': ['Nada', 'None'],
    'POCO': ['Poco', 'Low'],
    'ESTABLE': ['Estable', 'Steady'],
    'MEJORANDO': ['Mejorando', 'Improving'],
    'EXCELENTE': ['Excelente', 'Excellent'],
    'BAJA': ['Baja', 'Low'],
    'MODERADA': ['Moderada', 'Moderate'],
    'ALTA': ['Alta', 'High'],
    'MUY_ALTA': ['Muy alta', 'Very high'],
    'MALA': ['Mala', 'Poor'],
    'BUENA': ['Buena', 'Good'],
    'MUY_BUENA': ['Muy buena', 'Very good'],
    'MENOS_5': ['Menos de 5 h', 'Under 5 h'],
    'ENTRE_5_6': ['Entre 5 y 6 h', 'Between 5 and 6 h'],
    'ENTRE_6_7': ['Entre 6 y 7 h', 'Between 6 and 7 h'],
    'MAS_8': ['Mas de 8 h', 'Over 8 h'],
    'CANSADO': ['Cansado', 'Tired'],
    'FUERTE': ['Fuerte', 'Strong'],
    'LEVE': ['Leve', 'Mild'],
    'MODERADO': ['Moderado', 'Moderate'],
    'ALTO': ['Alto', 'High'],
    'CUELLO': ['Cuello', 'Neck'],
    'HOMBROS': ['Hombros', 'Shoulders'],
    'ESPALDA': ['Espalda', 'Back'],
    'LUMBAR': ['Lumbar', 'Lower back'],
    'GLUTEOS': ['Gluteos', 'Glutes'],
    'CUADRICEPS': ['Cuadriceps', 'Quads'],
    'ISQUIOS': ['Isquios', 'Hamstrings'],
    'GEMELOS': ['Gemelos', 'Calves'],
    'neck': ['Cuello', 'Neck'],
    'shoulders': ['Hombros', 'Shoulders'],
    'chest': ['Pecho', 'Chest'],
    'upperArm': ['Brazo', 'Upper arm'],
    'forearm': ['Antebrazo', 'Forearm'],
    'waist': ['Cintura', 'Waist'],
    'hips': ['Caderas', 'Hips'],
    'thigh': ['Muslo', 'Thigh'],
    'calf': ['Pantorrilla', 'Calf'],
    'FRONTAL': ['Frontal', 'Front'],
    'POSTERIOR': ['Posterior', 'Back'],
  };

  final translation = translations[value];
  if (translation != null) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return languageCode == 'en' ? translation[1] : translation[0];
  }

  return formatRecapOption(value);
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
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: GlassDecoration.accentCard(
                  palette.primary,
                  borderRadius: 12,
                ),
                child: Icon(icon, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
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
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
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
                activeColor: palette.primary,
                inactiveColor: palette.surfaceVariant,
                label: valueLabelBuilder(value),
                onChanged: onChanged,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: GlassDecoration.card(borderRadius: 12),
              child: Text(
                valueLabelBuilder(value),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textPrimary,
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
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
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
              backgroundColor: palette.surfaceVariant,
              selectedColor: palette.primary.withValues(alpha: 0.18),
              side: BorderSide(
                color: isSelected ? palette.primary : palette.divider,
              ),
              label: Text(
                recapCopy(context, option),
                style: TextStyle(
                  color: isSelected ? palette.primary : palette.textSecondary,
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
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
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
              backgroundColor: palette.surfaceVariant,
              selectedColor: semantic.info.withValues(alpha: 0.16),
              side: BorderSide(
                color: isSelected ? semantic.info : palette.divider,
              ),
              label: Text(
                recapCopy(context, option),
                style: TextStyle(
                  color: isSelected ? semantic.info : palette.textSecondary,
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

// ── Emoji Rating (5 caras de triste a feliz) ──────────────────────────────
class RecapEmojiRatingField extends StatelessWidget {
  final String label;
  final String helperText;
  final int value; // 0-4
  final ValueChanged<int> onChanged;

  const RecapEmojiRatingField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
  });

  static const _emojis = ['😫', '😞', '😐', '🙂', '😁'];
  static const _labels = ['MUY_MAL', 'MAL', 'NORMAL', 'BIEN', 'MUY_BIEN'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final isSelected = value == index;
            return GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.primary.withValues(alpha: 0.18)
                      : palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? palette.primary : palette.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _emojis[index],
                      style: TextStyle(fontSize: isSelected ? 28 : 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recapCopy(context, _labels[index]),
                      style: TextStyle(
                        color: isSelected
                            ? palette.primary
                            : palette.textDisabled,
                        fontSize: 9,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Star Rating (1-5 estrellas) ───────────────────────────────────────────
class RecapStarRatingField extends StatelessWidget {
  final String label;
  final String helperText;
  final int value; // 1-5
  final ValueChanged<int> onChanged;

  const RecapStarRatingField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isFilled = starIndex <= value;
            return GestureDetector(
              onTap: () => onChanged(starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFilled ? semantic.warning : palette.textDisabled,
                  size: 40,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Modelo anatómico interactivo (frontal / posterior) ─────────────────────
class RecapBodyMapField extends StatelessWidget {
  final String label;
  final String helperText;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const RecapBodyMapField({
    super.key,
    required this.label,
    required this.helperText,
    required this.values,
    required this.onChanged,
  });

  void _toggleZone(String zoneId) {
    final next = List<String>.from(values);
    if (next.contains(zoneId)) {
      next.remove(zoneId);
    } else {
      next.add(zoneId);
    }
    onChanged(next);
  }

  String _zoneLabel(BuildContext context, String value) {
    return RecapAnatomyZone.fromId(value)?.label(context) ??
        recapCopy(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final selectedZoneIds = values
        .where((value) => RecapAnatomyZone.fromId(value) != null)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: RecapAnatomySelector(
            height: 440,
            selectedZoneIds: selectedZoneIds,
            onZoneSelected: _toggleZone,
          ),
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: values.map((zone) {
              return Chip(
                label: Text(
                  _zoneLabel(context, zone),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: semantic.accent,
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
                onDeleted: () => _toggleZone(zone),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
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
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 4,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: palette.textDisabled),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
