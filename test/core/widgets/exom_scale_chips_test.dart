// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomScaleChips, a 1-5 or
// 1-10 radio group composed on ExomChoiceChips.
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

Widget _scale({
  int min = 1,
  int max = 5,
  int? selected = 3,
  ValueChanged<int?>? onChanged,
  bool allowDeselect = false,
}) => ExomScaleChips(
  min: min,
  max: max,
  selected: selected,
  onChanged: onChanged ?? (_) {},
  lowLabel: 'Nada',
  highLabel: 'Muchísimo',
  allowDeselect: allowDeselect,
);

void main() {
  registerTextComponentMatrix('ExomScaleChips 1-5', _scale);
  registerTextComponentMatrix(
    'ExomScaleChips 1-10',
    () => _scale(max: 10, selected: 10),
  );

  testWidgets('composes ExomChoiceChips with one chip per value', (
    tester,
  ) async {
    await pumpComponent(tester, _scale(max: 10));
    expect(find.byType(ExomChoiceChips<int>), findsOneWidget);
    for (var i = 1; i <= 10; i++) {
      expect(find.text('$i'), findsOneWidget);
    }
    expect(find.text('Nada'), findsOneWidget);
    expect(find.text('Muchísimo'), findsOneWidget);
  });

  testWidgets('tapping a value selects it', (tester) async {
    int? value;
    await pumpComponent(
      tester,
      _scale(selected: null, onChanged: (v) => value = v),
    );
    await tester.tap(find.text('4'));
    expect(value, 4);
  });

  testWidgets('tapping the selected value keeps it without allowDeselect', (
    tester,
  ) async {
    final calls = <int?>[];
    await pumpComponent(tester, _scale(onChanged: calls.add));
    await tester.tap(find.text('3'));
    expect(calls, isEmpty);
  });

  testWidgets('tapping the selected value clears it with allowDeselect', (
    tester,
  ) async {
    final calls = <int?>[];
    await pumpComponent(
      tester,
      _scale(onChanged: calls.add, allowDeselect: true),
    );
    await tester.tap(find.text('3'));
    expect(calls, [null]);
  });

  testWidgets('semantics: radio group with the selected value', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _scale());
    expect(
      tester.getSemantics(find.text('3')),
      matchesSemantics(
        label: '3',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('null onChanged disables the scale', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ExomScaleChips(min: 1, max: 5, selected: 2),
    );
    expect(
      tester.getSemantics(find.text('2')),
      matchesSemantics(
        label: '2',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  for (final width in const [320.0, 360.0]) {
    testWidgets('1-10 lays out five equal chips per row at $width dp', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
          child: _scale(max: 10),
        ),
        width: width,
      );
      final one = tester.getRect(find.text('1'));
      final five = tester.getRect(find.text('5'));
      final six = tester.getRect(find.text('6'));
      expect(five.center.dy, one.center.dy);
      expect(six.center.dy, greaterThan(one.center.dy));
      final chipSizes = [
        for (var i = 1; i <= 10; i++)
          tester.getSize(
            find
                .ancestor(
                  of: find.text('$i'),
                  matching: find.byType(GestureDetector),
                )
                .first,
          ),
      ];
      for (final size in chipSizes) {
        expect(size.width, chipSizes.first.width);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  }

  testWidgets('tap targets are at least 48 x 48', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Padding(padding: const EdgeInsets.all(20), child: _scale(max: 10)),
      width: 320,
    );
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('a tap during the crossfade acts at once (reduced too)', (
    tester,
  ) async {
    for (final reduced in const [false, true]) {
      final calls = <int?>[];
      var selected = 1;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, setState) => _scale(
            selected: selected,
            onChanged: (v) {
              calls.add(v);
              setState(() => selected = v ?? selected);
            },
          ),
        ),
        disableAnimations: reduced,
      );
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('5'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(calls, [2, 5]);
      await tester.pumpAndSettle();
    }
  });

  test('asserts a valid range', () {
    expect(() => ExomScaleChips(min: 5, max: 1), throwsAssertionError);
  });
}
