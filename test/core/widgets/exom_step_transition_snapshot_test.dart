// L6-S25-D2: `ExomStepTransition(snapshot: true)` paints each moving step
// from an image of its content taken once, instead of a group-opacity layer
// (an offscreen render pass) on every frame. These tests fix that contract:
// * mid-move there is no partially transparent OpacityLayer, while the
//   default overlap still has one per moving step (the control);
// * the picture is the same as the default overlap (pixels compared);
// * a content change mid-move, or content with layers of its own, falls back
//   to the live opacity layer, so the image never hides a change;
// * taps and positions follow the offset as before;
// * all of it at the device pixel ratio of real phones (2.625, 3.0; the S25
//   is about 2.8), not only at 1.0, where logical and physical pixels match;
// * interrupted moves (fast taps, going back mid-move) and unmounting
//   mid-move leave no image alive.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

const _captureKey = Key('snapshot-capture');

/// Device pixel ratios checked: 1.0 and two real phones' (the S25 is ~2.8).
const List<double> _ratios = [1.0, 2.625, 3.0];

/// Overlapping fill, outline and text: group opacity and per-element alpha
/// give different pixels here, so the comparison is meaningful.
class _Content extends StatelessWidget {
  const _Content({required this.step, required this.fill});

  final int step;
  final Color fill;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: Key('content-$step'),
    width: 160,
    height: 60,
    child: Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: fill)),
        Positioned(
          left: 10,
          top: 10,
          width: 60,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF3060C0),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 18,
          child: Text(
            'Mes $step',
            style: const TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
          ),
        ),
      ],
    ),
  );
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.snapshot,
    this.inner,
    this.onTap,
    this.content,
    this.padding = 40,
  });

  final bool snapshot;

  /// Distance of the step from the captured area's corner: a fraction of a
  /// physical pixel puts the step's origin between pixels.
  final double padding;

  /// Real content of [step] instead of the test drawing (sized by itself).
  final Widget Function(int step)? content;

  /// Wraps the content (e.g. in a layer of its own).
  final Widget Function(Widget content)? inner;
  final VoidCallback? onTap;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int step = 0;
  Color fill = const Color(0xFFC03020);

  void go(int value) => setState(() => step = value);

  void paintWith(Color value) => setState(() => fill = value);

  @override
  Widget build(BuildContext context) {
    final real = widget.content;
    Widget content =
        real?.call(step) ??
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: _Content(step: step, fill: fill),
        );
    final inner = widget.inner;
    if (inner != null) content = inner(content);
    // The captured area has a margin around the step: ink painted outside
    // the step's box is compared too.
    return Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _captureKey,
        child: Padding(
          padding: EdgeInsets.all(widget.padding),
          child: SizedBox(
            width: real == null ? 240 : 300,
            height: real == null ? 60 : null,
            child: ExomStepTransition(
              step: step,
              snapshot: widget.snapshot,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Partially transparent opacity layers in the scene.
List<OpacityLayer> _partialOpacityLayers(WidgetTester tester) {
  final found = <OpacityLayer>[];
  void walk(Layer layer) {
    if (layer is OpacityLayer) {
      final alpha = layer.alpha ?? 255;
      if (alpha > 0 && alpha < 255) found.add(layer);
    }
    if (layer is ContainerLayer) {
      for (var c = layer.firstChild; c != null; c = c.nextSibling) {
        walk(c);
      }
    }
  }

  walk(tester.binding.renderViews.first.debugLayer!);
  return found;
}

/// Pixels of the captured area at the physical resolution of the view (the
/// `captureImage` of flutter_test takes them at ratio 1).
Future<Uint8List> _pixels(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final boundary = tester.renderObject(find.byKey(_captureKey));
    final layer = boundary.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      boundary.paintBounds,
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Compositing an image with an alpha and compositing a layer with it round
/// differently: up to 2 of 255 per channel (measured: at a low alpha), never
/// a visible change.
const int _rounding = 2;

/// Largest difference of any channel of any pixel.
int _maxDifference(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var max = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > max) max = d;
  }
  return max;
}

Future<GlobalKey<_HostState>> _mount(
  WidgetTester tester, {
  required bool snapshot,
  bool reduced = false,
  Widget Function(Widget content)? inner,
  Widget Function(int step)? content,
  VoidCallback? onTap,
  double textScale = 1.0,
  double ratio = 1.0,
  double padding = 40,
}) async {
  final key = GlobalKey<_HostState>();
  await pumpComponent(
    tester,
    _Host(
      key: key,
      snapshot: snapshot,
      inner: inner,
      content: content,
      onTap: onTap,
      padding: padding,
    ),
    disableAnimations: reduced,
    textScale: textScale,
    devicePixelRatio: ratio,
  );
  // A second mount in the same test animates the theme of the app: let it
  // settle so the step's content is still while it moves.
  await tester.pumpAndSettle();
  return key;
}

/// Pixels of the step area [after] a change of step.
Future<Uint8List> _midMove(
  WidgetTester tester, {
  required bool snapshot,
  required bool reduced,
  required Duration after,
  Widget Function(Widget content)? inner,
  Widget Function(int step)? content,
  Color? repaintWith,
  double textScale = 1.0,
  double ratio = 1.0,
  double padding = 40,
}) async {
  final key = await _mount(
    tester,
    snapshot: snapshot,
    reduced: reduced,
    inner: inner,
    content: content,
    textScale: textScale,
    ratio: ratio,
    padding: padding,
  );
  key.currentState!.go(1);
  await tester.pump();
  await tester.pump(after);
  if (repaintWith != null) {
    key.currentState!.paintWith(repaintWith);
    await tester.pump(const Duration(milliseconds: 16));
  }
  return _pixels(tester);
}

void main() {
  group('L6-S25-D2 ExomStepTransition snapshot', () {
    for (final ratio in _ratios) {
      testWidgets('mid-move at dpr $ratio: no offscreen opacity layer with '
          'snapshot; one per moving step without it', (tester) async {
        for (final snapshot in [false, true]) {
          final key = await _mount(tester, snapshot: snapshot, ratio: ratio);
          expect(_partialOpacityLayers(tester), isEmpty, reason: 'at rest');
          key.currentState!.go(1);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          // Both steps are on screen.
          expect(find.byKey(const Key('content-0')), findsOneWidget);
          expect(find.byKey(const Key('content-1')), findsOneWidget);
          expect(
            _partialOpacityLayers(tester),
            hasLength(snapshot ? 0 : 2),
            reason: 'snapshot: $snapshot',
          );
          await tester.pump(const Duration(milliseconds: 60));
          expect(_partialOpacityLayers(tester), hasLength(snapshot ? 0 : 2));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('content-0')), findsNothing);
          expect(_partialOpacityLayers(tester), isEmpty, reason: 'at rest');
        }
      });

      testWidgets('mid-move at dpr $ratio: same pixels as the opacity layer '
          '(fade only)', (tester) async {
        for (final ms in const [20, 50, 80]) {
          final after = Duration(milliseconds: ms);
          final live = await _midMove(
            tester,
            snapshot: false,
            reduced: true,
            after: after,
            ratio: ratio,
          );
          final image = await _midMove(
            tester,
            snapshot: true,
            reduced: true,
            after: after,
            ratio: ratio,
          );
          expect(_partialOpacityLayers(tester), isEmpty, reason: '$ms ms');
          expect(
            _maxDifference(live, image),
            lessThanOrEqualTo(_rounding),
            reason: '$ms ms',
          );
        }
      });

      testWidgets('step between physical pixels at dpr $ratio: same pixels, '
          'so nothing jumps when it comes to rest', (tester) async {
        // The step's origin sits at a fraction of a physical pixel. The image
        // keeps that phase: drawn without offset it lands where the live
        // content does, which is where the step is painted at rest.
        const padding = 40.3;
        final live = await _midMove(
          tester,
          snapshot: false,
          reduced: true,
          after: const Duration(milliseconds: 50),
          ratio: ratio,
          padding: padding,
        );
        final image = await _midMove(
          tester,
          snapshot: true,
          reduced: true,
          after: const Duration(milliseconds: 50),
          ratio: ratio,
          padding: padding,
        );
        expect(_partialOpacityLayers(tester), isEmpty);
        expect(_maxDifference(live, image), lessThanOrEqualTo(_rounding));
      });

      testWidgets('mid-move with offset at dpr $ratio: same overall ink as '
          'the opacity layer', (tester) async {
        // Mid-move the offset is fractional: the live step is rasterized
        // between pixels and the image moves in whole physical pixels, so
        // edges differ by antialiasing. The overall ink (alpha and content)
        // must be the same.
        final live = await _midMove(
          tester,
          snapshot: false,
          reduced: false,
          after: const Duration(milliseconds: 120),
          ratio: ratio,
        );
        final image = await _midMove(
          tester,
          snapshot: true,
          reduced: false,
          after: const Duration(milliseconds: 120),
          ratio: ratio,
        );
        expect(_partialOpacityLayers(tester), isEmpty);
        int sum(Uint8List p) => p.fold(0, (s, v) => s + v);
        final difference = (sum(live) - sum(image)).abs() / sum(live);
        expect(difference, lessThan(0.005));
      });
    }

    for (final scale in const [1.0, 1.6]) {
      testWidgets('display numeral at ${scale}x: same pixels', (tester) async {
        // The calendar's protagonist figure (hero96, line height under 1).
        Widget figure(int step) => ExomNumeral(
          value: '${step + 8}',
          unit: '/12',
          side: const Text('SESIONES HECHAS', style: TextStyle(fontSize: 18)),
        );
        final live = await _midMove(
          tester,
          snapshot: false,
          reduced: true,
          after: const Duration(milliseconds: 50),
          content: figure,
          textScale: scale,
        );
        final image = await _midMove(
          tester,
          snapshot: true,
          reduced: true,
          after: const Duration(milliseconds: 50),
          content: figure,
          textScale: scale,
        );
        expect(_maxDifference(live, image), lessThanOrEqualTo(_rounding));
      });
    }

    testWidgets('ink painted outside the box is in the image', (tester) async {
      // A line height of 0.5 puts half of each glyph outside the box.
      Widget overflowing(int step) => Text(
        'Mes ${step + 1}',
        style: const TextStyle(fontSize: 40, height: 0.5, color: Colors.white),
      );
      final live = await _midMove(
        tester,
        snapshot: false,
        reduced: true,
        after: const Duration(milliseconds: 50),
        content: overflowing,
      );
      final image = await _midMove(
        tester,
        snapshot: true,
        reduced: true,
        after: const Duration(milliseconds: 50),
        content: overflowing,
      );
      expect(_maxDifference(live, image), lessThanOrEqualTo(_rounding));
    });

    testWidgets('content that repaints mid-move: falls back to the live '
        'layer, never a stale image', (tester) async {
      final live = await _midMove(
        tester,
        snapshot: false,
        reduced: true,
        after: const Duration(milliseconds: 30),
        repaintWith: const Color(0xFF20A040),
      );
      final image = await _midMove(
        tester,
        snapshot: true,
        reduced: true,
        after: const Duration(milliseconds: 30),
        repaintWith: const Color(0xFF20A040),
      );
      expect(_maxDifference(live, image), lessThanOrEqualTo(_rounding));
      // The incoming step went back to its opacity layer.
      expect(_partialOpacityLayers(tester), isNotEmpty);
      await tester.pumpAndSettle();
      expect(_partialOpacityLayers(tester), isEmpty);
    });

    testWidgets('content with a layer of its own: the live layer', (
      tester,
    ) async {
      Widget inner(Widget content) => RepaintBoundary(child: content);
      final live = await _midMove(
        tester,
        snapshot: false,
        reduced: true,
        after: const Duration(milliseconds: 40),
        inner: inner,
      );
      final liveLayers = _partialOpacityLayers(tester).length;
      final image = await _midMove(
        tester,
        snapshot: true,
        reduced: true,
        after: const Duration(milliseconds: 40),
        inner: inner,
      );
      expect(_partialOpacityLayers(tester), hasLength(liveLayers));
      expect(_maxDifference(live, image), lessThanOrEqualTo(_rounding));
    });

    testWidgets('the incoming step takes taps at its moving place', (
      tester,
    ) async {
      var taps = 0;
      final key = await _mount(tester, snapshot: true, onTap: () => taps++);
      key.currentState!.go(1);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('content-1'))).dx,
        closeTo(40 + 24, 0.01),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final x = tester.getTopLeft(find.byKey(const Key('content-1'))).dx;
      expect(x, inExclusiveRange(40, 64));
      // Just inside the moved content: only the incoming step takes it.
      await tester.tapAt(Offset(x + 2, 60));
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('content-1'))).dx, 40);
    });

    for (final ratio in _ratios) {
      testWidgets('fast taps at dpr $ratio: no offscreen opacity layer, the '
          'last step at rest and no image alive', (tester) async {
        final images = _trackImages();
        final key = await _mount(tester, snapshot: true, ratio: ratio);
        for (var step = 1; step <= 5; step++) {
          key.currentState!.go(step);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 30));
          expect(_partialOpacityLayers(tester), isEmpty, reason: 'tap $step');
        }
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(_partialOpacityLayers(tester), isEmpty, reason: 'frame $i');
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('content-5')), findsOneWidget);
        expect(find.byKey(const Key('content-4')), findsNothing);
        expect(tester.getTopLeft(find.byKey(const Key('content-5'))).dx, 40);
        expect(_partialOpacityLayers(tester), isEmpty);
        expect(images, isEmpty, reason: 'images alive at rest');
      });

      testWidgets('going back mid-move at dpr $ratio: no offscreen opacity '
          'layer, back at rest and no image alive', (tester) async {
        final images = _trackImages();
        final key = await _mount(tester, snapshot: true, ratio: ratio);
        key.currentState!.go(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(images, isNotEmpty, reason: 'the steps move as images');
        key.currentState!.go(0);
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(_partialOpacityLayers(tester), isEmpty, reason: 'frame $i');
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('content-0')), findsOneWidget);
        expect(find.byKey(const Key('content-1')), findsNothing);
        expect(tester.getTopLeft(find.byKey(const Key('content-0'))).dx, 40);
        expect(_partialOpacityLayers(tester), isEmpty);
        expect(images, isEmpty, reason: 'images alive at rest');
      });

      testWidgets('unmounted mid-move at dpr $ratio: no image alive', (
        tester,
      ) async {
        final images = _trackImages();
        final key = await _mount(tester, snapshot: true, ratio: ratio);
        key.currentState!.go(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(images, hasLength(2), reason: 'one image per moving step');
        await tester.pumpWidget(const SizedBox());
        expect(images, isEmpty, reason: 'images alive after unmounting');
      });
    }
  });
}

/// The `ui.Image`s created and not disposed since the call, until the end of
/// the test.
Set<ui.Image> _trackImages() {
  final alive = <ui.Image>{};
  final onCreate = ui.Image.onCreate;
  final onDispose = ui.Image.onDispose;
  ui.Image.onCreate = (image) {
    alive.add(image);
    onCreate?.call(image);
  };
  ui.Image.onDispose = (image) {
    alive.remove(image);
    onDispose?.call(image);
  };
  addTearDown(() {
    ui.Image.onCreate = onCreate;
    ui.Image.onDispose = onDispose;
  });
  return alive;
}
