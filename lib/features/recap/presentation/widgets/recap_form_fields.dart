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
  static const _labels = ['Muy mal', 'Mal', 'Normal', 'Bien', 'Muy bien'];

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
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
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
                      _labels[index],
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textDisabled,
                        fontSize: 9,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
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
                  color: isFilled ? AppColors.secondary : AppColors.textDisabled,
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
    'CUELLO': 'Cuello',
    'HOMBROS': 'Hombros',
    'ESPALDA': 'Espalda',
    'LUMBAR': 'Lumbar',
    'GLUTEOS': 'Glúteos',
    'CUADRICEPS': 'Cuádriceps',
    'ISQUIOS': 'Isquios',
    'GEMELOS': 'Gemelos',
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
    final isSelected = widget.values.contains(id);
    return GestureDetector(
      onTap: () => _toggleZone(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.85)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          _zoneLabels[id] ?? id,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _bodyHotspot(String zoneId, double relX, double relY) {
    final isSelected = widget.values.contains(zoneId);
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
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.06),
          ),
          child: Center(
            child: Container(
              width: isSelected ? 10 : 5,
              height: isSelected ? 10 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.accent
                    : AppColors.primary.withValues(alpha: 0.25),
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
    return GestureDetector(
      onTap: () => setState(() => _isFront = label == 'Frontal'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive
                  ? (label == 'Frontal'
                      ? Icons.accessibility_new
                      : Icons.accessibility)
                  : Icons.circle,
              size: isActive ? 16 : 6,
              color: isActive ? AppColors.primary : AppColors.textDisabled,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.helperText,
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        ),
        const SizedBox(height: 12),
        // ── Toggle Frontal / Posterior ──
        Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewTab('Frontal', _isFront),
                _viewTab('Posterior', !_isFront),
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
                      painter: _BodySilhouettePainter(isBack: !_isFront),
                    ),
                    ...hotspots.entries.map(
                      (e) => _bodyHotspot(e.key, e.value[0], e.value[1]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildZoneColumn(
                  rightZones, rightFlex, CrossAxisAlignment.start),
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
                  _zoneLabels[zone] ?? zone,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: AppColors.accent,
                deleteIcon:
                    const Icon(Icons.close, size: 16, color: Colors.white),
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

class _BodySilhouettePainter extends CustomPainter {
  final bool isBack;

  const _BodySilhouettePainter({this.isBack = false});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Head (oval) ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.055),
        width: w * 0.28,
        height: h * 0.07,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.055),
        width: w * 0.28,
        height: h * 0.07,
      ),
      stroke,
    );

    // Anchor points shared by body and arms
    final lSh = Offset(cx - w * 0.32, h * 0.165);
    final lPit = Offset(cx - w * 0.22, h * 0.20);
    final rSh = Offset(cx + w * 0.32, h * 0.165);
    final rPit = Offset(cx + w * 0.22, h * 0.20);

    // ── Torso + legs ──
    final body = Path()..moveTo(cx - w * 0.08, h * 0.085);
    body.quadraticBezierTo(cx - w * 0.10, h * 0.13, lSh.dx, lSh.dy);
    body.quadraticBezierTo(cx - w * 0.28, h * 0.18, lPit.dx, lPit.dy);
    body.quadraticBezierTo(cx - w * 0.20, h * 0.28, cx - w * 0.17, h * 0.36);
    body.quadraticBezierTo(cx - w * 0.17, h * 0.40, cx - w * 0.22, h * 0.45);
    body.quadraticBezierTo(cx - w * 0.24, h * 0.52, cx - w * 0.20, h * 0.63);
    body.quadraticBezierTo(cx - w * 0.20, h * 0.70, cx - w * 0.18, h * 0.78);
    body.quadraticBezierTo(cx - w * 0.16, h * 0.84, cx - w * 0.14, h * 0.88);
    body.lineTo(cx - w * 0.20, h * 0.91);
    body.lineTo(cx - w * 0.08, h * 0.91);
    body.quadraticBezierTo(cx - w * 0.08, h * 0.82, cx - w * 0.10, h * 0.70);
    body.quadraticBezierTo(cx - w * 0.06, h * 0.55, cx - w * 0.05, h * 0.48);
    body.lineTo(cx + w * 0.05, h * 0.48);
    body.quadraticBezierTo(cx + w * 0.06, h * 0.55, cx + w * 0.10, h * 0.70);
    body.quadraticBezierTo(cx + w * 0.08, h * 0.82, cx + w * 0.08, h * 0.91);
    body.lineTo(cx + w * 0.20, h * 0.91);
    body.lineTo(cx + w * 0.14, h * 0.88);
    body.quadraticBezierTo(cx + w * 0.16, h * 0.84, cx + w * 0.18, h * 0.78);
    body.quadraticBezierTo(cx + w * 0.20, h * 0.70, cx + w * 0.20, h * 0.63);
    body.quadraticBezierTo(cx + w * 0.24, h * 0.52, cx + w * 0.22, h * 0.45);
    body.quadraticBezierTo(cx + w * 0.17, h * 0.40, cx + w * 0.17, h * 0.36);
    body.quadraticBezierTo(cx + w * 0.20, h * 0.28, rPit.dx, rPit.dy);
    body.quadraticBezierTo(cx + w * 0.28, h * 0.18, rSh.dx, rSh.dy);
    body.quadraticBezierTo(cx + w * 0.10, h * 0.13, cx + w * 0.08, h * 0.085);
    body.close();

    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    // ── Left arm ──
    final lArm = Path()..moveTo(lSh.dx, lSh.dy);
    lArm.quadraticBezierTo(cx - w * 0.38, h * 0.20, cx - w * 0.40, h * 0.30);
    lArm.quadraticBezierTo(cx - w * 0.42, h * 0.37, cx - w * 0.40, h * 0.43);
    lArm.quadraticBezierTo(cx - w * 0.38, h * 0.46, cx - w * 0.34, h * 0.43);
    lArm.quadraticBezierTo(cx - w * 0.34, h * 0.36, cx - w * 0.32, h * 0.28);
    lArm.quadraticBezierTo(cx - w * 0.28, h * 0.22, lPit.dx, lPit.dy);
    lArm.close();
    canvas.drawPath(lArm, fill);
    canvas.drawPath(lArm, stroke);

    // ── Right arm ──
    final rArm = Path()..moveTo(rSh.dx, rSh.dy);
    rArm.quadraticBezierTo(cx + w * 0.38, h * 0.20, cx + w * 0.40, h * 0.30);
    rArm.quadraticBezierTo(cx + w * 0.42, h * 0.37, cx + w * 0.40, h * 0.43);
    rArm.quadraticBezierTo(cx + w * 0.38, h * 0.46, cx + w * 0.34, h * 0.43);
    rArm.quadraticBezierTo(cx + w * 0.34, h * 0.36, cx + w * 0.32, h * 0.28);
    rArm.quadraticBezierTo(cx + w * 0.28, h * 0.22, rPit.dx, rPit.dy);
    rArm.close();
    canvas.drawPath(rArm, fill);
    canvas.drawPath(rArm, stroke);

    // ── Back view detail: spine + shoulder blade lines ──
    if (isBack) {
      final detail = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      // Spine
      canvas.drawLine(Offset(cx, h * 0.09), Offset(cx, h * 0.44), detail);
      // Shoulder blades
      canvas.drawLine(
        Offset(cx - w * 0.12, h * 0.20),
        Offset(cx - w * 0.06, h * 0.28),
        detail,
      );
      canvas.drawLine(
        Offset(cx + w * 0.12, h * 0.20),
        Offset(cx + w * 0.06, h * 0.28),
        detail,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) =>
      oldDelegate.isBack != isBack;
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
