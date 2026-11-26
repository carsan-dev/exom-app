import 'dart:ui';

/// The «X» of Barlow Condensed 800 as a polygon (L5-D3, decision D3-Q1).
///
/// 32 vertices in font units (1000 per em), y up, origin on the baseline at
/// the glyph's left side bearing. Copied verbatim from the approved sketch
/// (`docs/bocetos/rediseno-exom-app/extension/m10-arranque.html`, V4d engine,
/// `var XG`); the vertices are points of the X contour of
/// `assets/fonts/barlow-condensed-800.ttf`. `tool/x_glyph_polygon.py` checks
/// it against the font (and that this file matches) and regenerates it with
/// `--emit`. Do not edit by hand.
const List<Offset> xGlyphPolygon = <Offset>[
  Offset(22, 14),
  Offset(156, 347),
  Offset(157, 350),
  Offset(156, 353),
  Offset(22, 686),
  Offset(21, 692),
  Offset(31, 700),
  Offset(176, 700),
  Offset(189, 690),
  Offset(243, 525),
  Offset(246, 522),
  Offset(249, 525),
  Offset(302, 690),
  Offset(315, 700),
  Offset(459, 700),
  Offset(469, 692),
  Offset(468, 686),
  Offset(334, 353),
  Offset(333, 350),
  Offset(334, 347),
  Offset(468, 14),
  Offset(469, 8),
  Offset(459, 0),
  Offset(316, 0),
  Offset(303, 10),
  Offset(249, 174),
  Offset(246, 178),
  Offset(243, 174),
  Offset(188, 10),
  Offset(175, 0),
  Offset(31, 0),
  Offset(21, 8),
];

/// Centre of the X in font units (sketch `XCU`, `XCV`); the window grows
/// from here.
const Offset xGlyphCentre = Offset(245.5, 350);

/// Advance width of the X in font units.
const double xGlyphAdvance = 490;

/// Font units per em of Barlow Condensed 800.
const double xGlyphUnitsPerEm = 1000;
