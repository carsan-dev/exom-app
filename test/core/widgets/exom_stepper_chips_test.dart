import 'dart:ui' show Tristate;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_panel.dart';
import 'package:exom_app/core/widgets/exom_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

String _kg(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} kg';

class _StepperHost extends StatefulWidget {
  const _StepperHost({this.typed = false});
  final bool typed;

  @override
  State<_StepperHost> createState() => _StepperHostState();
}

class _StepperHostState extends State<_StepperHost> {
  double value = 62.5;
  final controller = TextEditingController(text: '62,5');
  final changes = <String>[];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ExomStepper<double>(
        key: const Key('stepper'),
        value: value,
        increasedValue: value + 2.5,
        decreasedValue: value <= 0 ? null : value - 2.5,
        formatValue: _kg,
        label: 'Peso',
        decrementLabel: 'Restar 2,5 kg',
        incrementLabel: 'Sumar 2,5 kg',
        onDecrement: value <= 0 ? null : () => setState(() => value -= 2.5),
        onIncrement: () => setState(() => value += 2.5),
        textController: widget.typed ? controller : null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onTextChanged: widget.typed ? changes.add : null,
      ),
    );
  }
}

void main() {
  group('ExomStepper', () {
    for (final brightness in Brightness.values) {
      testWidgets('56 px buttons, callbacks, targets (${brightness.name})', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const _StepperHost(),
          brightness: brightness,
        );
        final minus = find.bySemanticsLabel('Restar 2,5 kg');
        final plus = find.bySemanticsLabel('Sumar 2,5 kg');
        expect(tester.getSize(minus), const Size(56, 56));
        expect(tester.getSize(plus), const Size(56, 56));
        expect(find.text('62,5 kg'), findsOneWidget);
        await tester.tap(plus);
        await tester.pump();
        expect(find.text('65,0 kg'), findsOneWidget);
        await tester.tap(minus);
        await tester.tap(minus);
        await tester.pump();
        expect(find.text('60,0 kg'), findsOneWidget);
        await expectTapTargetGuidelines(tester);
      });
    }

    testWidgets('exposes increase/decrease semantics actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, const _StepperHost());
      final node = tester.getSemantics(find.bySemanticsLabel('Peso'));
      expect(node.value, '62,5 kg');
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(find.text('65,0 kg'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('typed entry uses the given keyboard and only forwards text', (
      tester,
    ) async {
      await pumpComponent(tester, const _StepperHost(typed: true));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      await tester.enterText(find.byType(TextField), '6x');
      await tester.pump();
      final host = tester.state<_StepperHostState>(find.byType(_StepperHost));
      expect(host.changes.last, '6x', reason: 'no parsing in the widget');
      expect(host.value, 62.5);
    });

    for (final brightness in Brightness.values) {
      testWidgets('320 dp at 1.6x without overflow (${brightness.name})', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const _StepperHost(),
          brightness: brightness,
          width: 320,
          textScale: 1.6,
        );
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
      });
    }

    testWidgets('± buttons do not scale on press (principle 1 omission)', (
      tester,
    ) async {
      await pumpComponent(tester, const _StepperHost());
      expect(
        find.descendant(
          of: find.byKey(const Key('stepper')),
          matching: find.byType(AnimatedScale),
        ),
        findsNothing,
      );
    });
  });

  group('ExomChoiceChips', () {
    Widget chips(int? selected, ValueChanged<int> onSelected) => Padding(
      padding: const EdgeInsets.all(20),
      child: ExomChoiceChips<int>(
        key: const Key('rir'),
        options: const [0, 1, 2, 3, 4, 5],
        selected: selected,
        labelOf: (v) => v == 5 ? '5+' : '$v',
        semanticLabelOf: (v) => 'RIR ${v == 5 ? '5 o más' : v}',
        onSelected: onSelected,
      ),
    );

    for (final brightness in Brightness.values) {
      testWidgets(
        'single select, >=48 chips, selected style (${brightness.name})',
        (tester) async {
          int? picked;
          await pumpComponent(
            tester,
            chips(2, (v) => picked = v),
            brightness: brightness,
          );
          final palette = themeFor(brightness).extension<ExomThemePalette>()!;
          for (final label in ['0', '1', '2', '3', '4', '5+']) {
            final size = tester.getSize(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(AnimatedContainer),
              ),
            );
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          final selected = tester.widget<AnimatedContainer>(
            find.ancestor(
              of: find.text('2'),
              matching: find.byType(AnimatedContainer),
            ),
          );
          expect(
            (selected.decoration! as BoxDecoration).color,
            palette.textPrimary,
          );
          expect(selected.duration, const Duration(milliseconds: 160));
          final node = tester.getSemantics(find.bySemanticsLabel('RIR 2'));
          expect(node.flagsCollection.isSelected, Tristate.isTrue);
          await tester.tap(find.text('4'));
          expect(picked, 4);
          await expectTapTargetGuidelines(tester);
        },
      );
    }

    testWidgets('reduced motion crossfade is 120 ms', (tester) async {
      await pumpComponent(tester, chips(1, (_) {}), disableAnimations: true);
      final c = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('1'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(c.duration, const Duration(milliseconds: 120));
    });

    Finder chip(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    );
    const labels = ['0', '1', '2', '3', '4', '5+'];

    testWidgets('390 dp: six content-width chips share one row', (
      tester,
    ) async {
      await pumpComponent(tester, chips(2, (_) {}));
      final top = tester.getTopLeft(chip('0')).dy;
      for (final label in labels) {
        expect(tester.getTopLeft(chip(label)).dy, top, reason: label);
        final size = tester.getSize(chip(label));
        expect(size.width, lessThan(80), reason: 'content width, not full');
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('wraps at 320 dp and 1.6x without overflow', (tester) async {
      await pumpComponent(tester, chips(0, (_) {}), width: 320, textScale: 1.6);
      expectNoOverflow(tester);
      final rows = {
        for (final label in labels) tester.getTopLeft(chip(label)).dy,
      };
      expect(rows.length, lessThan(labels.length), reason: 'chips share rows');
      for (final label in labels) {
        expect(tester.getSize(chip(label)).width, lessThan(120));
      }
      await expectTapTargetGuidelines(tester);
    });
  });

  group('ExomPanel', () {
    for (final brightness in Brightness.values) {
      testWidgets('flat panel with hairline rules (${brightness.name})', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const ExomPanel(key: Key('panel'), child: Text('Contenido')),
          brightness: brightness,
          width: 320,
          textScale: 1.6,
        );
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const Key('panel')),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, palette.surface);
        expect(decoration.borderRadius, isNull);
        final border = decoration.border! as Border;
        expect(border.top.color, palette.borderSoft);
        expect(border.top.width, 1);
        expect(border.bottom.width, 1);
        expectNoOverflow(tester);
      });
    }
  });
}
