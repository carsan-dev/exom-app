// L5-A4 D2 (docs/plans/rediseno-app-l5-contrato-v2.md, L5-A4): the opt-in
// `fitLabels` of ExomChoiceChips with columns. Without it nothing changes.
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_nonlinear_text_scaler.dart';
import 'exom_component_harness.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

Widget _chips({required bool fit, TextScaler? scaler}) => Builder(
  builder: (context) {
    final chips = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ExomChoiceChips<String>(
        options: _months,
        selected: 'Nov',
        columns: 4,
        fitLabels: fit,
        labelOf: (m) => m,
        onSelected: (_) {},
      ),
    );
    if (scaler == null) return chips;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: chips,
    );
  },
);

Iterable<RenderParagraph> _paragraphs() => find
    .descendant(
      of: find.byType(ExomChoiceChips<String>),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map((e) => e.renderObject! as RenderParagraph);

bool _broken(RenderParagraph p) =>
    p.getMinIntrinsicWidth(double.infinity) > p.size.width + 0.01;

double _size(WidgetTester tester, String text) => tester
    .widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    )
    .style
    .fontSize!;

void main() {
  testWidgets('default: labels keep 16 and «May» wraps at 320 dp 1.6x', (
    tester,
  ) async {
    await pumpComponent(tester, _chips(fit: false), width: 320, textScale: 1.6);
    expect(_size(tester, 'May'), 16);
    expect(_paragraphs().where(_broken), isNotEmpty);
  });

  for (final android in [false, true]) {
    for (final (width, scale) in const [
      (320.0, 1.3),
      (320.0, 1.6),
      (360.0, 1.6),
      (320.0, 2.0),
    ]) {
      testWidgets('fitLabels: no word breaks at $width dp ${scale}x '
          '${android ? 'Android nonlinear' : 'linear'}', (tester) async {
        await pumpComponent(
          tester,
          _chips(
            fit: true,
            scaler: android ? AndroidNonlinearTextScaler(scale) : null,
          ),
          width: width,
          textScale: android ? 1.0 : scale,
        );
        expectNoOverflow(tester);
        expect(_paragraphs(), hasLength(12));
        for (final p in _paragraphs()) {
          expect(_broken(p), isFalse, reason: p.text.toPlainText());
        }
        final sizes = {for (final m in _months) _size(tester, m)};
        expect(sizes, hasLength(1), reason: 'the labels shrink together');
      });
    }
  }

  testWidgets('fitLabels: labels that fit keep their 16', (tester) async {
    await pumpComponent(tester, _chips(fit: true), width: 360);
    for (final m in _months) {
      expect(_size(tester, m), 16);
    }
  });

  // L5-A4b: the refit never goes below 10 (10 sp of visible text); a word
  // that still does not fit splits instead of becoming unreadable.
  testWidgets('fitLabels: extreme width keeps the 10 floor', (tester) async {
    await pumpComponent(tester, _chips(fit: true), width: 60, textScale: 2.0);
    for (final month in _months) {
      expect(_size(tester, month), greaterThanOrEqualTo(10));
    }
  });
}
