// Shared requirements of redesign L5 §2.1 for the text components of T0.2:
// 320/360 dp at text scale 1.0/1.3/1.6 without overflow or ellipsis, 2.0 inside
// a SingleChildScrollView, text contrast in both themes and no lime ink in the
// light theme. Not a test file: it has no `main` and is only imported.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'expect_no_lime_ink.dart';

/// Why [paragraph] may hide text, or null when it cannot.
///
/// A paragraph hides text when it asks for an ellipsis (with or without
/// `maxLines`), when it cannot wrap (`softWrap: false`) and its overflow is not
/// `visible` (the layout may then clip or fade it), or when it really dropped
/// lines (`didExceedMaxLines`).
String? textHidingReason(RenderParagraph paragraph) {
  if (paragraph.overflow == TextOverflow.ellipsis) return 'overflow: ellipsis';
  if (!paragraph.softWrap && paragraph.overflow != TextOverflow.visible) {
    return 'softWrap: false with overflow ${paragraph.overflow.name}';
  }
  if (paragraph.didExceedMaxLines) return 'lines dropped by maxLines';
  return null;
}

/// Fails when any painted paragraph can cut its text (see [textHidingReason]).
void expectNoEllipsis(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      textHidingReason(paragraph),
      isNull,
      reason: 'text may be cut: "${paragraph.text.toPlainText()}"',
    );
  }
}

/// Registers the common §2.1 tests for the component built by [build].
void registerTextComponentMatrix(
  String name,
  Widget Function() build, {
  bool checkContrast = true,
}) {
  for (final width in const [320.0, 360.0]) {
    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets('$name: ${width.toInt()} dp at $scale x, no overflow', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          SingleChildScrollView(child: build()),
          width: width,
          textScale: scale,
        );
        expectNoOverflow(tester);
        expectNoEllipsis(tester);
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('$name: 2.0 x inside a scroll view is reachable '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 300),
              build(),
              const SizedBox(height: 300),
            ],
          ),
        ),
        width: 320,
        height: 480,
        textScale: 2.0,
        brightness: brightness,
      );
      expectNoOverflow(tester);
      final scrollable = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scrollable).position;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pump();
      // Floating point noise only (fractional layout heights can leave the
      // clamped drag 1e-13 px short of the end); a real shortfall is far
      // larger than the tolerance.
      expect(
        position.pixels,
        moreOrLessEquals(position.maxScrollExtent, epsilon: 1e-6),
      );
      expectNoOverflow(tester);
      expectNoEllipsis(tester);
    });
  }

  if (checkContrast) {
    for (final brightness in Brightness.values) {
      testWidgets('$name: text contrast (${brightness.name})', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpComponent(
          tester,
          Padding(padding: const EdgeInsets.all(20), child: build()),
          brightness: brightness,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  testWidgets('$name: no lime ink in the light theme', (tester) async {
    await pumpComponent(
      tester,
      Padding(padding: const EdgeInsets.all(20), child: build()),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });
}
