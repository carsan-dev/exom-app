// L5-C5b body map («muñeco», treatment A «Placas»): the selector keeps the
// payload contract (same ids, same left/right convention) while the figure,
// its hit test (touch area bigger than the visible plate, nearest zone within
// 16 dp), the labels and the semantics change.
//
// The points below are in the 340 x 720 view box of the approved mockup
// (docs/bocetos/rediseno-exom-app/extension/c5b-muneco.html). The zone centres
// are the interior points the generator exports into
// recap_anatomy_geometry.dart (`_zoneCentres`); the other fixtures were
// computed from the same geometry (C5b evidence, logs/mun-fixtures.log).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';

const _viewBox = Size(340, 720);

const _frontCentres = <String, Offset>{
  'quadriceps_left': Offset(126.62, 435.61),
  'quadriceps_right': Offset(213.15, 430.61),
  'shin_left': Offset(124.59, 560.68),
  'shin_right': Offset(215.75, 563.68),
  'hip_flexors': Offset(142.5, 358),
  'abdomen': Offset(170.19, 252.5),
  'chest_left': Offset(144.63, 169.04),
  'chest_right': Offset(195, 168.54),
  'neck_front': Offset(170, 119.5),
  'forearm_left_front': Offset(69.86, 305.66),
  'forearm_right_front': Offset(269.95, 305.16),
  'biceps_left': Offset(87.44, 223.22),
  'biceps_right': Offset(252.58, 223.22),
  'shoulder_left_front': Offset(101.1, 152.65),
  'shoulder_right_front': Offset(239.38, 153.65),
};

const _backCentres = <String, Offset>{
  'hamstrings_left': Offset(134.93, 428.62),
  'hamstrings_right': Offset(204.71, 425.62),
  'calves_left': Offset(131.3, 565.76),
  'calves_right': Offset(208.53, 560.26),
  'glutes_left': Offset(141.5, 356),
  'glutes_right': Offset(198.5, 356),
  'lats_left': Offset(132, 232),
  'lats_right': Offset(208, 232),
  'upper_back': Offset(169.81, 207.5),
  'lower_back': Offset(170, 311.5),
  'neck_back': Offset(170, 118.5),
  'traps_upper': Offset(170, 159.5),
  'forearm_left_back': Offset(69.86, 305.66),
  'forearm_right_back': Offset(269.95, 305.16),
  'triceps_left': Offset(85.44, 214.72),
  'triceps_right': Offset(254.49, 214.72),
  'shoulder_left_back': Offset(100.6, 150.41),
  'shoulder_right_back': Offset(239.23, 149.91),
};

