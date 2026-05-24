import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

enum RecapAnatomyView { front, back }

class RecapAnatomyZone {
  final String id;
  final RecapAnatomyView view;
  final String spanishLabel;
  final String englishLabel;

  const RecapAnatomyZone({
    required this.id,
    required this.view,
    required this.spanishLabel,
    required this.englishLabel,
  });

  String label(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return languageCode == 'en' ? englishLabel : spanishLabel;
  }

  static RecapAnatomyZone? fromId(String id) => _zonesById[id];

  static const values = <RecapAnatomyZone>[
    RecapAnatomyZone(
      id: 'neck_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Cuello',
      englishLabel: 'Neck',
    ),
    RecapAnatomyZone(
      id: 'shoulder_left_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Hombro izquierdo',
      englishLabel: 'Left shoulder',
    ),
    RecapAnatomyZone(
      id: 'shoulder_right_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Hombro derecho',
      englishLabel: 'Right shoulder',
    ),
    RecapAnatomyZone(
      id: 'chest_left',
      view: RecapAnatomyView.front,
      spanishLabel: 'Pectoral izquierdo',
      englishLabel: 'Left chest',
    ),
    RecapAnatomyZone(
      id: 'chest_right',
      view: RecapAnatomyView.front,
      spanishLabel: 'Pectoral derecho',
      englishLabel: 'Right chest',
    ),
    RecapAnatomyZone(
      id: 'biceps_left',
      view: RecapAnatomyView.front,
      spanishLabel: 'Biceps izquierdo',
      englishLabel: 'Left biceps',
    ),
    RecapAnatomyZone(
      id: 'biceps_right',
      view: RecapAnatomyView.front,
      spanishLabel: 'Biceps derecho',
      englishLabel: 'Right biceps',
    ),
    RecapAnatomyZone(
      id: 'forearm_left_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Antebrazo izquierdo',
      englishLabel: 'Left forearm',
    ),
    RecapAnatomyZone(
      id: 'forearm_right_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Antebrazo derecho',
      englishLabel: 'Right forearm',
    ),
    RecapAnatomyZone(
      id: 'abdomen',
      view: RecapAnatomyView.front,
      spanishLabel: 'Abdomen',
      englishLabel: 'Abdomen',
    ),
    RecapAnatomyZone(
      id: 'hip_flexors',
      view: RecapAnatomyView.front,
      spanishLabel: 'Flexores de cadera',
      englishLabel: 'Hip flexors',
    ),
    RecapAnatomyZone(
      id: 'quadriceps_left',
      view: RecapAnatomyView.front,
      spanishLabel: 'Cuadriceps izquierdo',
      englishLabel: 'Left quadriceps',
    ),
    RecapAnatomyZone(
      id: 'quadriceps_right',
      view: RecapAnatomyView.front,
      spanishLabel: 'Cuadriceps derecho',
      englishLabel: 'Right quadriceps',
    ),
    RecapAnatomyZone(
      id: 'shin_left',
      view: RecapAnatomyView.front,
      spanishLabel: 'Tibia izquierda',
      englishLabel: 'Left shin',
    ),
    RecapAnatomyZone(
      id: 'shin_right',
      view: RecapAnatomyView.front,
      spanishLabel: 'Tibia derecha',
      englishLabel: 'Right shin',
    ),
    RecapAnatomyZone(
      id: 'neck_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Cuello',
      englishLabel: 'Neck',
    ),
    RecapAnatomyZone(
      id: 'traps_upper',
      view: RecapAnatomyView.back,
      spanishLabel: 'Trapecios',
      englishLabel: 'Upper traps',
    ),
    RecapAnatomyZone(
      id: 'shoulder_left_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Hombro izquierdo',
      englishLabel: 'Left shoulder',
    ),
    RecapAnatomyZone(
      id: 'shoulder_right_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Hombro derecho',
      englishLabel: 'Right shoulder',
    ),
    RecapAnatomyZone(
      id: 'triceps_left',
      view: RecapAnatomyView.back,
      spanishLabel: 'Triceps izquierdo',
      englishLabel: 'Left triceps',
    ),
    RecapAnatomyZone(
      id: 'triceps_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Triceps derecho',
      englishLabel: 'Right triceps',
    ),
    RecapAnatomyZone(
      id: 'forearm_left_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Antebrazo izquierdo',
      englishLabel: 'Left forearm',
    ),
    RecapAnatomyZone(
      id: 'forearm_right_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Antebrazo derecho',
      englishLabel: 'Right forearm',
    ),
    RecapAnatomyZone(
      id: 'lats_left',
      view: RecapAnatomyView.back,
      spanishLabel: 'Dorsal izquierdo',
      englishLabel: 'Left lat',
    ),
    RecapAnatomyZone(
      id: 'lats_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Dorsal derecho',
      englishLabel: 'Right lat',
    ),
    RecapAnatomyZone(
      id: 'upper_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Espalda alta',
      englishLabel: 'Upper back',
    ),
    RecapAnatomyZone(
      id: 'lower_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Lumbar',
      englishLabel: 'Lower back',
    ),
    RecapAnatomyZone(
      id: 'glutes_left',
      view: RecapAnatomyView.back,
      spanishLabel: 'Gluteo izquierdo',
      englishLabel: 'Left glute',
    ),
    RecapAnatomyZone(
      id: 'glutes_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Gluteo derecho',
      englishLabel: 'Right glute',
    ),
    RecapAnatomyZone(
      id: 'hamstrings_left',
      view: RecapAnatomyView.back,
      spanishLabel: 'Isquio izquierdo',
      englishLabel: 'Left hamstring',
    ),
    RecapAnatomyZone(
      id: 'hamstrings_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Isquio derecho',
      englishLabel: 'Right hamstring',
    ),
    RecapAnatomyZone(
      id: 'calves_left',
      view: RecapAnatomyView.back,
      spanishLabel: 'Gemelo izquierdo',
      englishLabel: 'Left calf',
    ),
    RecapAnatomyZone(
      id: 'calves_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Gemelo derecho',
      englishLabel: 'Right calf',
    ),
  ];
}

