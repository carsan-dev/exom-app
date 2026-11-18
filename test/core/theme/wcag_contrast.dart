// Shared WCAG 2.x contrast helpers for the redesign tests (palette pairs in
// palette_contrast_test.dart and rendered text in
// test/a11y/redesign_baseline_guidelines_test.dart). Not a test file: it has
// no `main` and is only imported.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

double _channel(double value) => value <= 0.04045
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

/// WCAG 2.x relative luminance of an opaque [color].
double relativeLuminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

/// WCAG 2.x contrast ratio between two opaque colours (1..21).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG large text: at least 18 pt regular or 14 pt bold. 1 pt = 4/3 logical
/// px, so 24 px regular or 18.67 px with weight 700 or heavier.
bool isWcagLargeText(double fontSize, FontWeight? weight) {
  const pxPerPt = 4 / 3;
  if (fontSize >= 18 * pxPerPt) return true;
  final bold = (weight ?? FontWeight.w400).value >= FontWeight.w700.value;
  return bold && fontSize >= 14 * pxPerPt;
}

/// Minimum AA ratio for text of [fontSize] and [weight].
double wcagAaMinimum(double fontSize, FontWeight? weight) =>
    isWcagLargeText(fontSize, weight) ? 3.0 : 4.5;

/// `#RRGGBB` (alpha dropped).
String hexRgb(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
