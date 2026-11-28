// L5-D3 · geometry of the V4d window (contract L5-D3, acceptance L5-D44):
// the hole and the inner contour of the X cut-out are simple polygons (no
// self-intersections) for every s in [1, Smax] and r in [0, 1]; the reveal is
// monotonic and Inicio is never visible outside the outer contour of the X.
import 'dart:ui';

import 'package:exom_app/features/splash/presentation/v4d/v4d_geometry.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/features/splash/presentation/v4d/x_glyph.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when [p] is inside [poly] (even-odd) or within [eps] of its boundary.
bool _insideOrOn(Offset p, List<Offset> poly, {double eps = 1e-6}) {
  if (pointInPolygon(p, poly)) return true;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    if (distanceToSegment(p, a, b) <= eps) return true;
  }
  return false;
}

/// [inner] lies inside [outer]: every vertex inside or on it and no edge of
/// one properly crosses an edge of the other.
void _expectContained(List<Offset> inner, List<Offset> outer, String why) {
  for (final v in inner) {
    expect(_insideOrOn(v, outer, eps: 1e-4), isTrue, reason: '$why: $v');
  }
  for (var i = 0; i < inner.length; i++) {
    final a = inner[i];
    final b = inner[(i + 1) % inner.length];
    if ((a - b).distance < 1e-9) continue;
    for (var j = 0; j < outer.length; j++) {
      final c = outer[j];
      final d = outer[(j + 1) % outer.length];
      expect(
        segmentsCrossProperly(a, b, c, d),
        isFalse,
        reason: '$why: edge $a-$b crosses $c-$d',
      );
    }
  }
}

double _area(List<Offset> poly) {
  var a = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final p = poly[i];
    final q = poly[(i + 1) % poly.length];
    a += p.dx * q.dy - q.dx * p.dy;
  }
  return a.abs() / 2;
}

/// Phone screens (logical px), the lockup unit (px per font unit) a screen of
/// that width gives, and the X centre used by the scene.
const _screens = <(Size, double)>[
  (Size(320, 640), 0.0885),
  (Size(360, 780), 0.1002),
  (Size(390, 844), 0.1088),
  (Size(412, 915), 0.1152),
  (Size(800, 1280), 0.2283),
];