final _zonesById = <String, RecapAnatomyZone>{
  for (final zone in RecapAnatomyZone.values) zone.id: zone,
};

class RecapAnatomySelector extends StatefulWidget {
  final Set<String> selectedZoneIds;
  final ValueChanged<String> onZoneSelected;
  final double height;

  const RecapAnatomySelector({
    super.key,
    required this.selectedZoneIds,
    required this.onZoneSelected,
    this.height = 440,
  });

  @override
  State<RecapAnatomySelector> createState() => _RecapAnatomySelectorState();
}

class _RecapAnatomySelectorState extends State<RecapAnatomySelector> {
  static const double _toggleHeight = 40;
  static const double _toggleSpacing = 12;

  var _view = RecapAnatomyView.front;

  double get _bodyHeight => widget.height - _toggleHeight - _toggleSpacing;

  double get _bodyWidth => _bodyHeight * (_kViewBoxW / _kViewBoxH);

  void _handleTap(TapDownDetails details) {
    final svgX = details.localPosition.dx * _kViewBoxW / _bodyWidth;
    final svgY = details.localPosition.dy * _kViewBoxH / _bodyHeight;
    final tapPoint = Offset(svgX, svgY);
    final zones = _view == RecapAnatomyView.front
        ? _PathCache.frontZones
        : _PathCache.backZones;

    for (final entry in zones.entries) {
      if (entry.value.contains(tapPoint)) {
        HapticFeedback.selectionClick();
        widget.onZoneSelected(entry.key);
        return;
      }
    }
  }

