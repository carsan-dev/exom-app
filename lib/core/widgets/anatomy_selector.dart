import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Interactive anatomical body selector that renders SVG-based body zones.
///
/// Supports single-select via [selectedZone] and multi-select via
/// [selectedZones]. Front/back view switching is handled internally.
class AnatomySelector extends StatefulWidget {
  /// Currently selected zone in single-select mode.
  final BodyZone? selectedZone;

  /// Currently selected zones (multi-select mode).
  final Set<BodyZone> selectedZones;

  /// Called when the user taps a body zone.
  final ValueChanged<BodyZone> onZoneSelected;

  /// Whether the selector is being used in multi-select mode.
  final bool multiSelect;

  /// Total height of the body visualization.
  final double height;

  const AnatomySelector({
    super.key,
    this.selectedZone,
    this.selectedZones = const {},
    required this.onZoneSelected,
    this.multiSelect = false,
    this.height = 440,
  });

  @override
  State<AnatomySelector> createState() => _AnatomySelectorState();
}

class _AnatomySelectorState extends State<AnatomySelector> {
  static const double _toggleHeight = 40;
  static const double _toggleSpacing = 12;

  bool _isFront = true;

  double get _bodyHeight => widget.height - _toggleHeight - _toggleSpacing;

  double get _bodyWidth => _bodyHeight * (_kViewBoxW / _kViewBoxH);

  Set<String> get _selectedSvgIds {
    final ids = <String>{};
    if (widget.selectedZone != null) {
      ids.addAll(widget.selectedZone!.svgIds);
    }
    for (final zone in widget.selectedZones) {
      ids.addAll(zone.svgIds);
    }
    return ids;
  }

