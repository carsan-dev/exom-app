import 'dart:math' as math;
import 'dart:ui';

import 'package:exom_app/features/splash/presentation/v4d/x_glyph.dart';

/// Geometry of the V4d window (L5-D3): the X of «EXOM» becomes a window that
/// grows until it is larger than the screen. Pure functions, so the
/// L5-D44 checks (simple polygons, monotonic reveal) run without a widget.
///
/// Every shape is recomputed in vector at each scale (sketch: «nunca se
/// escala un mapa de bits»). Screen coordinates: logical px, y down.

/// Moves every edge of [points] [distance] px inwards and recomputes the
/// vertices as mitres (sketch `offs`, as corrected by L5-D44).
///
/// An edge shorter than the offset comes out inverted and the polygon would
/// cross itself (loops at the tips of the X, which flicker with the even-odd
/// rule). The sketch collapsed each inverted edge to its midpoint; that still
/// leaves sub-pixel loops where two short edges meet at a tip, because the
/// two midpoints differ. Here an inverted edge is dropped instead (the most
/// inverted first, one at a time) and its vertices become the mitre of the
/// neighbouring edges that remain, so every collapsed vertex sits exactly on
/// the same point. The vertex count is kept (collapsed vertices repeat).
List<Offset> insetPolygon(List<Offset> points, double distance) {
  final n = points.length;
  var area = 0.0;
  for (var i = 0; i < n; i++) {
    final p = points[i];
    final q = points[(i + 1) % n];
    area += p.dx * q.dy - q.dx * p.dy;
  }
  final sign = area > 0 ? 1.0 : -1.0;
  final lines = <_Line>[];
  for (var i = 0; i < n; i++) {
    final p = points[i];
    final q = points[(i + 1) % n];
    final dx = q.dx - p.dx;
    final dy = q.dy - p.dy;
    var length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) length = 1;
    final nx = -dy / length * sign;
    final ny = dx / length * sign;
    lines.add(
      _Line(p.dx + nx * distance, p.dy + ny * distance, dx, dy, nx, ny),
    );
  }
  final active = List<bool>.filled(n, true);
  int previousActive(int i) {
    var k = (i - 1 + n) % n;
    while (!active[k]) {
      k = (k - 1 + n) % n;
    }
    return k;
  }

  int nextActive(int i) {
    var k = (i + 1) % n;
    while (!active[k]) {
      k = (k + 1) % n;
    }
    return k;
  }

  Offset mitre(int a, int b, Offset fallback) {
    final l1 = lines[a];
    final l2 = lines[b];
    final den = l1.dx * l2.dy - l1.dy * l2.dx;
    final scale =
        math.sqrt(l1.dx * l1.dx + l1.dy * l1.dy) *
        math.sqrt(l2.dx * l2.dx + l2.dy * l2.dy);
    if (den.abs() < 1e-6 * scale) {
      return Offset(
        fallback.dx + l2.nx * distance,
        fallback.dy + l2.ny * distance,
      );
    }
    final t = ((l2.x - l1.x) * l2.dy - (l2.y - l1.y) * l2.dx) / den;
    return Offset(l1.x + l1.dx * t, l1.y + l1.dy * t);
  }

  var remaining = n;
  while (remaining > 3) {
    var worst = -1;
    var worstValue = 0.0;
    for (var i = 0; i < n; i++) {
      if (!active[i]) continue;
      final start = mitre(previousActive(i), i, points[i]);
      final end = mitre(i, nextActive(i), points[(i + 1) % n]);
      final l = lines[i];
      final length2 = l.dx * l.dx + l.dy * l.dy;
      if (length2 == 0) continue;
      // Signed length of the offset edge along the original direction.
      final along =
          ((end.dx - start.dx) * l.dx + (end.dy - start.dy) * l.dy) /
          math.sqrt(length2);
      if (along < worstValue) {
        worstValue = along;
        worst = i;
      }
    }
    if (worst < 0) break;
    active[worst] = false;
    remaining--;
  }
  return List<Offset>.generate(n, (j) {
    if (active[j]) return mitre(previousActive(j), j, points[j]);
    // Start of a dropped edge: where its active neighbours meet.
    var k = j;
    while (!active[k]) {
      k = (k + 1) % n;
    }
    return mitre(previousActive(k), k, points[k]);
  });
}

class _Line {
  const _Line(this.x, this.y, this.dx, this.dy, this.nx, this.ny);

  final double x;
  final double y;
  final double dx;
  final double dy;
  final double nx;
  final double ny;
}

/// [points] scaled by [factor] about [centre].
List<Offset> scaleAbout(List<Offset> points, Offset centre, double factor) => [
  for (final p in points) centre + (p - centre) * factor,
];

/// Even-odd point in polygon (sketch `inside`).
bool pointInPolygon(Offset point, List<Offset> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.dy > point.dy) != (b.dy > point.dy) &&
        point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// Distance from [p] to the segment [a]–[b].
double distanceToSegment(Offset p, Offset a, Offset b) {
  final d = b - a;
  final length2 = d.dx * d.dx + d.dy * d.dy;
  if (length2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * d.dx + (p.dy - a.dy) * d.dy) / length2).clamp(
    0.0,
    1.0,
  );
  return (p - (a + d * t)).distance;
}

