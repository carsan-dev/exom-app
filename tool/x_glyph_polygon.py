"""Provenance and check of the V4d «X» polygon (L5-D3, decision D3-Q1).

The splash opens through the X of «EXOM». Its shape is the polygon `XG` of
the approved sketch (docs/bocetos/rediseno-exom-app/extension/m10-arranque.html,
V4d engine, `var XG`): 32 vertices in font units of Barlow Condensed 800
(1000 units per em, y up, origin on the baseline, advance 490). The vertices
are points of the X contour of assets/fonts/barlow-condensed-800.ttf: the
on-curve points, the two waist control points and, at the four rounded
corners and the two notches, one point on the curve.

The owner fixed that polygon as the source of truth (D3-Q1), so this script
does not invent a new one. It:

* checks the polygon against the font: every vertex lies on the flattened
  outline and every point of the outline lies on the polygon, both within
  TOLERANCE font units (the corners are rounded by a few units);
* checks the sketch centre (XCU, XCV) against the outline bounding box;
* checks units per em and the advance width;
* checks that the Dart constant in lib/ matches this polygon exactly;
* with --emit, prints the Dart constant (to regenerate the lib/ file).

Usage (from the repo root, fontTools installed):

    python tool/x_glyph_polygon.py            # check, exit 1 on failure
    python tool/x_glyph_polygon.py --emit     # print the Dart constant
"""

import math
import re
import sys
from pathlib import Path

from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "barlow-condensed-800.ttf"
DART = ROOT / "lib" / "features" / "splash" / "presentation" / "v4d" / "x_glyph.dart"

# m10-arranque.html, V4d engine, `var XG` (copied verbatim).
XG = [
    (22, 14), (156, 347), (157, 350), (156, 353), (22, 686), (21, 692),
    (31, 700), (176, 700), (189, 690), (243, 525), (246, 522), (249, 525),
    (302, 690), (315, 700), (459, 700), (469, 692), (468, 686), (334, 353),
    (333, 350), (334, 347), (468, 14), (469, 8), (459, 0), (316, 0),
    (303, 10), (249, 174), (246, 178), (243, 174), (188, 10), (175, 0),
    (31, 0), (21, 8),
]
XCU, XCV = 245.5, 350.0
UPM = 1000
ADVANCE = 490
TOLERANCE = 3.5  # font units (0.35 % of the em; the rounded corners deviate ~3.1)
CENTRE_TOLERANCE = 1.0  # XCU is the sketch value; the outline bbox centre is 245


class _Flatten(BasePen):
    """Flattens the glyph into one list of points per contour."""

    def __init__(self, glyph_set, steps=24):
        super().__init__(glyph_set)
        self.steps = steps
        self.contours = []
        self._current = None

    def _moveTo(self, pt):
        self._current = [pt]
        self.contours.append(self._current)

    def _lineTo(self, pt):
        self._current.append(pt)

    def _qCurveToOne(self, pt1, pt2):
        x0, y0 = self._current[-1]
        for i in range(1, self.steps + 1):
            t = i / self.steps
            a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
            self._current.append(
                (a * x0 + b * pt1[0] + c * pt2[0], a * y0 + b * pt1[1] + c * pt2[1])
            )

    def _curveToOne(self, pt1, pt2, pt3):
        x0, y0 = self._current[-1]
        for i in range(1, self.steps + 1):
            t = i / self.steps
            a, b = (1 - t) ** 3, 3 * (1 - t) ** 2 * t
            c, d = 3 * (1 - t) * t * t, t ** 3
            self._current.append((
                a * x0 + b * pt1[0] + c * pt2[0] + d * pt3[0],
                a * y0 + b * pt1[1] + c * pt2[1] + d * pt3[1],
            ))

    def _closePath(self):
        self._current = None


def _segment_distance(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / length2))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (ay + t * dy))


def _distance_to_polyline(p, pts):
    n = len(pts)
    return min(_segment_distance(p, pts[i], pts[(i + 1) % n]) for i in range(n))


def _densify(pts, step=2.0):
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        k = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        for j in range(k):
            out.append((a[0] + (b[0] - a[0]) * j / k, a[1] + (b[1] - a[1]) * j / k))
    return out


def dart_constant():
    # One vertex per line, as `dart format` lays the list out.
    rows = [f"  Offset({x}, {y})," for x, y in XG]
    return "const List<Offset> xGlyphPolygon = <Offset>[\n" + "\n".join(rows) + "\n];"


def check():
    font = TTFont(str(FONT))
    errors = []
    upm = font["head"].unitsPerEm
    glyph_name = font.getBestCmap()[ord("X")]
    advance = font["hmtx"][glyph_name][0]
    if upm != UPM:
        errors.append(f"unitsPerEm {upm} != {UPM}")
    if advance != ADVANCE:
        errors.append(f"advance {advance} != {ADVANCE}")
    pen = _Flatten(font.getGlyphSet())
    font.getGlyphSet()[glyph_name].draw(pen)
    if len(pen.contours) != 1:
        errors.append(f"expected one contour, found {len(pen.contours)}")
    outline = pen.contours[0]
    xs = [p[0] for p in outline]
    ys = [p[1] for p in outline]
    cu, cv = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    if abs(cu - XCU) > CENTRE_TOLERANCE or abs(cv - XCV) > CENTRE_TOLERANCE:
        errors.append(f"centre ({cu}, {cv}) != ({XCU}, {XCV})")
    if len(XG) != 32:
        errors.append(f"XG has {len(XG)} vertices, expected 32")
    vertex_dev = max(_distance_to_polyline(v, outline) for v in XG)
    outline_dev = max(_distance_to_polyline(p, XG) for p in outline)
    polygon_dev = max(_distance_to_polyline(p, outline) for p in _densify(XG))
    for name, dev in (("vertex-to-outline", vertex_dev), ("outline-to-polygon", outline_dev), ("polygon-to-outline", polygon_dev)):
        print(f"{name}: max {dev:.3f} font units (tolerance {TOLERANCE})")
        if dev > TOLERANCE:
            errors.append(f"{name} deviation {dev:.3f} > {TOLERANCE}")
    if DART.exists():
        source = DART.read_text(encoding="utf-8")
        found = [
            (int(a), int(b))
            for a, b in re.findall(r"Offset\((-?\d+), (-?\d+)\)", source.split("xGlyphPolygon", 1)[-1].split("];", 1)[0])
        ]
        if found != XG:
            errors.append(f"{DART.relative_to(ROOT)} does not match XG ({len(found)} vertices)")
        else:
            print(f"{DART.relative_to(ROOT).as_posix()}: matches XG ({len(found)} vertices)")
    else:
        errors.append(f"missing {DART}")
    for e in errors:
        print("FAIL:", e)
    if not errors:
        print("OK: XG matches the X of", FONT.relative_to(ROOT).as_posix())
    return not errors


if __name__ == "__main__":
    if "--emit" in sys.argv:
        print(dart_constant())
        sys.exit(0)
    sys.exit(0 if check() else 1)