/// The ids and views of the payload `muscle_pain_zones` before this change.
const _legacyFrontIds = <String>{
  'neck_front',
  'shoulder_left_front',
  'shoulder_right_front',
  'chest_left',
  'chest_right',
  'biceps_left',
  'biceps_right',
  'forearm_left_front',
  'forearm_right_front',
  'abdomen',
  'hip_flexors',
  'quadriceps_left',
  'quadriceps_right',
  'shin_left',
  'shin_right',
};
const _legacyBackIds = <String>{
  'neck_back',
  'traps_upper',
  'shoulder_left_back',
  'shoulder_right_back',
  'triceps_left',
  'triceps_right',
  'forearm_left_back',
  'forearm_right_back',
  'lats_left',
  'lats_right',
  'upper_back',
  'lower_back',
  'glutes_left',
  'glutes_right',
  'hamstrings_left',
  'hamstrings_right',
  'calves_left',
  'calves_right',
};

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final taps = <String>[];
  var selected = <String>{};

  Future<void> pump({
    Brightness brightness = Brightness.dark,
    double width = 360,
    double height = 800,
    double textScale = 1.0,
    bool disableAnimations = false,
    Locale locale = const Locale('es'),
    Set<String> initial = const {},
    double selectorHeight = 440,
  }) async {
    selected = {...initial};
    await pumpComponent(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => RecapAnatomySelector(
              height: selectorHeight,
              selectedZoneIds: selected,
              onZoneSelected: (id) {
                taps.add(id);
                setState(() {
                  selected = selected.contains(id)
                      ? ({...selected}..remove(id))
                      : {...selected, id};
                });
              },
            ),
          ),
        ),
      ),
      brightness: brightness,
      width: width,
      height: height,
      textScale: textScale,
      disableAnimations: disableAnimations,
      locale: locale,
    );
  }

  /// The painted figure: the CustomPaint of the selector with a body size.
  Rect get figure => tester.getRect(
    find.descendant(
      of: find.byType(RecapAnatomySelector),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null && w.size.height > 200,
      ),
    ),
  );

  Offset toGlobal(Offset viewBoxPoint) {
    final rect = figure;
    return rect.topLeft +
        Offset(
          viewBoxPoint.dx * rect.width / _viewBox.width,
          viewBoxPoint.dy * rect.height / _viewBox.height,
        );
  }

  Future<String?> tapAt(Offset viewBoxPoint) async {
    final before = taps.length;
    await tester.tapAt(toGlobal(viewBoxPoint));
    await tester.pump(const Duration(milliseconds: 200));
    return taps.length == before ? null : taps.last;
  }

  Future<void> showBack() async {
    await tester.tap(find.text('Posterior'));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('payload contract', () {
    test('the zone ids, views and order of the payload do not change', () {
      final front = RecapAnatomyZone.values
          .where((z) => z.view == RecapAnatomyView.front)
          .map((z) => z.id)
          .toSet();
      final back = RecapAnatomyZone.values
          .where((z) => z.view == RecapAnatomyView.back)
          .map((z) => z.id)
          .toSet();
      expect(front, _legacyFrontIds);
      expect(back, _legacyBackIds);
      expect(RecapAnatomyZone.values, hasLength(33));
      expect(_frontCentres.keys.toSet(), _legacyFrontIds);
      expect(_backCentres.keys.toSet(), _legacyBackIds);
    });

    test('the fixtures match the centres exported by the geometry', () {
      for (final entry in {..._frontCentres, ..._backCentres}.entries) {
        expect(
          RecapAnatomySelector.debugZoneCentre(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('hit test on the new figure', () {
    testWidgets('the figure keeps the footprint and the view-box aspect', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      final rect = h.figure;
      // Same height as before (440 - 48 toggle - 12 spacing, measured on
      // the base); the width follows the new 340 x 720 view box.
      expect(rect.height, 380);
      expect(rect.width, closeTo(380 * 340 / 720, 0.01));
      // The whole selector (segmented control, spacing, figure) keeps the
      // footprint of the base: the figure height is unchanged and the
      // segmented control is untouched.
      expect(tester.getSize(find.byType(RecapAnatomySelector)).height, 442);
    });

    testWidgets('tapping the centre of every front zone toggles that id', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      for (final entry in _frontCentres.entries) {
        expect(await h.tapAt(entry.value), entry.key, reason: entry.key);
      }
      expect(h.taps, _frontCentres.keys.toList());
      expect(h.selected, _legacyFrontIds);
      // A second tap toggles it off again: same id reaches the form.
      expect(await h.tapAt(_frontCentres['abdomen']!), 'abdomen');
      expect(h.selected.contains('abdomen'), isFalse);
    });

    testWidgets('tapping the centre of every back zone toggles that id', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.showBack();
      for (final entry in _backCentres.entries) {
        expect(await h.tapAt(entry.value), entry.key, reason: entry.key);
      }
      expect(h.taps, _backCentres.keys.toList());
      expect(h.selected, _legacyBackIds);
    });

    testWidgets('a tap 6 dp outside the visible edge selects that zone', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      // Fixtures computed for a 376 dp figure: 6 dp there is 6.06 dp here.
      expect(h.figure.height, 380);
      expect(await h.tapAt(const Offset(67.11, 152.65)), 'shoulder_left_front');
      expect(
        await h.tapAt(const Offset(300.19, 305.16)),
        'forearm_right_front',
      );
      await h.showBack();
      expect(await h.tapAt(const Offset(97.81, 565.76)), 'calves_left');
      expect(await h.tapAt(const Offset(280.68, 214.72)), 'triceps_right');
    });

    testWidgets('a tap in a gap or on a neutral plate selects the nearest '
        'zone', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      // Elbow, front: the bare gap under the biceps, then the neutral elbow
      // plate nearer the biceps and nearer the forearm.
      expect(await h.tapAt(const Offset(87.44, 263.22)), 'biceps_left');
      expect(await h.tapAt(const Offset(87.44, 269.22)), 'biceps_left');
      expect(await h.tapAt(const Offset(87.44, 281.22)), 'forearm_left_front');
      await h.showBack();
      expect(await h.tapAt(const Offset(254.49, 244.72)), 'triceps_right');
      expect(await h.tapAt(const Offset(254.49, 280.72)), 'forearm_right_back');
    });

    testWidgets('taps far from every zone and on the head select nothing', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      expect(await h.tapAt(const Offset(6, 20)), isNull);
      expect(await h.tapAt(const Offset(170, 700)), isNull);
      expect(await h.tapAt(const Offset(170, 34)), isNull);
      expect(await h.tapAt(const Offset(170, 60)), isNull);
      await h.showBack();
      expect(await h.tapAt(const Offset(330, 20)), isNull);
      expect(await h.tapAt(const Offset(170, 34)), isNull);
      expect(h.taps, isEmpty);
    });

    testWidgets('the latissimus is hittable across the whole wing', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.showBack();
      for (final point in const [
        Offset(118, 180),
        Offset(125, 215),
        Offset(138, 250),
        Offset(122, 265),
        Offset(131, 305),
      ]) {
        h.taps.clear();
        expect(await h.tapAt(point), 'lats_left', reason: '$point');
        // Toggle back so every tap starts from the same state.
        await h.tapAt(point);
      }
      expect(await h.tapAt(const Offset(218, 260)), 'lats_right');
    });

    testWidgets('it fits 360 dp at text scale 2.0 without overflow', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(textScale: 2.0, brightness: Brightness.light);
      expectNoOverflow(tester);
      expect(await h.tapAt(_frontCentres['chest_left']!), 'chest_left');
      await h.showBack();
      expectNoOverflow(tester);
    });
  });

  group('neutral plates over zones', () {
    // A neutral plate drawn on top of a zone plate never captures the tap:
    // the topmost zone plate under it wins, whatever the nearest-edge
    // distance. At this large size 16 dp is ~10 view-box units, less than
    // the depth of these overlaps (mun2-overlap.log), so the nearest-edge
    // fallback alone would select nothing.
    testWidgets('the zone under a neutral plate is selected', (tester) async {
      final h = _Harness(tester);
      await h.pump(width: 700, height: 1300, selectorHeight: 1200);
      expect(h.figure.height, 1140);
      // Chin: the neutral head is drawn over the top of neck_front.
      expect(await h.tapAt(const Offset(170, 103)), 'neck_front');
      await h.showBack();
      // Inner elbow: a neutral plate is drawn over the triceps.
      expect(await h.tapAt(const Offset(84, 233)), 'triceps_left');
      expect(await h.tapAt(const Offset(256, 233)), 'triceps_right');
      // The bare head is still neutral.
      expect(await h.tapAt(const Offset(170, 40)), isNull);
    });
  });

  group('light theme outline', () {
    // WCAG 1.4.11: in light the lime plate is too close to the idle plate,
    // so a selected plate also carries the lime-fill outline.
    final light = AppTheme.light.extension<ExomThemePalette>()!;
    // The outline is a stroke in the outline colour wider than the 3.2-unit
    // gap stroke (the dark gap is the same charcoal, but never wider).
    bool isOutline(Symbol method, List<dynamic> args) {
      if (method != #drawPath) return false;
      final paint = args[1] as Paint;
      // Paint keeps 32-bit floats: compare the ARGB words.
      return paint.color.toARGB32() == light.limeFillOutline!.toARGB32() &&
          paint.style == PaintingStyle.stroke &&
          paint.strokeWidth > 4;
    }

    Finder figure() => find.descendant(
      of: find.byType(RecapAnatomySelector),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null && w.size.height > 200,
      ),
    );

    testWidgets('selected plates are outlined in light', (tester) async {
      expect(light.limeFillOutline, isNotNull);
      final h = _Harness(tester);
      await h.pump(
        brightness: Brightness.light,
        disableAnimations: true,
        initial: {'abdomen'},
      );
      expect(tester.renderObject(figure()), paints..something(isOutline));
    });

    testWidgets('no outline without selection in light', (tester) async {
      final h = _Harness(tester);
      await h.pump(brightness: Brightness.light, disableAnimations: true);
      expect(
        tester.renderObject(figure()),
        isNot(paints..something(isOutline)),
      );
    });

    testWidgets('no outline in dark (unchanged contrast)', (tester) async {
      final h = _Harness(tester);
      await h.pump(disableAnimations: true, initial: {'abdomen'});
      expect(
        tester.renderObject(figure()),
        isNot(paints..something(isOutline)),
      );
    });
  });

  group('motion', () {
    testWidgets('the selection colour settles within 120 ms', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      await tester.tapAt(h.toGlobal(_frontCentres['abdomen']!));
      await tester.pump(); // rebuild with the new selection
      await tester.pump(); // first animation frame
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 60));
      // At 120 ms the colour is final; the controller reports completion
      // (and stops ticking) on the next frame.
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('with reduced motion the change is instant', (tester) async {
      final h = _Harness(tester);
      await h.pump(disableAnimations: true);
      await tester.tapAt(h.toGlobal(_frontCentres['abdomen']!));
      await tester.pump();
      expect(h.selected, {'abdomen'});
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('labels', () {
    test('Spanish labels carry their accents', () {
      String es(String id) => RecapAnatomyZone.fromId(id)!.spanishLabel;
      expect(es('biceps_left'), 'Bíceps izquierdo');
      expect(es('biceps_right'), 'Bíceps derecho');
      expect(es('quadriceps_left'), 'Cuádriceps izquierdo');
      expect(es('quadriceps_right'), 'Cuádriceps derecho');
      expect(es('triceps_left'), 'Tríceps izquierdo');
      expect(es('triceps_right'), 'Tríceps derecho');
      expect(es('glutes_left'), 'Glúteo izquierdo');
      expect(es('glutes_right'), 'Glúteo derecho');
      expect(es('hamstrings_left'), 'Isquio izquierdo');
    });

    test('zones that share a name say front or back', () {
      String es(String id) => RecapAnatomyZone.fromId(id)!.spanishLabel;
      String en(String id) => RecapAnatomyZone.fromId(id)!.englishLabel;
      expect(es('neck_front'), 'Cuello (delante)');
      expect(es('neck_back'), 'Cuello (detrás)');
      expect(es('shoulder_left_front'), 'Hombro izquierdo (delante)');
      expect(es('shoulder_right_front'), 'Hombro derecho (delante)');
      expect(es('shoulder_left_back'), 'Hombro izquierdo (detrás)');
      expect(es('shoulder_right_back'), 'Hombro derecho (detrás)');
      expect(es('forearm_left_front'), 'Antebrazo izquierdo (delante)');
      expect(es('forearm_right_front'), 'Antebrazo derecho (delante)');
      expect(es('forearm_left_back'), 'Antebrazo izquierdo (detrás)');
      expect(es('forearm_right_back'), 'Antebrazo derecho (detrás)');
      expect(en('neck_front'), 'Neck (front)');
      expect(en('neck_back'), 'Neck (back)');
      expect(en('shoulder_left_front'), 'Left shoulder (front)');
      expect(en('shoulder_right_back'), 'Right shoulder (back)');
      expect(en('forearm_left_front'), 'Left forearm (front)');
      expect(en('forearm_right_back'), 'Right forearm (back)');
    });

    test('every label is unique per language', () {
      final es = RecapAnatomyZone.values.map((z) => z.spanishLabel).toSet();
      final en = RecapAnatomyZone.values.map((z) => z.englishLabel).toSet();
      expect(es, hasLength(RecapAnatomyZone.values.length));
      expect(en, hasLength(RecapAnatomyZone.values.length));
    });
  });

  group('semantics', () {
    testWidgets('each zone of the view is a labelled, selectable button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = _Harness(tester);
      await h.pump(initial: {'biceps_left', 'lower_back'});
      for (final id in _legacyFrontIds) {
        final zone = RecapAnatomyZone.fromId(id)!;
        expect(
          tester.getSemantics(find.bySemanticsLabel(zone.spanishLabel)),
          isSemantics(
            label: zone.spanishLabel,
            isButton: true,
            hasSelectedState: true,
            isSelected: id == 'biceps_left',
            hasTapAction: true,
          ),
          reason: id,
        );
      }
      expect(find.bySemanticsLabel('Lumbar'), findsNothing);

      // The semantic tap toggles the zone like a touch.
      tester.semantics.tap(find.semantics.byLabel('Abdomen'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.taps, ['abdomen']);

      await h.showBack();
      final lumbar = RecapAnatomyZone.fromId('lower_back')!;
      expect(
        tester.getSemantics(find.bySemanticsLabel(lumbar.spanishLabel)),
        isSemantics(
          label: 'Lumbar',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Hombro izquierdo (detrás)'), findsOne);
      handle.dispose();
    });

    testWidgets('in English the semantics use the English labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = _Harness(tester);
      await h.pump(locale: const Locale('en'));
      expect(find.bySemanticsLabel('Left shoulder (front)'), findsOne);
      expect(find.bySemanticsLabel('Left biceps'), findsOne);
      handle.dispose();
    });
  });
}
