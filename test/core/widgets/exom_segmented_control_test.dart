// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomSegmentedControl, the
// 2-3 option segmented control of ESPEC §3 (`.segc`).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

enum _View { week, month, year }

String _label(_View v) => switch (v) {
  _View.week => 'Semana',
  _View.month => 'Mes completo con sus sesiones',
  _View.year => 'Año',
};

Widget _control({
  _View selected = _View.month,
  ValueChanged<_View>? onChanged,
  List<_View> options = _View.values,
}) => ExomSegmentedControl<_View>(
  options: options,
  selected: selected,
  labelOf: _label,
  onChanged: onChanged ?? (_) {},
);

Widget _stateful(List<_View> taps, {_View initial = _View.week}) {
  var selected = initial;
  return StatefulBuilder(
    builder: (context, setState) => _control(
      selected: selected,
      onChanged: (v) {
        taps.add(v);
        setState(() => selected = v);
      },
    ),
  );
}

Rect _fillRect(WidgetTester tester) =>
    tester.getRect(find.byKey(ExomSegmentedControl.fillKey));

void main() {
  registerTextComponentMatrix('ExomSegmentedControl', _control);

  testWidgets('labels wrap instead of being cut and every segment is >= 48 '
      'high', (tester) async {
    await pumpComponent(tester, _control(), width: 320, textScale: 1.6);
    expectNoOverflow(tester);
    final long = tester.getSize(find.text(_label(_View.month)));
    final short = tester.getSize(find.text(_label(_View.week)));
    // The long label takes several lines.
    expect(long.height, greaterThan(short.height * 1.5));
    expect(
      tester.getSize(find.byType(ExomSegmentedControl<_View>)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('control is at least 48 high with short labels', (tester) async {
    await pumpComponent(
      tester,
      _control(options: const [_View.week, _View.year], selected: _View.week),
    );
    expect(
      tester.getSize(find.byType(ExomSegmentedControl<_View>)).height,
      greaterThanOrEqualTo(48),
    );
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('selection fill and label use the selection tokens, never '
        'lime (${brightness.name})', (tester) async {
      await pumpComponent(tester, _control(), brightness: brightness);
      await tester.pumpAndSettle();
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(ExomSegmentedControl.fillKey),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, palette.selectionFill);
      expect(fill.color, isNot(palette.limeFill));
      final selectedStyle = DefaultTextStyle.of(
        tester.element(find.text(_label(_View.month))),
      ).style;
      expect(selectedStyle.color, palette.onSelectionFill);
      final otherStyle = DefaultTextStyle.of(
        tester.element(find.text(_label(_View.week))),
      ).style;
      expect(otherStyle.color, palette.textPrimary);
    });
  }

  testWidgets('the fill slides to the tapped segment in 200 ms', (
    tester,
  ) async {
    final taps = <_View>[];
    await pumpComponent(tester, _stateful(taps));
    final start = _fillRect(tester);
    await tester.tap(find.text(_label(_View.year)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = _fillRect(tester);
    expect(middle.left, greaterThan(start.left));
    await tester.pump(const Duration(milliseconds: 101));
    final end = _fillRect(tester);
    final yearSegment = tester.getRect(
      find.byKey(const ValueKey('exom-segment-2')),
    );
    expect(end.left, closeTo(yearSegment.left, 0.5));
    expect(middle.left, lessThan(end.left));
    expect(taps, [_View.year]);
  });

  testWidgets('reduced motion: no slide, the selection fades in 120 ms', (
    tester,
  ) async {
    final taps = <_View>[];
    await pumpComponent(tester, _stateful(taps), disableAnimations: true);
    expect(find.byKey(ExomSegmentedControl.fillKey), findsNothing);
    await tester.tap(find.text(_label(_View.year)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final fading = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('exom-segment-fill-2')),
    );
    expect(fading.opacity, 1);
    expect(fading.duration, const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(taps, [_View.year]);
  });

  testWidgets('a tap during the slide acts at once', (tester) async {
    final taps = <_View>[];
    await pumpComponent(tester, _stateful(taps));
    await tester.tap(find.text(_label(_View.year)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(_label(_View.month)));
    expect(taps, [_View.year, _View.month]);
    await tester.pumpAndSettle();
  });

  testWidgets('tapping the selected segment does not call onChanged', (
    tester,
  ) async {
    final taps = <_View>[];
    await pumpComponent(tester, _stateful(taps));
    await tester.tap(find.text(_label(_View.week)));
    expect(taps, isEmpty);
  });

  testWidgets('semantics: exclusive group with the selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _control());
    expect(
      tester.getSemantics(find.text(_label(_View.month))),
      matchesSemantics(
        label: _label(_View.month),
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text(_label(_View.week))),
      matchesSemantics(
        label: _label(_View.week),
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('disabled: no action, disabled semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      ExomSegmentedControl<_View>(
        options: _View.values,
        selected: _View.week,
        labelOf: _label,
      ),
    );
    expect(
      tester.getSemantics(find.text(_label(_View.year))),
      matchesSemantics(
        label: _label(_View.year),
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('tap targets are at least 48 x 48', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Padding(padding: const EdgeInsets.all(20), child: _control()),
      width: 320,
    );
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  test('asserts two or three options', () {
    final one = [_View.week];
    final four = [..._View.values, _View.week];
    expect(
      () => ExomSegmentedControl<_View>(
        options: one,
        selected: _View.week,
        labelOf: _label,
      ),
      throwsAssertionError,
    );
    expect(
      () => ExomSegmentedControl<_View>(
        options: four,
        selected: _View.week,
        labelOf: _label,
      ),
      throwsAssertionError,
    );
  });
}