  void _handleTap(TapDownDetails details) {
    final svgX = details.localPosition.dx * _kViewBoxW / _bodyWidth;
    final svgY = details.localPosition.dy * _kViewBoxH / _bodyHeight;
    final tapPoint = Offset(svgX, svgY);

    final zones = _isFront ? _PathCache.frontZones : _PathCache.backZones;

    for (final entry in zones.entries) {
      if (entry.value.contains(tapPoint)) {
        final zone = BodyZone.fromSvgId(entry.key);
        if (zone != null) {
          HapticFeedback.selectionClick();
          widget.onZoneSelected(zone);
          return;
        }
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
    final selectedIds = _selectedSvgIds;

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
                painter: _AnatomyPainter(
                  isFront: _isFront,
                  selectedSvgIds: selectedIds,
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
                  active: _isFront,
                  onTap: () => setState(() => _isFront = true),
                ),
                const SizedBox(width: 4),
                _buildViewTab(
                  context: context,
                  label: l10n.backViewLabel,
                  active: !_isFront,
                  onTap: () => setState(() => _isFront = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Constants ────────────────────────────────────────────────────────────────

const double _kViewBoxW = 320;
const double _kViewBoxH = 760;

// ── Path Cache (lazy, computed once) ─────────────────────────────────────────

class _PathCache {
  _PathCache._();

  static final headPath = _parseSvgPath(_BodyPathData.head);
  static final bodyPath = _parseSvgPath(_BodyPathData.bodyOutline);

  static final frontZones = <String, Path>{
    for (final e in _BodyPathData.frontZones.entries)
      e.key: _parseSvgPath(e.value),
  };

  static final backZones = <String, Path>{
    for (final e in _BodyPathData.backZones.entries)
      e.key: _parseSvgPath(e.value),
  };
}

// ── Custom Painter ──────────────────────────────────────────────────────────

class _AnatomyPainter extends CustomPainter {
  final bool isFront;
  final Set<String> selectedSvgIds;
  final ExomThemePalette palette;

  const _AnatomyPainter({
    required this.isFront,
    required this.selectedSvgIds,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _kViewBoxW;
    final scaleY = size.height / _kViewBoxH;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // ── 1. Silhouette base ──
    final baseFill = Paint()
      ..color = palette.textSecondary.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = palette.textSecondary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(_PathCache.headPath, baseFill);
    canvas.drawPath(_PathCache.headPath, baseStroke);
    canvas.drawPath(_PathCache.bodyPath, baseFill);
    canvas.drawPath(_PathCache.bodyPath, baseStroke);

    // ── 2. Interactive zones ──
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

    final zones = isFront ? _PathCache.frontZones : _PathCache.backZones;

    for (final entry in zones.entries) {
      final isSelected = selectedSvgIds.contains(entry.key);
      canvas.drawPath(entry.value, isSelected ? selectedFill : defaultFill);
      canvas.drawPath(entry.value, isSelected ? selectedStroke : defaultStroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnatomyPainter oldDelegate) =>
      oldDelegate.isFront != isFront ||
      !_setsEqual(oldDelegate.selectedSvgIds, selectedSvgIds) ||
      oldDelegate.palette != palette;
}

bool _setsEqual<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

// ── Minimal SVG Path Parser ─────────────────────────────────────────────────
//
// Handles only the commands used in our SVGs: M, C, L, Z (all absolute).

Path _parseSvgPath(String d) {
  final tokens = RegExp(
    r'[MCLZmclz]|[-+]?[0-9]*\.?[0-9]+',
  ).allMatches(d).map((m) => m.group(0)!).toList();
  final path = ui.Path();

  var i = 0;
  String? command;

  double nextNumber() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    final token = tokens[i];
    if (RegExp(r'^[MCLZmclz]$').hasMatch(token)) {
      command = token.toUpperCase();
      i++;
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

// ── SVG Path Data ───────────────────────────────────────────────────────────
//
// Extracted from body_front.svg and body_back.svg (viewBox 0 0 320 760).
// These strings are the `d` attributes of each <path> element.

class _BodyPathData {
  _BodyPathData._();

  // ── Silhouette base (shared between front & back) ──

  static const head =
      'M160 38 C143 38 131 50 131 68'
      ' C131 85 143 97 160 97'
      ' C177 97 189 85 189 68'
      ' C189 50 177 38 160 38 Z';

  static const bodyOutline =
      'M128 104 C120 104 114 108 110 116'
      ' C103 130 91 140 80 149'
      ' C69 159 64 176 64 198'
      ' C64 225 68 254 74 286'
      ' C78 308 82 329 84 350'
      ' C85 362 91 370 99 372'
      ' C107 374 114 369 118 359'
      ' C123 345 126 329 128 312'
      ' C131 289 135 269 141 253'
      ' C145 242 151 236 160 236'
      ' C169 236 175 242 179 253'
      ' C185 269 189 289 192 312'
      ' C194 329 197 345 202 359'
      ' C206 369 213 374 221 372'
      ' C229 370 235 362 236 350'
      ' C238 329 242 308 246 286'
      ' C252 254 256 225 256 198'
      ' C256 176 251 159 240 149'
      ' C229 140 217 130 210 116'
      ' C206 108 200 104 192 104'
      ' C183 104 176 109 172 118'
      ' C169 124 165 127 160 127'
      ' C155 127 151 124 148 118'
      ' C144 109 137 104 128 104 Z'
      ' M136 258 C130 281 126 305 122 330'
      ' C117 357 113 386 109 416'
      ' C105 443 102 472 102 502'
      ' C102 531 106 561 112 592'
      ' C117 616 121 642 123 668'
      ' C124 681 133 691 146 693'
      ' C154 694 160 689 160 681'
      ' C160 689 166 694 174 693'
      ' C187 691 196 681 197 668'
      ' C199 642 203 616 208 592'
      ' C214 561 218 531 218 502'
      ' C218 472 215 443 211 416'
      ' C207 386 203 357 198 330'
      ' C194 305 190 281 184 258'
      ' C180 244 172 236 160 236'
      ' C148 236 140 244 136 258 Z';

  // ── Front interactive zones ──

  static const frontZones = <String, String>{
    'neck_center_front':
        'M146 98 C146 89 152 84 160 84'
        ' C168 84 174 89 174 98'
        ' L174 125 C174 132 168 137 160 137'
        ' C152 137 146 132 146 125 Z',
    'shoulder_center_front':
        'M92 149 C97 132 111 120 129 118'
        ' L145 118 C148 124 153 127 160 127'
        ' C167 127 172 124 175 118'
        ' L191 118 C209 120 223 132 228 149'
        ' C231 158 227 164 218 167'
        ' L102 167 C93 164 89 158 92 149 Z',
    'chest_center_front':
        'M114 158 C118 146 129 139 143 137'
        ' L177 137 C191 139 202 146 206 158'
        ' C210 172 210 187 207 201'
        ' C204 216 196 226 183 232'
        ' C176 235 168 237 160 237'
        ' C152 237 144 235 137 232'
        ' C124 226 116 216 113 201'
        ' C110 187 110 172 114 158 Z',
    'upper_arm_left_front':
        'M87 160 C95 155 104 157 111 164'
        ' C119 172 123 184 122 198'
        ' C121 221 116 243 108 264'
        ' C104 275 96 281 87 281'
        ' C78 281 71 274 69 262'
        ' C65 238 65 215 68 192'
        ' C70 178 77 166 87 160 Z',
    'upper_arm_right_front':
        'M233 160 C225 155 216 157 209 164'
        ' C201 172 197 184 198 198'
        ' C199 221 204 243 212 264'
        ' C216 275 224 281 233 281'
        ' C242 281 249 274 251 262'
        ' C255 238 255 215 252 192'
        ' C250 178 243 166 233 160 Z',
    'forearm_left_front':
        'M72 277 C79 272 87 271 95 275'
        ' C102 280 106 288 106 299'
        ' C105 322 102 345 97 367'
        ' C94 380 87 388 78 390'
        ' C69 391 62 385 59 373'
        ' C55 350 55 327 57 304'
        ' C59 291 64 282 72 277 Z',
    'forearm_right_front':
        'M248 277 C241 272 233 271 225 275'
        ' C218 280 214 288 214 299'
        ' C215 322 218 345 223 367'
        ' C226 380 233 388 242 390'
        ' C251 391 258 385 261 373'
        ' C265 350 265 327 263 304'
        ' C261 291 256 282 248 277 Z',
    'waist_center_front':
        'M128 233 C137 228 148 225 160 225'
        ' C172 225 183 228 192 233'
        ' C199 239 202 249 202 261'
        ' C202 276 197 289 188 298'
        ' C181 305 171 309 160 309'
        ' C149 309 139 305 132 298'
        ' C123 289 118 276 118 261'
        ' C118 249 121 239 128 233 Z',
    'hips_center_front':
        'M121 300 C132 292 146 288 160 288'
        ' C174 288 188 292 199 300'
        ' C209 309 214 322 214 337'
        ' C214 351 208 362 198 370'
        ' C188 378 175 383 160 383'
        ' C145 383 132 378 122 370'
        ' C112 362 106 351 106 337'
        ' C106 322 111 309 121 300 Z',
    'thigh_left_front':
        'M116 374 C127 366 139 364 148 369'
        ' C156 374 160 383 160 397'
        ' L160 492 C160 505 154 516 143 522'
        ' C132 528 120 527 111 518'
        ' C102 509 96 497 95 482'
        ' C94 447 99 414 105 383'
        ' C107 379 111 376 116 374 Z',
    'thigh_right_front':
        'M204 374 C193 366 181 364 172 369'
        ' C164 374 160 383 160 397'
        ' L160 492 C160 505 166 516 177 522'
        ' C188 528 200 527 209 518'
        ' C218 509 224 497 225 482'
        ' C226 447 221 414 215 383'
        ' C213 379 209 376 204 374 Z',
    'calf_left_front':
        'M111 523 C120 515 132 512 142 515'
        ' C151 518 156 526 156 538'
        ' C156 570 153 603 149 637'
        ' C147 652 139 661 128 664'
        ' C117 666 109 660 104 649'
        ' C97 628 93 605 93 580'
        ' C93 557 98 538 111 523 Z',
    'calf_right_front':
        'M209 523 C200 515 188 512 178 515'
        ' C169 518 164 526 164 538'
        ' C164 570 167 603 171 637'
        ' C173 652 181 661 192 664'
        ' C203 666 211 660 216 649'
        ' C223 628 227 605 227 580'
        ' C227 557 222 538 209 523 Z',
  };

  // ── Back interactive zones ──

  static const backZones = <String, String>{
    'neck_center_back':
        'M145 98 C145 89 151 84 160 84'
        ' C169 84 175 89 175 98'
        ' L175 128 C175 135 169 140 160 140'
        ' C151 140 145 135 145 128 Z',
    'shoulder_center_back':
        'M90 147 C96 129 111 118 130 116'
        ' L190 116 C209 118 224 129 230 147'
        ' C233 157 228 164 219 167'
        ' L101 167 C92 164 87 157 90 147 Z',
    'upper_arm_left_back':
        'M86 161 C94 156 103 158 110 165'
        ' C118 173 121 185 120 199'
        ' C119 221 114 242 107 262'
        ' C103 273 95 279 86 279'
        ' C77 279 71 272 69 260'
        ' C65 237 65 215 68 193'
        ' C70 179 77 167 86 161 Z',
    'upper_arm_right_back':
        'M234 161 C226 156 217 158 210 165'
        ' C202 173 199 185 200 199'
        ' C201 221 206 242 213 262'
        ' C217 273 225 279 234 279'
        ' C243 279 249 272 251 260'
        ' C255 237 255 215 252 193'
        ' C250 179 243 167 234 161 Z',
    'forearm_left_back':
        'M72 276 C79 271 87 270 95 274'
        ' C102 279 106 288 106 299'
        ' C105 321 102 343 97 365'
        ' C94 379 87 387 78 389'
        ' C69 390 62 384 59 372'
        ' C55 350 55 327 57 304'
        ' C59 290 64 281 72 276 Z',
    'forearm_right_back':
        'M248 276 C241 271 233 270 225 274'
        ' C218 279 214 288 214 299'
        ' C215 321 218 343 223 365'
        ' C226 379 233 387 242 389'
        ' C251 390 258 384 261 372'
        ' C265 350 265 327 263 304'
        ' C261 290 256 281 248 276 Z',
    'waist_center_back':
        'M124 226 C134 220 147 216 160 216'
        ' C173 216 186 220 196 226'
        ' C203 232 207 242 207 255'
        ' C207 269 202 282 193 292'
        ' C185 300 174 304 160 304'
        ' C146 304 135 300 127 292'
        ' C118 282 113 269 113 255'
        ' C113 242 117 232 124 226 Z',
    'hips_center_back':
        'M116 298 C128 290 143 286 160 286'
        ' C177 286 192 290 204 298'
        ' C214 307 220 320 220 336'
        ' C220 352 213 365 201 374'
        ' C190 382 175 387 160 387'
        ' C145 387 130 382 119 374'
        ' C107 365 100 352 100 336'
        ' C100 320 106 307 116 298 Z',
    'thigh_left_back':
        'M114 377 C125 369 138 367 148 372'
        ' C156 377 160 386 160 400'
        ' L160 494 C160 507 154 518 142 524'
        ' C130 530 118 529 109 520'
        ' C100 511 94 499 93 483'
        ' C92 447 97 415 103 385'
        ' C105 381 109 378 114 377 Z',
    'thigh_right_back':
        'M206 377 C195 369 182 367 172 372'
        ' C164 377 160 386 160 400'
        ' L160 494 C160 507 166 518 178 524'
        ' C190 530 202 529 211 520'
        ' C220 511 226 499 227 483'
        ' C228 447 223 415 217 385'
        ' C215 381 211 378 206 377 Z',
    'calf_left_back':
        'M108 524 C117 516 129 512 140 515'
        ' C150 518 156 526 156 539'
        ' C156 571 153 604 149 639'
        ' C147 654 139 664 127 667'
        ' C116 669 107 663 102 651'
        ' C95 630 91 606 91 580'
        ' C91 557 97 539 108 524 Z',
    'calf_right_back':
        'M212 524 C203 516 191 512 180 515'
        ' C170 518 164 526 164 539'
        ' C164 571 167 604 171 639'
        ' C173 654 181 664 193 667'
        ' C204 669 213 663 218 651'
        ' C225 630 229 606 229 580'
        ' C229 557 223 539 212 524 Z',
  };
}