double _cross(Offset o, Offset a, Offset b) =>
    (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

/// True when the open segments [a]–[b] and [c]–[d] cross at a single interior
/// point of both (touching at an end or overlapping does not count).
bool segmentsCrossProperly(Offset a, Offset b, Offset c, Offset d) {
  const eps = 1e-9;
  final d1 = _cross(c, d, a);
  final d2 = _cross(c, d, b);
  final d3 = _cross(a, b, c);
  final d4 = _cross(a, b, d);
  return ((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) &&
      ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps));
}

bool _onSegment(Offset p, Offset a, Offset b, double eps) =>
    distanceToSegment(p, a, b) <= eps;

/// True when [polygon] is simple: once consecutive repeated vertices are
/// merged, no two non-adjacent edges touch or cross, and adjacent edges do
/// not fold back over each other. A polygon whose vertices all coincide
/// (zero area) is not simple.
bool isSimplePolygon(List<Offset> polygon, {double eps = 1e-7}) {
  final pts = <Offset>[];
  for (final p in polygon) {
    if (pts.isEmpty || (pts.last - p).distance > eps) pts.add(p);
  }
  while (pts.length > 1 && (pts.first - pts.last).distance <= eps) {
    pts.removeLast();
  }
  final n = pts.length;
  if (n < 3) return false;
  for (var i = 0; i < n; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % n];
    for (var j = i + 1; j < n; j++) {
      final c = pts[j];
      final d = pts[(j + 1) % n];
      final adjacent = j == i + 1 || (i == 0 && j == n - 1);
      if (adjacent) {
        // Shared vertex: the other ends must not lie on the other edge
        // (an edge folding back over its neighbour).
        final shared = j == i + 1 ? b : a;
        final farA = j == i + 1 ? a : b;
        final farC = j == i + 1 ? d : c;
        if (_onSegment(farC, shared, farA, eps) ||
            _onSegment(farA, shared, farC, eps)) {
          return false;
        }
        continue;
      }
      if (segmentsCrossProperly(a, b, c, d) ||
          _onSegment(a, c, d, eps) ||
          _onSegment(b, c, d, eps) ||
          _onSegment(c, a, b, eps) ||
          _onSegment(d, a, b, eps)) {
        return false;
      }
    }
  }
  return true;
}

/// One path with every contour of [contours], filled with the even-odd rule
/// (sketch `path(evenodd, …)`).
Path evenOddPath(List<List<Offset>> contours) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final contour in contours) {
    if (contour.length < 3) continue;
    path.addPolygon(contour, true);
  }
  return path;
}

/// The X window at a screen position: [centre] is where the glyph centre
/// sits, [unit] the logical px per font unit and [rim] the outline width.
class V4dXWindow {
  const V4dXWindow({
    required this.centre,
    required this.unit,
    required this.rim,
  });

  final Offset centre;
  final double unit;
  final double rim;

  /// Rim width in logical px: 2.5 in dark, 3 in light (sketch `RIM`).
  static double rimFor(Brightness brightness) =>
      brightness == Brightness.light ? 3.0 : 2.5;

  /// Outer contour of the X at scale [s] (sketch `at(s)`).
  List<Offset> outer(double s) => [
    for (final p in xGlyphPolygon)
      Offset(
        centre.dx + (p.dx - xGlyphCentre.dx) * unit * s,
        centre.dy - (p.dy - xGlyphCentre.dy) * unit * s,
      ),
  ];

  /// Inner contour: the outer one moved [rim] px inwards.
  List<Offset> inner(double s) => insetPolygon(outer(s), rim);

  /// The hole at emptying ratio [r] (0: closed, 1: the whole inner contour)
  /// and scale [s] (sketch `hole(r, s)`).
  List<Offset> hole(double r, double s) => scaleAbout(inner(s), centre, r);

  /// Smallest scale at which the hole (rim included) holds [screen] with a
  /// [margin] px border (sketch `Smax`, grown by 1 % steps up to 400).
  double solveMaxScale(Size screen, {double margin = 4}) {
    var s = 1.0;
    while (!_fits(s, screen, margin) && s < 400) {
      s *= 1.01;
    }
    return s;
  }

  bool _fits(double s, Size screen, double margin) {
    final h = hole(1, s);
    final w = screen.width;
    final ht = screen.height;
    for (final p in h) {
      if (p.dx > -margin &&
          p.dx < w + margin &&
          p.dy > -margin &&
          p.dy < ht + margin) {
        return false;
      }
    }
    for (var x = -margin; x <= w + margin; x += 8) {
      if (!pointInPolygon(Offset(x, -margin), h) ||
          !pointInPolygon(Offset(x, ht + margin), h)) {
        return false;
      }
    }
    for (var y = -margin; y <= ht + margin; y += 8) {
      if (!pointInPolygon(Offset(-margin, y), h) ||
          !pointInPolygon(Offset(w + margin, y), h)) {
        return false;
      }
    }
    return true;
  }
}
