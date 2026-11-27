// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomNumeralStepper, the
// 64 numeral with unit and ± of 56 on top of ExomStepper (`.numstep`).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

class _Probe {
  final values = <double>[];
  final invalid = <String>[];
}

Widget _stepper({
  double value = 70,
  double min = 40,
  double max = 200,
  double step = 1,
  bool acceptsTypedOutOfRange = true,
  _Probe? probe,
  String? errorText,
  bool enabled = true,
}) => ExomNumeralStepper(
  value: value,
  min: min,
  max: max,
  step: step,
  unit: 'kg',
  label: 'Peso',
  decrementLabel: 'Restar',
  incrementLabel: 'Sumar',
  acceptsTypedOutOfRange: acceptsTypedOutOfRange,
  errorText: errorText,
  onChanged: enabled ? (v) => probe?.values.add(v) : null,
  onInvalidInput: (raw) => probe?.invalid.add(raw),
);

/// Holds the value like a screen would and records every emission.
Widget _stateful(
  _Probe probe, {
  double initial = 70,
  double min = 40,
  double max = 200,
  double step = 1,
  bool acceptsTypedOutOfRange = true,
}) {
  var value = initial;
  return StatefulBuilder(
    builder: (context, setState) => ExomNumeralStepper(
      value: value,
      min: min,
      max: max,
      step: step,
      unit: 'kg',
      label: 'Peso',
      decrementLabel: 'Restar',
      incrementLabel: 'Sumar',
      acceptsTypedOutOfRange: acceptsTypedOutOfRange,
      onChanged: (v) {
        probe.values.add(v);
        setState(() => value = v);
      },
      onInvalidInput: probe.invalid.add,
    ),
  );
}

Finder get _minus => find.bySemanticsLabel('Restar');
Finder get _plus => find.bySemanticsLabel('Sumar');

Future<void> _tapButton(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pump();
}

Future<void> _startEditing(WidgetTester tester) async {
  await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
  await tester.pump();
}