  Widget _buildViewTab({
    required BuildContext context,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final palette = context.exomPalette;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: _toggleHeight,
          alignment: Alignment.center,
          decoration: active
              ? GlassDecoration.accentCard(palette.primary, borderRadius: 12)
              : const BoxDecoration(),
          child: Text(
            label,
            style: TextStyle(
              color: active ? palette.primary : palette.textDisabled,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: _bodyWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: _handleTap,
            child: SizedBox(
              width: _bodyWidth,
              height: _bodyHeight,
              child: CustomPaint(
                size: Size(_bodyWidth, _bodyHeight),
                painter: _RecapAnatomyPainter(
                  view: _view,
                  selectedZoneIds: widget.selectedZoneIds,
                  palette: palette,
                ),
              ),
            ),
          ),
          const SizedBox(height: _toggleSpacing),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: GlassDecoration.card(
              borderRadius: 14,
              borderColor: palette.glassBorder.withValues(alpha: 0.12),
            ),
            child: Row(
              children: [
                _buildViewTab(
                  context: context,
                  label: l10n.frontViewLabel,
                  active: _view == RecapAnatomyView.front,
                  onTap: () => setState(() => _view = RecapAnatomyView.front),
                ),
                const SizedBox(width: 4),
                _buildViewTab(
                  context: context,
                  label: l10n.backViewLabel,
                  active: _view == RecapAnatomyView.back,
                  onTap: () => setState(() => _view = RecapAnatomyView.back),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const double _kViewBoxW = 320;
const double _kViewBoxH = 760;

class _PathCache {
  _PathCache._();

  static final silhouetteBase = <Path>[
    _parseSvgPath(_RecapPathData.head),
    _parseSvgPath(_RecapPathData.bodyOutline),
  ];

  static final frontZones = <String, Path>{
    for (final entry in _RecapPathData.frontZones.entries)
      entry.key: _parseSvgPath(entry.value),
  };

  static final backZones = <String, Path>{
    for (final entry in _RecapPathData.backZones.entries)
      entry.key: _parseSvgPath(entry.value),
  };
}

class _RecapAnatomyPainter extends CustomPainter {
  final RecapAnatomyView view;
  final Set<String> selectedZoneIds;
  final ExomThemePalette palette;

  const _RecapAnatomyPainter({
    required this.view,
    required this.selectedZoneIds,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _kViewBoxW;
    final scaleY = size.height / _kViewBoxH;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final baseFill = Paint()
      ..color = palette.textSecondary.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = palette.textSecondary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    for (final path in _PathCache.silhouetteBase) {
      canvas.drawPath(path, baseFill);
      canvas.drawPath(path, baseStroke);
    }

    final defaultFill = Paint()
      ..color = palette.textSecondary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final defaultStroke = Paint()
      ..color = palette.textSecondary.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;
    final selectedFill = Paint()
      ..color = palette.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final selectedStroke = Paint()
      ..color = palette.primary.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    final zones = view == RecapAnatomyView.front
        ? _PathCache.frontZones
        : _PathCache.backZones;

    for (final entry in zones.entries) {
      final isSelected = selectedZoneIds.contains(entry.key);
      canvas.drawPath(entry.value, isSelected ? selectedFill : defaultFill);
      canvas.drawPath(entry.value, isSelected ? selectedStroke : defaultStroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RecapAnatomyPainter oldDelegate) =>
      oldDelegate.view != view ||
      !_setsEqual(oldDelegate.selectedZoneIds, selectedZoneIds) ||
      oldDelegate.palette != palette;
}

bool _setsEqual<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

Path _parseSvgPath(String d) {
  final tokens = RegExp(
    r'[MCLZmclz]|[-+]?[0-9]*\.?[0-9]+',
  ).allMatches(d).map((match) => match.group(0)!).toList();
  final path = ui.Path();

  var index = 0;
  String? command;

  double nextNumber() => double.parse(tokens[index++]);

  while (index < tokens.length) {
    final token = tokens[index];
    if (RegExp(r'^[MCLZmclz]$').hasMatch(token)) {
      command = token.toUpperCase();
      index++;
      if (command == 'Z') {
        path.close();
        continue;
      }
    }

    switch (command) {
      case 'M':
        path.moveTo(nextNumber(), nextNumber());
        command = 'L';
        break;
      case 'L':
        path.lineTo(nextNumber(), nextNumber());
        break;
      case 'C':
        path.cubicTo(
          nextNumber(),
          nextNumber(),
          nextNumber(),
          nextNumber(),
          nextNumber(),
          nextNumber(),
        );
        break;
      default:
        throw FormatException('Unsupported SVG path command: $command');
    }
  }

  return path;
}

class _RecapPathData {
  _RecapPathData._();

  static const head =
      'M160 38 C143 38 131 50 131 68 C131 85 143 97 160 97 '
      'C177 97 189 85 189 68 C189 50 177 38 160 38 Z';

  static const bodyOutline =
      'M128 104 C120 104 114 108 110 116 C103 130 91 140 80 149 '
      'C69 159 64 176 64 198 C64 225 68 254 74 286 '
      'C78 308 82 329 84 350 C85 362 91 370 99 372 '
      'C107 374 114 369 118 359 C123 345 126 329 128 312 '
      'C131 289 135 269 141 253 C145 242 151 236 160 236 '
      'C169 236 175 242 179 253 C185 269 189 289 192 312 '
      'C194 329 197 345 202 359 C206 369 213 374 221 372 '
      'C229 370 235 362 236 350 C238 329 242 308 246 286 '
      'C252 254 256 225 256 198 C256 176 251 159 240 149 '
      'C229 140 217 130 210 116 C206 108 200 104 192 104 '
      'C183 104 176 109 172 118 C169 124 165 127 160 127 '
      'C155 127 151 124 148 118 C144 109 137 104 128 104 Z '
      'M136 258 C130 281 126 305 122 330 C117 357 113 386 109 416 '
      'C105 443 102 472 102 502 C102 531 106 561 112 592 '
      'C117 616 121 642 123 668 C124 681 133 691 146 693 '
      'C154 694 160 689 160 681 C160 689 166 694 174 693 '
      'C187 691 196 681 197 668 C199 642 203 616 208 592 '
      'C214 561 218 531 218 502 C218 472 215 443 211 416 '
      'C207 386 203 357 198 330 C194 305 190 281 184 258 '
      'C180 244 172 236 160 236 C148 236 140 244 136 258 Z';

  static const frontZones = <String, String>{
    'neck_front':
        'M146 96 C146 88 152 83 160 83 C168 83 174 88 174 96 '
        'L174 126 C174 134 168 140 160 140 C152 140 146 134 146 126 Z',
    'shoulder_left_front':
        'M91 148 C97 131 111 119 130 117 L148 117 '
        'C150 128 146 139 137 147 C127 157 115 165 101 169 '
        'C92 171 87 160 91 148 Z',
    'shoulder_right_front':
        'M229 148 C223 131 209 119 190 117 L172 117 '
        'C170 128 174 139 183 147 C193 157 205 165 219 169 '
        'C228 171 233 160 229 148 Z',
    'chest_left':
        'M114 159 C118 145 130 138 146 137 L160 137 L160 237 '
        'C151 237 143 235 136 231 C123 225 116 215 113 201 '
        'C110 186 110 172 114 159 Z',
    'chest_right':
        'M206 159 C202 145 190 138 174 137 L160 137 L160 237 '
        'C169 237 177 235 184 231 C197 225 204 215 207 201 '
        'C210 186 210 172 206 159 Z',
    'biceps_left':
        'M86 160 C95 154 105 157 113 165 C121 174 124 188 122 203 '
        'C120 225 115 247 107 266 C103 276 95 282 86 281 '
        'C77 280 71 273 69 261 C65 238 65 215 68 193 '
        'C70 178 76 166 86 160 Z',
    'biceps_right':
        'M234 160 C225 154 215 157 207 165 C199 174 196 188 198 203 '
        'C200 225 205 247 213 266 C217 276 225 282 234 281 '
        'C243 280 249 273 251 261 C255 238 255 215 252 193 '
        'C250 178 244 166 234 160 Z',
    'forearm_left_front':
        'M72 277 C80 272 88 272 96 276 C103 281 107 290 106 301 '
        'C105 324 102 347 97 368 C94 381 87 389 78 390 '
        'C69 391 62 385 59 373 C55 350 55 327 57 304 '
        'C59 291 64 282 72 277 Z',
    'forearm_right_front':
        'M248 277 C240 272 232 272 224 276 C217 281 213 290 214 301 '
        'C215 324 218 347 223 368 C226 381 233 389 242 390 '
        'C251 391 258 385 261 373 C265 350 265 327 263 304 '
        'C261 291 256 282 248 277 Z',
    'abdomen':
        'M128 232 C137 226 148 223 160 223 C172 223 183 226 192 232 '
        'C200 239 204 250 203 263 C203 280 198 294 188 304 '
        'C181 312 171 316 160 316 C149 316 139 312 132 304 '
        'C122 294 117 280 117 263 C116 250 120 239 128 232 Z',
    'hip_flexors':
        'M119 306 C131 297 145 293 160 293 C175 293 189 297 201 306 '
        'C211 315 216 329 215 344 C214 361 207 374 196 383 '
        'C184 391 171 394 160 394 C149 394 136 391 124 383 '
        'C113 374 106 361 105 344 C104 329 109 315 119 306 Z',
    'quadriceps_left':
        'M114 375 C126 366 139 364 149 369 C156 374 160 384 160 398 '
        'L160 492 C160 506 153 518 142 524 C131 530 119 528 110 519 '
        'C101 510 96 497 95 482 C94 447 99 414 105 384 '
        'C107 380 110 377 114 375 Z',
    'quadriceps_right':
        'M206 375 C194 366 181 364 171 369 C164 374 160 384 160 398 '
        'L160 492 C160 506 167 518 178 524 C189 530 201 528 210 519 '
        'C219 510 224 497 225 482 C226 447 221 414 215 384 '
        'C213 380 210 377 206 375 Z',
    'shin_left':
        'M110 524 C120 516 132 513 142 516 C151 519 156 528 156 540 '
        'C156 572 153 604 149 638 C147 653 139 662 128 665 '
        'C117 667 108 661 104 649 C97 628 93 605 93 580 '
        'C93 557 98 538 110 524 Z',
    'shin_right':
        'M210 524 C200 516 188 513 178 516 C169 519 164 528 164 540 '
        'C164 572 167 604 171 638 C173 653 181 662 192 665 '
        'C203 667 212 661 216 649 C223 628 227 605 227 580 '
        'C227 557 222 538 210 524 Z',
  };

  static const backZones = <String, String>{
    'neck_back':
        'M145 96 C145 88 151 83 160 83 C169 83 175 88 175 96 '
        'L175 129 C175 137 169 143 160 143 C151 143 145 137 145 129 Z',
    'traps_upper':
        'M116 122 C128 116 143 116 151 126 C154 132 157 136 160 136 '
        'C163 136 166 132 169 126 C177 116 192 116 204 122 '
        'C212 127 218 137 222 151 C205 163 185 169 160 169 '
        'C135 169 115 163 98 151 C102 137 108 127 116 122 Z',
    'shoulder_left_back':
        'M90 148 C96 130 111 119 130 117 L145 118 '
        'C147 131 141 145 129 155 C120 163 110 168 100 170 '
        'C91 171 86 159 90 148 Z',
    'shoulder_right_back':
        'M230 148 C224 130 209 119 190 117 L175 118 '
        'C173 131 179 145 191 155 C200 163 210 168 220 170 '
        'C229 171 234 159 230 148 Z',
    'triceps_left':
        'M86 161 C95 156 104 158 111 166 C119 175 122 187 121 201 '
        'C120 223 115 244 107 263 C103 274 95 280 86 279 '
        'C77 278 71 272 69 260 C65 237 65 215 68 193 '
        'C70 179 77 167 86 161 Z',
    'triceps_right':
        'M234 161 C225 156 216 158 209 166 C201 175 198 187 199 201 '
        'C200 223 205 244 213 263 C217 274 225 280 234 279 '
        'C243 278 249 272 251 260 C255 237 255 215 252 193 '
        'C250 179 243 167 234 161 Z',
    'forearm_left_back':
        'M72 276 C80 271 88 271 96 275 C103 280 107 289 106 300 '
        'C105 323 102 345 97 366 C94 380 87 388 78 389 '
        'C69 390 62 384 59 372 C55 350 55 327 57 304 '
        'C59 290 64 281 72 276 Z',
    'forearm_right_back':
        'M248 276 C240 271 232 271 224 275 C217 280 213 289 214 300 '
        'C215 323 218 345 223 366 C226 380 233 388 242 389 '
        'C251 390 258 384 261 372 C265 350 265 327 263 304 '
        'C261 290 256 281 248 276 Z',
    'lats_left':
        'M119 164 C130 169 143 171 160 171 L160 292 '
        'C148 292 137 288 129 280 C119 270 114 256 113 240 '
        'C112 216 114 190 119 164 Z',
    'lats_right':
        'M201 164 C190 169 177 171 160 171 L160 292 '
        'C172 292 183 288 191 280 C201 270 206 256 207 240 '
        'C208 216 206 190 201 164 Z',
    'upper_back':
        'M128 166 C138 170 149 172 160 172 C171 172 182 170 192 166 '
        'C198 183 201 201 201 220 C201 236 196 248 187 256 '
        'C180 262 170 265 160 265 C150 265 140 262 133 256 '
        'C124 248 119 236 119 220 C119 201 122 183 128 166 Z',
    'lower_back':
        'M127 252 C136 260 147 264 160 264 C173 264 184 260 193 252 '
        'C201 262 205 275 205 291 C205 307 200 320 190 329 '
        'C182 337 171 341 160 341 C149 341 138 337 130 329 '
        'C120 320 115 307 115 291 C115 275 119 262 127 252 Z',
    'glutes_left':
        'M116 315 C128 307 144 303 160 306 L160 389 '
        'C147 389 134 385 123 378 C111 369 104 356 103 340 '
        'C102 329 107 321 116 315 Z',
    'glutes_right':
        'M204 315 C192 307 176 303 160 306 L160 389 '
        'C173 389 186 385 197 378 C209 369 216 356 217 340 '
        'C218 329 213 321 204 315 Z',
    'hamstrings_left':
        'M113 379 C125 370 138 368 148 373 C156 378 160 388 160 402 '
        'L160 495 C160 508 154 519 142 525 C130 531 118 530 109 520 '
        'C100 511 94 499 93 483 C92 448 97 416 103 386 '
        'C105 383 109 381 113 379 Z',
    'hamstrings_right':
        'M207 379 C195 370 182 368 172 373 C164 378 160 388 160 402 '
        'L160 495 C160 508 166 519 178 525 C190 531 202 530 211 520 '
        'C220 511 226 499 227 483 C228 448 223 416 217 386 '
        'C215 383 211 381 207 379 Z',
    'calves_left':
        'M108 524 C118 516 130 513 141 516 C150 519 156 528 156 540 '
        'C156 572 153 605 149 639 C147 654 139 664 127 667 '
        'C116 669 107 663 102 651 C95 630 91 606 91 580 '
        'C91 557 97 539 108 524 Z',
    'calves_right':
        'M212 524 C202 516 190 513 179 516 C170 519 164 528 164 540 '
        'C164 572 167 605 171 639 C173 654 181 664 193 667 '
        'C204 669 213 663 218 651 C225 630 229 606 229 580 '
        'C229 557 223 539 212 524 Z',
  };
}