void main() {
  test('XG is the 32-vertex X of Barlow Condensed 800 and is simple', () {
    expect(xGlyphPolygon, hasLength(32));
    expect(xGlyphCentre, const Offset(245.5, 350));
    expect(xGlyphAdvance, 490);
    expect(isSimplePolygon(xGlyphPolygon), isTrue);
  });

  test('inset drops an inverted edge: its vertices meet exactly at the '
      'mitre of its neighbours, vertex count kept', () {
    // A 10 x 10 square with a 0.7-unit chamfer: insetting by 2 inverts it
    // (the sketch's midpoint collapse left a sub-pixel loop there).
    const square = [
      Offset(0, 0),
      Offset(10, 0),
      Offset(10, 9.5),
      Offset(9.5, 10),
      Offset(0, 10),
    ];
    final inset = insetPolygon(square, 2);
    expect(inset, hasLength(square.length));
    expect(isSimplePolygon(inset), isTrue);
    expect(inset[0].dx, closeTo(2, 1e-9));
    expect(inset[0].dy, closeTo(2, 1e-9));
    expect(inset[2], inset[3]);
    expect(inset[2].dx, closeTo(8, 1e-9));
    expect(inset[2].dy, closeTo(8, 1e-9));
  });

  test('timeline: expo-in growth and ease-out emptying are monotonic', () {
    var lastS = 0.0;
    var lastR = -1.0;
    for (var o = 0.0; o <= V4dTimeline.grow; o += 1) {
      final s = V4dTimeline.growScale(o, 50);
      final r = V4dTimeline.holeRatio(o);
      expect(s, greaterThanOrEqualTo(lastS));
      expect(r, greaterThanOrEqualTo(lastR));
      lastS = s;
      lastR = r;
    }
    expect(V4dTimeline.growScale(0, 50), 1);
    expect(V4dTimeline.growScale(V4dTimeline.grow, 50), closeTo(50, 1e-9));
    expect(V4dTimeline.holeRatio(0), 0);
    // r3 (D3-Q7): the emptying lasts [empty] ms from the start of the growth
    // (it started at 0 before); this was `holeRatio(empty) == 1`.
    expect(V4dTimeline.holeRatio(V4dTimeline.emptyEnd), 1);
  });

  for (final (screen, unit) in _screens) {
    for (final rim in const [2.5, 3.0]) {
      test('L5-D44 ${screen.width.toInt()}x${screen.height.toInt()} '
          'unit $unit rim $rim: simple, monotonic and contained', () {
        final centre = Offset(screen.width * 0.56, screen.height * 0.42);
        final window = V4dXWindow(centre: centre, unit: unit, rim: rim);
        final smax = window.solveMaxScale(screen);
        expect(smax, greaterThan(1));

        // At Smax the hole holds the whole screen with its 4 px margin.
        final last = window.hole(1, smax);
        for (final corner in [
          const Offset(-4, -4),
          Offset(screen.width + 4, -4),
          Offset(-4, screen.height + 4),
          Offset(screen.width + 4, screen.height + 4),
        ]) {
          expect(pointInPolygon(corner, last), isTrue, reason: '$corner');
        }

        // Dense sampling of s in [1, Smax] (uniform plus the real expo-in
        // frames) and r in [0, 1].
        final scales = <double>{
          for (var i = 0; i <= 240; i++) 1 + (smax - 1) * i / 240,
          for (var o = 0.0; o <= V4dTimeline.grow; o += 2)
            V4dTimeline.growScale(o, smax),
        };
        for (final s in scales) {
          final outer = window.outer(s);
          final inner = window.inner(s);
          expect(isSimplePolygon(outer), isTrue, reason: 'outer s=$s');
          expect(isSimplePolygon(inner), isTrue, reason: 'inner s=$s');
          for (var k = 0; k <= 20; k++) {
            final r = k / 20;
            final hole = window.hole(r, s);
            if (r == 0) {
              // Nothing of Inicio shows before the X starts emptying.
              expect(_area(hole), closeTo(0, 1e-9), reason: 's=$s r=0');
              continue;
            }
            expect(isSimplePolygon(hole), isTrue, reason: 'hole s=$s r=$r');
            if (k % 5 == 0) {
              _expectContained(hole, outer, 'hole in outer s=$s r=$r');
            }
          }
        }

        // The reveal follows the timeline: each frame's hole contains the
        // previous one (never shrinks) and stays inside the outer X.
        List<Offset>? previous;
        for (var o = 0.0; o <= V4dTimeline.grow; o += 4) {
          final s = V4dTimeline.growScale(o, smax);
          final r = V4dTimeline.holeRatio(o);
          final hole = window.hole(r, s);
          _expectContained(hole, window.outer(s), 'frame $o in outer');
          if (previous != null && r > 0) {
            _expectContained(previous, hole, 'frame $o grows');
          }
          if (r > 0) previous = hole;
        }
      });
    }
  }

  test('rim width: 2.5 px in dark, 3 px in light', () {
    expect(V4dXWindow.rimFor(Brightness.dark), 2.5);
    expect(V4dXWindow.rimFor(Brightness.light), 3.0);
  });

  test('even-odd path: a point inside the hole is not filled', () {
    const outer = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)];
    const inner = [Offset(3, 3), Offset(7, 3), Offset(7, 7), Offset(3, 7)];
    final path = evenOddPath([outer, inner]);
    expect(path.fillType, PathFillType.evenOdd);
    expect(path.contains(const Offset(1, 1)), isTrue);
    expect(path.contains(const Offset(5, 5)), isFalse);
  });
}