void main() {
  registerTextComponentMatrix('ExomNumeralStepper', () => _stepper());
  registerTextComponentMatrix(
    'ExomNumeralStepper with error',
    () => _stepper(value: 1234.5, errorText: 'Introduce un peso mayor que 0'),
  );

  testWidgets('composes ExomStepper with a 64 data numeral and its unit', (
    tester,
  ) async {
    await pumpComponent(tester, _stepper(value: 68.4));
    expect(find.byType(ExomStepper<double>), findsOneWidget);
    final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
    expect(numeral.size, ExomNumeralSize.hero64);
    expect(numeral.value, '68,4');
    expect(numeral.unit, 'kg');
    expect(numeral.isData, isTrue);
    expect(ExomType.hero64.fontSize, 64);
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('numeral in the data colour (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(tester, _stepper(), brightness: brightness);
      final text = tester.widget<Text>(find.byKey(ExomNumeral.valueKey));
      expect(text.style?.color, palette.data);
    });
  }

  testWidgets('± buttons are 56 x 56', (tester) async {
    await pumpComponent(tester, _stepper(), width: 320);
    for (final finder in [_minus, _plus]) {
      final size = tester.getSize(finder);
      expect(size.width, ExomStepper.buttonSize);
      expect(size.height, ExomStepper.buttonSize);
    }
  });

  testWidgets('± move by step and the value is formatted for the locale', (
    tester,
  ) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe, initial: 68, step: 0.5));
    await _tapButton(tester, ExomIcons.add);
    await _tapButton(tester, ExomIcons.add);
    await _tapButton(tester, ExomIcons.remove);
    expect(probe.values, [68.5, 69, 68.5]);
    expect(tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value, '68,5');
  });

  testWidgets('en locale formats with a point', (tester) async {
    await pumpComponent(
      tester,
      _stepper(value: 68.4),
      locale: const Locale('en'),
    );
    expect(tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value, '68.4');
  });

  group('fractionDigits', () {
    Widget fixed(double value, {int? digits, _Probe? probe}) =>
        ExomNumeralStepper(
          value: value,
          min: 0,
          max: 200,
          step: 0.5,
          unit: 'cm',
          label: 'Brazo',
          decrementLabel: 'Restar',
          incrementLabel: 'Sumar',
          acceptsTypedOutOfRange: true,
          fractionDigits: digits,
          onChanged: (v) => probe?.values.add(v),
        );

    String shown(WidgetTester tester) =>
        tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value;

    testWidgets('null keeps the trimmed format', (tester) async {
      await pumpComponent(tester, fixed(33));
      expect(shown(tester), '33');
    });

    testWidgets('1 shows a fixed decimal in es', (tester) async {
      await pumpComponent(tester, fixed(33, digits: 1));
      expect(shown(tester), '33,0');
    });

    testWidgets('1 shows a fixed decimal in en', (tester) async {
      await pumpComponent(
        tester,
        fixed(33.5, digits: 1),
        locale: const Locale('en'),
      );
      expect(shown(tester), '33.5');
      await pumpComponent(
        tester,
        fixed(33, digits: 1),
        locale: const Locale('en'),
      );
      expect(shown(tester), '33.0');
    });

    testWidgets('typing and emitted values are unchanged', (tester) async {
      final probe = _Probe();
      await pumpComponent(tester, fixed(33, digits: 1, probe: probe));
      await _startEditing(tester);
      await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '34,25');
      await tester.pump();
      expect(probe.values, [34.25]);
    });
  });

  testWidgets('limit: ± stop at min and max and the button is disabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final probe = _Probe();
    await pumpComponent(
      tester,
      _stateful(probe, initial: 41, min: 40, max: 42),
    );
    await _tapButton(tester, ExomIcons.remove);
    expect(probe.values, [40]);
    expect(
      tester.getSemantics(_minus),
      matchesSemantics(
        label: 'Restar',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await _tapButton(tester, ExomIcons.remove);
    expect(probe.values, [40]);
    await _tapButton(tester, ExomIcons.add);
    await _tapButton(tester, ExomIcons.add);
    await _tapButton(tester, ExomIcons.add);
    expect(probe.values, [40, 41, 42]);
    expect(
      tester.getSemantics(_plus),
      matchesSemantics(
        label: 'Sumar',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('a step that would cross a limit lands on the limit', (
    tester,
  ) async {
    final probe = _Probe();
    await pumpComponent(
      tester,
      _stateful(probe, initial: 40.3, min: 40, max: 160, step: 0.5),
    );
    await _tapButton(tester, ExomIcons.remove);
    expect(probe.values, [40]);
  });

  testWidgets('accepts «68,4» typed in es', (tester) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe));
    await _startEditing(tester);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '68,4');
    await tester.pump();
    expect(probe.values.last, 68.4);
    expect(probe.invalid, isEmpty);
  });

  testWidgets('accepts «68.4» typed in en', (tester) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe), locale: const Locale('en'));
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '68.4');
    await tester.pump();
    expect(probe.values.last, 68.4);
  });

  testWidgets('editing starts with the formatted value and ends on submit', (
    tester,
  ) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe, initial: 70.5));
    await _startEditing(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '70,5');
    expect(field.style?.fontSize, 64);
    await tester.enterText(find.byType(TextField), '72');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value, '72');
  });

  testWidgets('typed value outside the ± range is emitted when allowed', (
    tester,
  ) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe, max: 220));
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '250');
    await tester.pump();
    expect(probe.values.last, 250);
    expect(probe.invalid, isEmpty);
  });

  testWidgets('typed value outside the range is reported when not allowed', (
    tester,
  ) async {
    final probe = _Probe();
    await pumpComponent(
      tester,
      _stateful(probe, max: 220, acceptsTypedOutOfRange: false),
    );
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '250');
    await tester.pump();
    expect(probe.values, isEmpty);
    expect(probe.invalid, ['250']);
    // Still editing: the caller shows its error and the user can fix it.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('unparseable or empty text is reported, never emitted', (
    tester,
  ) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe));
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), '6,8,4');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(probe.values, isEmpty);
    expect(probe.invalid, ['6,8,4', '']);
  });

  testWidgets('while editing, ± update the typed text', (tester) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe, initial: 70));
    await _startEditing(tester);
    await _tapButton(tester, ExomIcons.add);
    expect(probe.values, [71]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '71',
    );
  });

  testWidgets('error: message under the row, live region, invalid control', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      _stepper(errorText: 'Introduce un peso mayor que 0'),
    );
    expect(find.text('Introduce un peso mayor que 0'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('Introduce un peso mayor que 0'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    final control = tester.getSemantics(find.bySemanticsLabel('Peso'));
    expect(
      control.getSemanticsData().validationResult,
      SemanticsValidationResult.invalid,
    );
    handle.dispose();
  });

  testWidgets('semantics: value with unit, increase/decrease and edit', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _stepper(value: 68.5, step: 0.5));
    final data = tester
        .getSemantics(find.bySemanticsLabel('Peso'))
        .getSemanticsData();
    expect(data.label, 'Peso');
    expect(data.value, '68,5 kg');
    expect(data.increasedValue, '69 kg');
    expect(data.decreasedValue, '68 kg');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('disabled: no buttons, no editing', (tester) async {
    final probe = _Probe();
    await pumpComponent(tester, _stepper(probe: probe, enabled: false));
    await _tapButton(tester, ExomIcons.add);
    await _startEditing(tester);
    expect(find.byType(TextField), findsNothing);
    expect(probe.values, isEmpty);
  });

  testWidgets('quick taps act at once, each one counted', (tester) async {
    final probe = _Probe();
    await pumpComponent(tester, _stateful(probe, initial: 70));
    // One frame between taps (a real device always renders one): no
    // animation or delay holds a tap back.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(ExomIcons.add));
      await tester.pump();
    }
    expect(probe.values, [71, 72, 73]);
  });

  testWidgets('tap targets are at least 48 x 48', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Padding(padding: const EdgeInsets.all(20), child: _stepper()),
      width: 320,
    );
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('wide value at 320 dp and 1.6 x scales down without overflow', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        child: _stepper(value: 1102.31, max: 2000),
      ),
      width: 320,
      textScale: 1.6,
    );
    expectNoOverflow(tester);
    final numeral = tester.getRect(find.byType(ExomNumeral));
    final minus = tester.getRect(_minus);
    final plus = tester.getRect(_plus);
    expect(numeral.left, greaterThanOrEqualTo(minus.right));
    expect(numeral.right, lessThanOrEqualTo(plus.left));
  });
}
