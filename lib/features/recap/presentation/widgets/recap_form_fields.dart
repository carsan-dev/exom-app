import 'package:flutter/material.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/body_silhouette_painter.dart';

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
    'REGULAR': ['Regular', 'Fair'],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
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
                  color: palette.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
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
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
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
class RecapBodyMapField extends StatefulWidget {
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

  @override
  State<RecapBodyMapField> createState() => _RecapBodyMapFieldState();
}

class _RecapBodyMapFieldState extends State<RecapBodyMapField> {
  bool _isFront = true;

  static const _zoneLabels = <String, String>{
    'CUELLO': 'CUELLO',
    'HOMBROS': 'HOMBROS',
    'ESPALDA': 'ESPALDA',
    'LUMBAR': 'LUMBAR',
    'GLUTEOS': 'GLUTEOS',
    'CUADRICEPS': 'CUADRICEPS',
    'ISQUIOS': 'ISQUIOS',
    'GEMELOS': 'GEMELOS',
  };

  // ── Front view ──
  static const _frontLeft = ['CUELLO', 'CUADRICEPS'];
  static const _frontRight = ['HOMBROS', 'GEMELOS'];
  static const _frontHotspots = <String, List<double>>{
    'CUELLO': [0.50, 0.10],
    'HOMBROS': [0.50, 0.18],
    'CUADRICEPS': [0.50, 0.57],
    'GEMELOS': [0.50, 0.78],
  };
  static const _frontLeftFlex = [2, 14, 15];
  static const _frontRightFlex = [3, 13, 4];

  // ── Back view ──
  static const _backLeft = ['ESPALDA', 'GLUTEOS'];
  static const _backRight = ['LUMBAR', 'ISQUIOS'];
  static const _backHotspots = <String, List<double>>{
    'ESPALDA': [0.50, 0.25],
    'LUMBAR': [0.50, 0.37],
    'GLUTEOS': [0.50, 0.46],
    'ISQUIOS': [0.50, 0.60],
  };
  static const _backLeftFlex = [5, 3, 12];
  static const _backRightFlex = [8, 4, 9];

  void _toggleZone(String zone) {
    final next = List<String>.from(widget.values);
    if (next.contains(zone)) {
      next.remove(zone);
    } else {
      next.add(zone);
    }
    widget.onChanged(next);
  }

  Widget _zoneButton(String id) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final isSelected = widget.values.contains(id);
    return GestureDetector(
      onTap: () => _toggleZone(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? semantic.accent.withValues(alpha: 0.9)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? semantic.accent : palette.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          recapCopy(context, _zoneLabels[id] ?? id),
          style: TextStyle(
            color: isSelected ? Colors.white : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _bodyHotspot(String zoneId, double relX, double relY) {
    final isSelected = widget.values.contains(zoneId);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    const s = 26.0;
    return Positioned(
      left: relX * 90 - s / 2,
      top: relY * 380 - s / 2,
      child: GestureDetector(
        onTap: () => _toggleZone(zoneId),
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? semantic.accent.withValues(alpha: 0.3)
                : palette.primary.withValues(alpha: 0.08),
          ),
          child: Center(
            child: Container(
              width: isSelected ? 10 : 5,
              height: isSelected ? 10 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? semantic.accent
                    : palette.primary.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneColumn(
    List<String> zones,
    List<int> flex,
    CrossAxisAlignment align,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Spacer(flex: flex[0]),
          _zoneButton(zones[0]),
          Spacer(flex: flex[1]),
          _zoneButton(zones[1]),
          Spacer(flex: flex[2]),
        ],
      ),
    );
  }

  Widget _viewTab(String label, bool isActive) {
    final palette = context.exomPalette;
    return GestureDetector(
      onTap: () => setState(() => _isFront = label == 'FRONTAL'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? palette.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? palette.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive
                  ? (label == 'FRONTAL'
                        ? Icons.accessibility_new
                        : Icons.accessibility)
                  : Icons.circle,
              size: isActive ? 16 : 6,
              color: isActive ? palette.primary : palette.textDisabled,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? palette.primary : palette.textSecondary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final leftZones = _isFront ? _frontLeft : _backLeft;
    final rightZones = _isFront ? _frontRight : _backRight;
    final leftFlex = _isFront ? _frontLeftFlex : _backLeftFlex;
    final rightFlex = _isFront ? _frontRightFlex : _backRightFlex;
    final hotspots = _isFront ? _frontHotspots : _backHotspots;

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
        const SizedBox(height: 4),
        Text(
          widget.helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        // ── Toggle Frontal / Posterior ──
        Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewTab('FRONTAL', _isFront),
                _viewTab('POSTERIOR', !_isFront),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 380,
          child: Row(
            children: [
              _buildZoneColumn(leftZones, leftFlex, CrossAxisAlignment.end),
              const SizedBox(width: 6),
              // ── Body silhouette with tappable zones ──
              SizedBox(
                width: 90,
                height: 380,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(90, 380),
                      painter: BodySilhouettePainter(
                        isBack: !_isFront,
                        fillColor: palette.textSecondary.withValues(
                          alpha: 0.08,
                        ),
                        strokeColor: palette.textSecondary.withValues(
                          alpha: 0.22,
                        ),
                        detailColor: palette.textSecondary.withValues(
                          alpha: 0.16,
                        ),
                      ),
                    ),
                    ...hotspots.entries.map(
                      (e) => _bodyHotspot(e.key, e.value[0], e.value[1]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildZoneColumn(rightZones, rightFlex, CrossAxisAlignment.start),
            ],
          ),
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.values.map((zone) {
              return Chip(
                label: Text(
                  recapCopy(context, _zoneLabels[zone] ?? zone),
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
