// L6-D2 measure map: the C5b figure reused by «06 Medidas corporales» of the
// metrics form. With `zoneMarks` only the measurable zones take taps and are
// announced; a zone with data is filled, one without data is outlined, the
// selected one is lime and every other plate is muted and inert. Without
// `zoneMarks` the selector is the Recap one (recap_anatomy_selector_test and
// the C5b goldens cover it unchanged).
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';

const _viewBox = Size(340, 720);

double _channel(double value) => value <= 0.03928
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Arm (biceps) with data, neck without data; everything else is inert.
const _marks = <String, RecapZoneMark>{
  'biceps_left': RecapZoneMark.withData,
  'biceps_right': RecapZoneMark.withData,
  'triceps_left': RecapZoneMark.withData,
  'triceps_right': RecapZoneMark.withData,
  'neck_front': RecapZoneMark.withoutData,
};

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final taps = <String>[];

  Future<void> pump({
    Map<String, RecapZoneMark>? marks = _marks,
    Brightness brightness = Brightness.dark,
  }) async {
    await pumpComponent(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RecapAnatomySelector(
            selectedZoneIds: const {},
            onZoneSelected: taps.add,
            zoneMarks: marks,
            zoneLabelOf: marks == null ? null : (id) => 'Medida $id',
          ),
        ),
      ),
      brightness: brightness,
      width: 360,
      height: 800,
    );
  }

  Rect get figure => tester.getRect(
    find.descendant(
      of: find.byType(RecapAnatomySelector),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null && w.size.height > 200,
      ),
    ),
  );

  Future<String?> tapAt(Offset viewBoxPoint) async {
    final rect = figure;
    final before = taps.length;
    await tester.tapAt(
      rect.topLeft +
          Offset(
            viewBoxPoint.dx * rect.width / _viewBox.width,
            viewBoxPoint.dy * rect.height / _viewBox.height,
          ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return taps.length == before ? null : taps.last;
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('measure tones keep 3:1 between states (${brightness.name})', (
      tester,
    ) async {
      late BuildContext captured;
      await pumpComponent(
        tester,
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
        brightness: brightness,
      );
      final tones = RecapAnatomySelector.debugMeasureTones(captured);
      final background = captured.exomPalette.background;
      final recap = RecapAnatomySelector.debugPlateTones(captured);

      // With data: the filled plate, a graphical object at 3:1 on the page.
      expect(_ratio(tones.filled, background), greaterThanOrEqualTo(3.0));
      // Without data: only the outline, at 3:1 on the page it sits on.
      expect(tones.empty, background, reason: 'no fill without data');
      expect(_ratio(tones.outline, background), greaterThanOrEqualTo(3.0));
      // Selected: lime at 3:1 against the filled plate (as C5b) and, through
      // its fill or (light theme) its dark outline, against the empty one.
      expect(_ratio(tones.selected, tones.filled), greaterThanOrEqualTo(3.0));
      final selectedEdge = tones.selectedOutline ?? tones.selected;
      expect(_ratio(selectedEdge, background), greaterThanOrEqualTo(3.0));
      // Inert parts: dimmer than the C5b neutral plate, still a silhouette,
      // and clearly apart from the measurable plates with data.
      final muted = _ratio(tones.muted, background);
      expect(muted, lessThan(_ratio(recap.neutral, background)));
      expect(muted, greaterThanOrEqualTo(1.2));
      expect(_ratio(tones.filled, tones.muted), greaterThanOrEqualTo(2.0));
      expect(_ratio(tones.outline, tones.muted), greaterThanOrEqualTo(2.0));
    });
  }

  testWidgets('only measurable zones take a tap', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    expect(
      await h.tapAt(RecapAnatomySelector.debugZoneCentre('biceps_left')!),
      'biceps_left',
    );
    expect(
      await h.tapAt(RecapAnatomySelector.debugZoneCentre('neck_front')!),
      'neck_front',
    );
    // Abdomen and chest are zones of Recap but not marked here: inert.
    expect(
      await h.tapAt(RecapAnatomySelector.debugZoneCentre('abdomen')!),
      isNull,
    );
    expect(
      await h.tapAt(RecapAnatomySelector.debugZoneCentre('chest_left')!),
      isNull,
    );
    // The head is a neutral plate: inert too, even near the neck.
    expect(await h.tapAt(const Offset(170, 60)), isNull);
  });

  testWidgets('a tap just outside a measurable plate still reaches it', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    // Left of the left biceps, outside every plate (touch area > plate).
    final centre = RecapAnatomySelector.debugZoneCentre('biceps_left')!;
    expect(await h.tapAt(centre.translate(-22, 0)), 'biceps_left');
  });

  testWidgets('only measurable zones are announced, with the given label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = _Harness(tester);
    await h.pump();
    expect(find.bySemanticsLabel('Medida biceps_left'), findsOneWidget);
    expect(find.bySemanticsLabel('Medida neck_front'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('abdomen|Abdomen')), findsNothing);
    final node = tester.getSemantics(
      find.bySemanticsLabel('Medida biceps_left'),
    );
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('announced zones are targets of at least 48 x 48 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = _Harness(tester);
    await h.pump(
      marks: {
        for (final zone in RecapAnatomyZone.values)
          zone.id: RecapZoneMark.withData,
      },
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('without marks the Recap behaviour is kept', (tester) async {
    final h = _Harness(tester);
    await h.pump(marks: null);
    expect(
      await h.tapAt(RecapAnatomySelector.debugZoneCentre('abdomen')!),
      'abdomen',
    );
    expect(tester.takeException(), isNull);
  });
}
