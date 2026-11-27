// Redesign L5 (docs/plans/rediseno-app-l5-contrato-v2.md, D13): in the light
// theme lime (#BAF23A) is a fill only, never ink. `expectNoLimeInk` walks the
// rendered tree and fails if lime shows up as text, icon or thin line. Colours
// are compared by RGB and alpha is ignored (a translucent lime is still lime).
//
// What it inspects:
//  * every RenderParagraph: `color` and `decorationColor` (underlines,
//    overlines, strikethroughs) of every TextSpan, including the root span.
//    Icons are painted as paragraphs too, so Icon glyphs are covered, and an
//    Icon widget's explicit colour is also checked;
//  * borders with a visible side: Border and BorderDirectional of any
//    BoxDecoration (DecoratedBox), the OutlinedBorder side of a
//    ShapeDecoration, and the OutlinedBorder side of Material.shape;
//  * painters: the whole subtree is painted onto a flutter_test
//    TestRecordingCanvas (the one behind the `paints` matcher) and every
//    recorded call is checked. Fails on a lime Paint with
//    PaintingStyle.stroke, and on drawLine / drawPoints / drawRawPoints with a
//    lime Paint whatever its style (those always stroke). This covers
//    CustomPaint painter and foregroundPainter and any other RenderObject.
//
// Lime as a FILL is allowed and never reported: ColoredBox / Container /
// BoxDecoration.color backgrounds and Paint with PaintingStyle.fill.
//
// Known limits (not faked):
//  * a Paint using a shader
//    (gradient) is judged by its `color` only; lime inside a shader is not seen;
//  * drawShadow / drawImage* / drawAtlas / drawVertices / drawColor are not
//    judged (no stroke semantics) and saveLayer paints are ignored;
//  * Material.shape and ShapeDecoration are only inspected through
//    OutlinedBorder.side; shapes that are not OutlinedBorder are not read, but
//    their actual painting is still caught by the recorded canvas check when
//    they stroke;
//  * ink drawn by platform views or textures is not part of the render tree
//    paint and cannot be seen;
//  * text painted by a RenderParagraph is judged from its spans, not from the
//    recorded drawParagraph call, so a Paint foreground set via
//    TextStyle.foreground is not checked.
//
// Dark theme: lime is the data colour there, so the check passes without
// scanning unless a [brightness] override says otherwise.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The forbidden light-theme ink: lime `#BAF23A`.
const Color kLimeInk = Color(0xFFBAF23A);

bool _isLime(Color? color) =>
    color != null &&
    color.a > 0 &&
    (color.toARGB32() & 0xFFFFFF) == (kLimeInk.toARGB32() & 0xFFFFFF);

const _strokeAlways = {#drawLine, #drawPoints, #drawRawPoints};
const _notInk = {
  #drawImage,
  #drawImageRect,
  #drawImageNine,
  #drawAtlas,
  #drawRawAtlas,
  #drawVertices,
  #drawShadow,
  #drawColor,
  #drawParagraph,
};

String _callName(Symbol name) {
  final raw = name.toString(); // Symbol("drawLine")
  return raw.substring(8, raw.length - 2);
}

/// Lime ink among the calls recorded by [canvas]. The recorder copies each
/// Paint argument at call time, so a Paint reused with another style is judged
/// as it was when drawn.
Set<String> _limePaintCalls(TestRecordingCanvas canvas) {
  final found = <String>{};
  for (final recorded in canvas.invocations) {
    final call = recorded.invocation;
    if (_notInk.contains(call.memberName)) continue;
    for (final arg in call.positionalArguments) {
      if (arg is! ui.Paint || !_isLime(arg.color)) continue;
      if (_strokeAlways.contains(call.memberName)) {
        found.add('${_callName(call.memberName)} painted in lime');
      } else if (arg.style == PaintingStyle.stroke) {
        found.add('${_callName(call.memberName)} stroked in lime');
      }
    }
  }
  return found;
}

bool _visibleLimeSide(BorderSide side) =>
    side.style != BorderStyle.none && _isLime(side.color);

/// Returns a description of every lime ink found under [root] (the whole app
/// when null). Empty when none.
List<String> findLimeInk(WidgetTester tester, {Finder? root}) {
  final found = <String>[];
  final start = root == null
      ? tester.binding.rootElement!
      : tester.element(root.first);

  void visit(Element element) {
    final widget = element.widget;
    final render = element.renderObject;
    if (render is RenderParagraph) {
      void checkSpan(InlineSpan span) {
        if (span is TextSpan) {
          if (_isLime(span.style?.color)) {
            found.add('text "${span.text ?? ''}" painted in lime');
          }
          if (_isLime(span.style?.decorationColor)) {
            found.add('text "${span.text ?? ''}" decoration painted in lime');
          }
        }
      }

      checkSpan(render.text);
      render.text.visitChildren((span) {
        checkSpan(span);
        return true;
      });
    }
    if (widget is Icon && _isLime(widget.color)) {
      found.add('icon ${widget.icon} painted in lime');
    }
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        final border = decoration.border;
        final sides = switch (border) {
          Border() => [border.top, border.right, border.bottom, border.left],
          BorderDirectional() => [
            border.top,
            border.start,
            border.end,
            border.bottom,
          ],
          _ => const <BorderSide>[],
        };
        if (sides.any(_visibleLimeSide)) {
          found.add('border side painted in lime');
        }
      } else if (decoration is ShapeDecoration) {
        final shape = decoration.shape;
        if (shape is OutlinedBorder && _visibleLimeSide(shape.side)) {
          found.add('shape side painted in lime');
        }
      }
    }
    if (widget is Material) {
      final shape = widget.shape;
      if (shape is OutlinedBorder && _visibleLimeSide(shape.side)) {
        found.add('Material shape side painted in lime');
      }
    }
    element.visitChildren(visit);
  }

  visit(start);

  final startRender = start.renderObject;
  if (startRender != null) {
    final canvas = TestRecordingCanvas();
    startRender.paint(TestRecordingPaintingContext(canvas), Offset.zero);
    found.addAll(_limePaintCalls(canvas));
  }
  return found;
}

/// Fails when lime is used as ink under [root] in the light theme.
void expectNoLimeInk(
  WidgetTester tester, {
  Finder? root,
  Brightness? brightness,
}) {
  final start = root == null
      ? tester.binding.rootElement!
      : tester.element(root.first);
  var effective = brightness;
  if (effective == null) {
    Element? themed;
    void find(Element e) {
      if (themed != null) return;
      if (e.widget is Theme) {
        themed = e;
        return;
      }
      e.visitChildren(find);
    }

    find(start);
    final found = themed;
    effective = found == null
        ? Theme.of(start).brightness
        : (found.widget as Theme).data.brightness;
  }
  if (effective == Brightness.dark) return;
  final found = findLimeInk(tester, root: root);
  if (found.isNotEmpty) {
    fail('Lime (#BAF23A) used as ink in the light theme: ${found.join('; ')}');
  }
}
