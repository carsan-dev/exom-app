// Geometry probe for the alignment tests of the active exercise and the
// active circuit (owner report «PREPÁRATE PARA GRABAR y la de justo debajo
// están desalineadas»): it reads the real layout (render boxes, not widget
// parameters) so the tests measure what is painted.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A horizontal hairline painted by a [BoxDecoration] border.
class ProbeRule {
  const ProbeRule(this.y, this.left, this.right);

  /// Top of the painted line, in global coordinates.
  final double y;
  final double left;
  final double right;

  double get width => right - left;

  @override
  String toString() =>
      'rule y=${y.toStringAsFixed(1)} '
      'x=${left.toStringAsFixed(1)}..${right.toStringAsFixed(1)}';
}

Rect probeRect(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;

void _visit(RenderObject root, void Function(RenderObject) visitor) {
  void walk(RenderObject node) {
    visitor(node);
    node.visitChildren(walk);
  }

  walk(root);
}

/// Every horizontal rule (top or bottom border side) painted under [scope].
List<ProbeRule> probeRules(WidgetTester tester, Finder scope) {
  final rules = <ProbeRule>[];
  _visit(tester.renderObject(scope), (node) {
    if (node is! RenderDecoratedBox || !node.hasSize) return;
    final decoration = node.decoration;
    if (decoration is! BoxDecoration) return;
    final border = decoration.border;
    if (border is! Border) return;
    final rect = probeRect(node);
    if (rect.height <= 0) return;
    if (border.top.style != BorderStyle.none && border.top.width > 0) {
      rules.add(ProbeRule(rect.top, rect.left, rect.right));
    }
    if (border.bottom.style != BorderStyle.none && border.bottom.width > 0) {
      rules.add(
        ProbeRule(rect.bottom - border.bottom.width, rect.left, rect.right),
      );
    }
  });
  rules.sort((a, b) => a.y.compareTo(b.y));
  return rules;
}

/// The rules that cross the whole screen (section separators).
List<ProbeRule> probeFullWidthRules(
  WidgetTester tester,
  Finder scope,
  double screenWidth,
) => [
  for (final rule in probeRules(tester, scope))
    if (rule.left <= 0.5 && rule.right >= screenWidth - 0.5) rule,
];

/// Rects of every painted paragraph under [scope] (text actually laid out).
List<Rect> probeParagraphs(WidgetTester tester, Finder scope) {
  final rects = <Rect>[];
  _visit(tester.renderObject(scope), (node) {
    if (node is RenderParagraph && node.hasSize && node.size.height > 0) {
      rects.add(probeRect(node));
    }
  });
  return rects;
}

/// Problems with the section separators under [scope]: two full-width rules
/// stacked (less than 2 dp apart) or two consecutive full-width rules with no
/// text between them (an empty strip that reads as an empty section).
List<String> probeRuleProblems(
  WidgetTester tester,
  Finder scope,
  double screenWidth,
) {
  final rules = probeFullWidthRules(tester, scope, screenWidth);
  final paragraphs = probeParagraphs(tester, scope);
  final problems = <String>[];
  for (var i = 1; i < rules.length; i++) {
    final a = rules[i - 1];
    final b = rules[i];
    final gap = b.y - a.y;
    if (gap < 2) {
      problems.add('double rule at y=${a.y} / ${b.y}');
      continue;
    }
    final hasText = paragraphs.any(
      (p) => p.center.dy > a.y && p.center.dy < b.y,
    );
    if (!hasText) {
      problems.add(
        'empty strip of ${gap.toStringAsFixed(1)} dp between $a and $b',
      );
    }
  }
  return problems;
}

/// Left edge of the first painted paragraph under [finder].
double probeTextLeft(WidgetTester tester, Finder finder) {
  final paragraphs = probeParagraphs(tester, finder);
  expect(paragraphs, isNotEmpty, reason: 'no text under $finder');
  return paragraphs.map((p) => p.left).reduce((a, b) => a < b ? a : b);
}

Finder kickerText(String text) => find.text(text.toUpperCase());
