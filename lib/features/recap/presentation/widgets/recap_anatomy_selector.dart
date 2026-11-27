import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/l10n/app_localizations.dart';

part 'recap_anatomy_geometry.dart';

enum RecapAnatomyView { front, back }

/// How a measurable zone of a measure map is painted (L6-D2, «06 Medidas
/// corporales» of the metrics form): filled when it has data, outlined when
/// it has none. Zones without a mark are muted and inert in a measure map.
enum RecapZoneMark { withData, withoutData }

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
      spanishLabel: 'Cuello (delante)',
      englishLabel: 'Neck (front)',
    ),
    RecapAnatomyZone(
      id: 'shoulder_left_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Hombro izquierdo (delante)',
      englishLabel: 'Left shoulder (front)',
    ),
    RecapAnatomyZone(
      id: 'shoulder_right_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Hombro derecho (delante)',
      englishLabel: 'Right shoulder (front)',
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
      spanishLabel: 'Bíceps izquierdo',
      englishLabel: 'Left biceps',
    ),
    RecapAnatomyZone(
      id: 'biceps_right',
      view: RecapAnatomyView.front,
      spanishLabel: 'Bíceps derecho',
      englishLabel: 'Right biceps',
    ),
    RecapAnatomyZone(
      id: 'forearm_left_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Antebrazo izquierdo (delante)',
      englishLabel: 'Left forearm (front)',
    ),
    RecapAnatomyZone(
      id: 'forearm_right_front',
      view: RecapAnatomyView.front,
      spanishLabel: 'Antebrazo derecho (delante)',
      englishLabel: 'Right forearm (front)',
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
      spanishLabel: 'Cuádriceps izquierdo',
      englishLabel: 'Left quadriceps',
    ),
    RecapAnatomyZone(
      id: 'quadriceps_right',
      view: RecapAnatomyView.front,
      spanishLabel: 'Cuádriceps derecho',
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
      spanishLabel: 'Cuello (detrás)',
      englishLabel: 'Neck (back)',
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
      spanishLabel: 'Hombro izquierdo (detrás)',
      englishLabel: 'Left shoulder (back)',
    ),
    RecapAnatomyZone(
      id: 'shoulder_right_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Hombro derecho (detrás)',
      englishLabel: 'Right shoulder (back)',
    ),
    RecapAnatomyZone(
      id: 'triceps_left',
      view: RecapAnatomyView.back,
      spanishLabel: 'Tríceps izquierdo',
      englishLabel: 'Left triceps',
    ),
    RecapAnatomyZone(
      id: 'triceps_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Tríceps derecho',
      englishLabel: 'Right triceps',
    ),
    RecapAnatomyZone(
      id: 'forearm_left_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Antebrazo izquierdo (detrás)',
      englishLabel: 'Left forearm (back)',
    ),
    RecapAnatomyZone(
      id: 'forearm_right_back',
      view: RecapAnatomyView.back,
      spanishLabel: 'Antebrazo derecho (detrás)',
      englishLabel: 'Right forearm (back)',
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
      spanishLabel: 'Glúteo izquierdo',
      englishLabel: 'Left glute',
    ),
    RecapAnatomyZone(
      id: 'glutes_right',
      view: RecapAnatomyView.back,
      spanishLabel: 'Glúteo derecho',
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

/// Touch area bigger than the visible plate (design norm 14, Fitts): a tap
/// that misses every zone plate (in a gap, on a neutral plate or just outside
/// the figure) goes to the zone whose edge is nearest, up to this distance. It
/// covers the 8 dp inflation of each plate of the mockup.
const double _kNearestZoneDp = 16;

/// Distance between the edge samples used for the nearest-zone search, in
/// view-box units (about half a dp at the default size).
const double _kEdgeSampleStep = 1;

/// Gap between plates and stroke of the decorative lines, in view-box units
/// (2 px and 1 px at the 450 px figure of the mockup).
const double _kPlateGapWidth = 3.2;
const double _kDecoWidth = 1.6;

/// Selection colour change of a frequently used control (plan §8, norm 20):
/// short and without bounce; instant with reduced motion.
const Duration _kSelectionFade = Duration(milliseconds: 120);

class RecapAnatomySelector extends StatefulWidget {
  final Set<String> selectedZoneIds;
  final ValueChanged<String> onZoneSelected;
  final double height;

  /// Measure-map mode when not null (L6-D2): only the zones in the map take
  /// taps and are announced; a zone [RecapZoneMark.withData] is filled, one
  /// [RecapZoneMark.withoutData] is only outlined, a selected one is lime as
  /// in Recap, and every other plate (other zones and the neutral plates) is
  /// muted. Null (default) keeps the Recap figure: every zone is idle and
  /// tappable until selected.
  final Map<String, RecapZoneMark>? zoneMarks;

  /// Semantic label of a zone; by default its anatomical name.
  final String Function(String zoneId)? zoneLabelOf;

  const RecapAnatomySelector({
    super.key,
    required this.selectedZoneIds,
    required this.onZoneSelected,
    this.height = 440,
    this.zoneMarks,
    this.zoneLabelOf,
  });

  /// Interior point of [zoneId] not covered by another plate, in the
  /// 340 x 720 view box of the figure.
  @visibleForTesting
  static Offset? debugZoneCentre(String zoneId) => _zoneCentres[zoneId];

  /// Plate tones the figure paints with in the theme of [context].
  @visibleForTesting
  static ({
    Color idle,
    Color neutral,
    Color selected,
    Color gap,
    Color? outline,
  })
  debugPlateTones(BuildContext context) {
    final tones = _PlateTones.of(context);
    return (
      idle: tones.idle,
      neutral: tones.neutral,
      selected: tones.selected,
      gap: tones.gap,
      outline: tones.outline,
    );
  }

  /// Tones of the measure-map mode ([zoneMarks]) in the theme of [context]:
  /// [filled] for a zone with data, [empty] fill and [outline] for one
  /// without data, [muted] for the inert plates and the selection tones.
  @visibleForTesting
  static ({
    Color filled,
    Color empty,
    Color outline,
    Color muted,
    Color selected,
    Color? selectedOutline,
  })
  debugMeasureTones(BuildContext context) {
    final tones = _PlateTones.of(context);
    return (
      filled: tones.idle,
      empty: tones.gap,
      outline: tones.idle,
      muted: tones.muted,
      selected: tones.selected,
      selectedOutline: tones.outline,
    );
  }

  @override
  State<RecapAnatomySelector> createState() => _RecapAnatomySelectorState();
}

class _RecapAnatomySelectorState extends State<RecapAnatomySelector>
    with SingleTickerProviderStateMixin {
  static const double _toggleHeight = 48;
  static const double _toggleSpacing = ExomSpacing.md;

  var _view = RecapAnatomyView.front;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _kSelectionFade,
    value: 1,
  );

  /// Selection before the last change: the zones that changed fade from it.
  late Set<String> _previousZoneIds = widget.selectedZoneIds;

  double get _bodyHeight => widget.height - _toggleHeight - _toggleSpacing;

  double get _bodyWidth => _bodyHeight * (_kViewBoxW / _kViewBoxH);

  @override
  void didUpdateWidget(covariant RecapAnatomySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_setsEqual(oldWidget.selectedZoneIds, widget.selectedZoneIds)) {
      return;
    }
    _previousZoneIds = oldWidget.selectedZoneIds;
    if (PerformanceProfile.prefersReducedMotion(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    final unitsPerDp = _kViewBoxH / _bodyHeight;
    final zoneId = _RecapFigure.of(_view).zoneAt(
      details.localPosition * unitsPerDp,
      maxDistance: _kNearestZoneDp * unitsPerDp,
      tappable: widget.zoneMarks?.keys.toSet(),
    );
    if (zoneId == null) return;
    HapticFeedback.selectionClick();
    widget.onZoneSelected(zoneId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final figure = _RecapFigure.of(_view);
    final scale = _bodyHeight / _kViewBoxH;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Front / back (D14-3): the zones chosen belong to the form, not to
        // the view, so changing the view never loses them.
        ExomSegmentedControl<RecapAnatomyView>(
          options: RecapAnatomyView.values,
          selected: _view,
          labelOf: (view) => view == RecapAnatomyView.front
              ? l10n.frontViewLabel
              : l10n.backViewLabel,
          onChanged: (view) => setState(() => _view = view),
        ),
        const SizedBox(height: _toggleSpacing),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTap,
            child: SizedBox(
              width: _bodyWidth,
              height: _bodyHeight,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(_bodyWidth, _bodyHeight),
                    painter: _RecapAnatomyPainter(
                      figure: figure,
                      selectedZoneIds: widget.selectedZoneIds,
                      previousZoneIds: _previousZoneIds,
                      fade: _fade,
                      tones: _PlateTones.of(context),
                      zoneMarks: widget.zoneMarks,
                    ),
                  ),
                  // One semantic button per zone of the view, over its
                  // bounds; touches go through [_handleTap].
                  for (final MapEntry(key: zoneId, value: bounds)
                      in figure.bounds.entries)
                    if (widget.zoneMarks?.containsKey(zoneId) ?? true)
                      Positioned.fromRect(
                        rect: Rect.fromLTRB(
                          bounds.left * scale,
                          bounds.top * scale,
                          bounds.right * scale,
                          bounds.bottom * scale,
                        ),
                        child: Semantics(
                          container: true,
                          button: true,
                          selected: widget.selectedZoneIds.contains(zoneId),
                          label:
                              widget.zoneLabelOf?.call(zoneId) ??
                              _zonesById[zoneId]!.label(context),
                          onTap: () => widget.onZoneSelected(zoneId),
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Plate colours of treatment A «Placas» from the palette tokens: plates are
/// lerps between two grey tokens of each theme, chosen so the figure reads at
/// 3:1 against the page; the selection is the lime fill and the gaps are the
/// page background.
@immutable
class _PlateTones {
  final Color idle;
  final Color neutral;
  final Color selected;
  final Color gap;

  /// Inert plates of a measure map: dimmer than [neutral], a silhouette that
  /// stays clearly apart from the measurable plates.
  final Color muted;

  /// Outline of a selected plate: the lime-fill outline token, which only the
  /// light theme sets (lime against the idle plate is only just above 3:1
  /// there, so the dark outline carries the shape of the selected plate).
  final Color? outline;

  const _PlateTones({
    required this.idle,
    required this.neutral,
    required this.selected,
    required this.gap,
    required this.muted,
    required this.outline,
  });

  factory _PlateTones.of(BuildContext context) {
    final palette = context.exomPalette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Idle plates are graphical objects: 3:1 against the page (WCAG 1.4.11)
    // and, in the light theme, against the lime fill as well. Neutral plates
    // sit between the page and the idle ones (above 2:1 against the page).
    final idle = dark
        ? Color.lerp(palette.borderSoft, palette.textDisabled, 0.5)!
        : Color.lerp(palette.borderSoft, palette.textDisabled, 0.8)!;
    return _PlateTones(
      idle: idle,
      neutral: Color.lerp(palette.background, idle, 0.65)!,
      selected: palette.limeFill,
      gap: palette.background,
      muted: Color.lerp(palette.background, idle, 0.3)!,
      outline: palette.limeFillOutline,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _PlateTones &&
      other.idle == idle &&
      other.neutral == neutral &&
      other.selected == selected &&
      other.gap == gap &&
      other.muted == muted &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(idle, neutral, selected, gap, muted, outline);
}

class _RecapPlateData {
  final String? zoneId;
  final String d;
  final List<String> deco;

  const _RecapPlateData({
    required this.zoneId,
    required this.d,
    this.deco = const <String>[],
  });
}

class _RecapPlate {
  final String? zoneId;
  final Path path;
  final List<Path> deco;

  _RecapPlate(_RecapPlateData data)
    : zoneId = data.zoneId,
      path = _parseSvgPath(data.d),
      deco = [for (final d in data.deco) _parseSvgPath(d)];
}

/// Parsed plates of one view, with the bounds and edge samples of each zone.
class _RecapFigure {
  _RecapFigure._(List<_RecapPlateData> data)
    : plates = [for (final plate in data) _RecapPlate(plate)] {
    for (final plate in plates) {
      final zoneId = plate.zoneId;
      if (zoneId == null) continue;
      final plateBounds = plate.path.getBounds();
      bounds[zoneId] =
          bounds[zoneId]?.expandToInclude(plateBounds) ?? plateBounds;
      final samples = _edgeSamples.putIfAbsent(zoneId, () => <Offset>[]);
      for (final metric in plate.path.computeMetrics()) {
        for (var at = 0.0; at < metric.length; at += _kEdgeSampleStep) {
          samples.add(metric.getTangentForOffset(at)!.position);
        }
      }
    }
  }

  static final _front = _RecapFigure._(_frontPlates);
  static final _back = _RecapFigure._(_backPlates);

  static _RecapFigure of(RecapAnatomyView view) =>
      view == RecapAnatomyView.front ? _front : _back;

  /// Plates in paint order; later plates are drawn on top.
  final List<_RecapPlate> plates;

  /// Bounds of each zone (union of its plates), in paint order.
  final Map<String, Rect> bounds = <String, Rect>{};

  final Map<String, List<Offset>> _edgeSamples = <String, List<Offset>>{};

  /// The zone for a tap at [point] (view-box units): the topmost zone plate
  /// containing it, even under a neutral plate (neutral plates never capture
  /// a tap); otherwise (gap, neutral plate alone, outside the figure) the zone
  /// whose edge is nearest, if it is closer than [maxDistance].
  ///
  /// With [tappable] (measure map) only those zones are candidates, and a
  /// tap that lands on any other plate is ignored: inert parts never pass
  /// their tap to a neighbour.
  String? zoneAt(
    Offset point, {
    required double maxDistance,
    Set<String>? tappable,
  }) {
    bool candidate(String? zoneId) =>
        zoneId != null && (tappable == null || tappable.contains(zoneId));
    for (final plate in plates.reversed) {
      if (candidate(plate.zoneId) && plate.path.contains(point)) {
        return plate.zoneId;
      }
    }
    if (tappable != null && plates.any((plate) => plate.path.contains(point))) {
      return null;
    }
    String? nearest;
    var nearestDistance = maxDistance;
    for (final entry in _edgeSamples.entries) {
      if (!candidate(entry.key)) continue;
      for (final sample in entry.value) {
        final distance = (sample - point).distance;
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = entry.key;
        }
      }
    }
    return nearest;
  }
}

class _RecapAnatomyPainter extends CustomPainter {
  final _RecapFigure figure;
  final Set<String> selectedZoneIds;
  final Set<String> previousZoneIds;
  final Animation<double> fade;
  final _PlateTones tones;
  final Map<String, RecapZoneMark>? zoneMarks;

  _RecapAnatomyPainter({
    required this.figure,
    required this.selectedZoneIds,
    required this.previousZoneIds,
    required this.fade,
    required this.tones,
    required this.zoneMarks,
  }) : super(repaint: fade);

  /// How selected [zoneId] looks at fade progress [t]: 0 idle, 1 selected.
  double _selectionOf(String zoneId, double t) {
    final selected = selectedZoneIds.contains(zoneId);
    final was = previousZoneIds.contains(zoneId);
    if (t >= 1 || selected == was) return selected ? 1 : 0;
    return selected ? t : 1 - t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kViewBoxW, size.height / _kViewBoxH);

    final t = Curves.easeOut.transform(fade.value);
    final fill = Paint()..style = PaintingStyle.fill;
    final gap = Paint()
      ..color = tones.gap
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kPlateGapWidth
      ..strokeJoin = StrokeJoin.round;
    final deco = Paint()
      ..color = tones.gap
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kDecoWidth
      ..strokeCap = StrokeCap.round;

    // Outline of a selected plate, ExomRule.outline wide at the rendered
    // size, drawn inside the plate right next to the gap so neither the
    // plate silhouette nor the gaps move.
    final outlineColor = tones.outline;
    final outlineWidth = ExomRule.outline * _kViewBoxH / size.height;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kPlateGapWidth + 2 * outlineWidth
      ..strokeJoin = StrokeJoin.round;

    // Outline of a measurable zone without data (measure map): the idle
    // tone, as wide and placed as the selection outline.
    final emptyOutline = Paint()
      ..color = tones.idle
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kPlateGapWidth + 2 * outlineWidth
      ..strokeJoin = StrokeJoin.round;

    final marks = zoneMarks;
    for (final plate in figure.plates) {
      final zoneId = plate.zoneId;
      final mark = zoneId == null ? null : marks?[zoneId];
      if (marks != null && mark == null) {
        // Measure map: a part that cannot be measured, muted and inert.
        fill.color = tones.muted;
        canvas.drawPath(plate.path, fill);
        for (final line in plate.deco) {
          canvas.drawPath(line, deco);
        }
        canvas.drawPath(plate.path, gap);
        continue;
      }
      final selection = zoneId == null ? 0.0 : _selectionOf(zoneId, t);
      final base = mark == RecapZoneMark.withoutData ? tones.gap : tones.idle;
      fill.color = zoneId == null
          ? tones.neutral
          : Color.lerp(base, tones.selected, selection)!;
      canvas.drawPath(plate.path, fill);
      for (final line in plate.deco) {
        canvas.drawPath(line, deco);
      }
      canvas.drawPath(plate.path, gap);
      if (mark == RecapZoneMark.withoutData && selection < 1) {
        emptyOutline.color = tones.idle.withValues(
          alpha: tones.idle.a * (1 - selection),
        );
        canvas.save();
        canvas.clipPath(plate.path);
        canvas.drawPath(plate.path, emptyOutline);
        canvas.restore();
      }
      if (outlineColor != null && selection > 0) {
        outline.color = outlineColor.withValues(
          alpha: outlineColor.a * selection,
        );
        canvas.save();
        canvas.clipPath(plate.path);
        canvas.drawPath(plate.path, outline);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RecapAnatomyPainter oldDelegate) =>
      oldDelegate.figure != figure ||
      !_setsEqual(oldDelegate.selectedZoneIds, selectedZoneIds) ||
      !_setsEqual(oldDelegate.previousZoneIds, previousZoneIds) ||
      oldDelegate.fade != fade ||
      oldDelegate.tones != tones ||
      !_marksEqual(oldDelegate.zoneMarks, zoneMarks);
}

bool _setsEqual<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _marksEqual(Map<String, RecapZoneMark>? a, Map<String, RecapZoneMark>? b) {
  if (a == null || b == null) return a == b;
  return a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);
}

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
