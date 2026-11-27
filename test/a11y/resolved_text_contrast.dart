// Deterministic resolution of the violations reported by Flutter's
// textContrastGuideline. Not a test file: it has no `main` and is only
// imported.
//
// textContrastGuideline samples rendered pixels: it takes the text box +4 px
// and compares the most frequent lighter and darker colours. Glyph
// rasterisation differs between hosts (DirectWrite on Windows, FreeType on
// Linux CI): with the thinner Linux anti-aliasing a 14-16 px DM Sans label has
// fewer pure text pixels than the partially covered row of its own underline,
// so the sampler measures that underline shade instead of the text (e.g.
// «Saltar descanso», inside its text box: 116 pure #101111 pixels against 122
// underline pixels of #8D8D88 on Linux, 260 against 100 on Windows). Every
// label the sampler reports is therefore resolved here from the widget tree
// and the frame: text colour from the effective style, background from the
// dominant colour behind it, and it must reach WCAG AA (4.5, or 3.0 for large
// text). A real low-contrast text still fails; a reported label that cannot be
// resolved fails too, it is never skipped.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/theme/wcag_contrast.dart';

/// RGBA capture of the whole scene at 1 logical px per pixel, taken the way
/// textContrastGuideline takes it (render view layer -> toImage).
class SceneCapture {
  SceneCapture._(this.bytes, this.width, this.height);
  final ByteData bytes;
  final int width;
  final int height;

  static Future<SceneCapture> take(WidgetTester tester) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    late int width;
    late int height;
    final bytes = await tester.binding.runAsync<ByteData?>(() async {
      final image = await layer.toImage(
        view.paintBounds,
        pixelRatio: 1 / view.flutterView.devicePixelRatio,
      );
      width = image.width;
      height = image.height;
      final data = await image.toByteData();
      image.dispose();
      return data;
    });
    return SceneCapture._(bytes!, width, height);
  }

  /// ARGB32 -> pixel count inside [rect] (global logical coordinates).
  Map<int, int> histogram(Rect rect) {
    final counts = <int, int>{};
    final left = rect.left.floor().clamp(0, width);
    final top = rect.top.floor().clamp(0, height);
    final right = rect.right.ceil().clamp(0, width);
    final bottom = rect.bottom.ceil().clamp(0, height);
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final o = (y * width + x) * 4;
        final argb = bytes.getUint8(o + 3) << 24 |
            bytes.getUint8(o) << 16 |
            bytes.getUint8(o + 1) << 8 |
            bytes.getUint8(o + 2);
        counts[argb] = (counts[argb] ?? 0) + 1;
      }
    }
    return counts;
  }
}

typedef ResolvedContrast = ({
  Color text,
  Color background,
  double ratio,
  double minimum,
});

/// Resolves the real contrast of every visible `Text(label)`: the text colour
/// comes from the effective style (DefaultTextStyle merged with the widget
/// style); the background is the most frequent colour inside the text's paint
/// bounds (uncropped) in [capture]. The text colour must itself appear among
/// those pixels, which guards against resolving the wrong widget.
List<ResolvedContrast> resolvedTextContrast(
  WidgetTester tester,
  String label,
  SceneCapture capture,
) {
  final elements = find.text(label).hitTestable().evaluate().toList();
  expect(elements, isNotEmpty, reason: 'no visible Text "$label"');
  final resolved = <ResolvedContrast>[];
  for (final element in elements) {
    final widget = element.widget;
    expect(widget, isA<Text>(), reason: '"$label" is not a Text widget');
    final style =
        DefaultTextStyle.of(element).style.merge((widget as Text).style);
    expect(
      style.foreground,
      isNull,
      reason: '"$label" paints with a foreground Paint',
    );
    final text = style.color;
    expect(text, isNotNull, reason: '"$label" has no resolved text colour');
    expect(text!.a, 1.0, reason: '"$label" text colour is translucent');
    final box = element.renderObject! as RenderBox;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      box.paintBounds,
    );
    final counts = capture.histogram(rect);
    expect(
      counts[text.toARGB32()] ?? 0,
      greaterThan(0),
      reason:
          'text colour ${hexRgb(text)} of "$label" not found in its paint bounds',
    );
    final background = Color(
      counts.entries.reduce((a, b) => b.value > a.value ? b : a).key,
    );
    expect(
      background,
      isNot(text),
      reason: '"$label": the text colour dominates its own box',
    );
    resolved.add((
      text: text,
      background: background,
      ratio: contrastRatio(text, background),
      minimum: wcagAaMinimum(style.fontSize!, style.fontWeight),
    ));
  }
  return resolved;
}

/// The text textContrastGuideline looked up for the semantics node [id]: the
/// label of the node's semantics data (merged from its descendants when the
/// node merges them, e.g. a `MergeSemantics` button), or its value when the
/// label is empty. Null when no node has that id.
///
/// The node's own `toString` in the guideline's reason omits a merged label,
/// so the label is read from the tree, exactly as the guideline reads it.
String? guidelineTextOfNode(WidgetTester tester, int id) {
  SemanticsNode? found;
  bool visit(SemanticsNode node) {
    if (node.id == id) {
      found = node;
      return false;
    }
    node.visitChildren(visit);
    return found == null;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
    if (found != null) break;
  }
  final node = found;
  if (node == null) return null;
  final data = node.getSemanticsData();
  return data.label.isEmpty ? data.value : data.label;
}

/// Node ids of the textContrastGuideline violations in [reason], in order.
/// Fails if the reason holds a node chunk that is not a contrast violation.
List<int> contrastViolationNodeIds(String? reason) {
  if (reason == null || reason.trim().isEmpty) return const [];
  final ids = <int>[];
  final chunks = reason
      .split(RegExp(r'(?=SemanticsNode#\d+\()'))
      .where((chunk) => chunk.trim().startsWith('SemanticsNode#'));
  for (final chunk in chunks) {
    expect(
      chunk,
      contains('Expected contrast ratio of at least'),
      reason: 'unexpected textContrastGuideline violation: $chunk',
    );
    ids.add(int.parse(RegExp(r'^\s*SemanticsNode#(\d+)\(').firstMatch(chunk)!.group(1)!));
  }
  return ids;
}

/// Evaluates textContrastGuideline on the current frame and resolves every
/// violation it reports with [resolvedTextContrast]: the test passes when the
/// sampler passes or every label it flags really reaches WCAG AA.
Future<void> expectResolvedTextContrast(WidgetTester tester) async {
  final result = await textContrastGuideline.evaluate(tester);
  if (result.passed) return;
  final ids = contrastViolationNodeIds(result.reason);
  expect(
    ids,
    isNotEmpty,
    reason: 'textContrastGuideline failed without a node: ${result.reason}',
  );
  final capture = await SceneCapture.take(tester);
  for (final id in ids) {
    final label = guidelineTextOfNode(tester, id);
    expect(label, isNotNull, reason: 'SemanticsNode#$id is gone');
    for (final r in resolvedTextContrast(tester, label!, capture)) {
      expect(
        r.ratio,
        greaterThanOrEqualTo(r.minimum),
        reason: '"$label" ${hexRgb(r.text)} on ${hexRgb(r.background)}',
      );
    }
  }
}
