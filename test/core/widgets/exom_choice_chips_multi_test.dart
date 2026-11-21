// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): multi-select variant of
// ExomChoiceChips. The single-select API and its tests stay untouched.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

const _options = ['Pecho', 'Espalda', 'Piernas', 'Hombros y brazos'];

Widget _multi({
  Set<String> selected = const {'Espalda'},
  ValueChanged<String>? onToggled,
}) => ExomChoiceChips<String>.multi(
  options: _options,
  selectedValues: selected,
  labelOf: (o) => o,
  onToggled: onToggled ?? (_) {},
);

void main() {
  registerTextComponentMatrix('ExomChoiceChips.multi', _multi);

  testWidgets('each tap toggles one option and several stay selected', (
    tester,
  ) async {
    var selected = <String>{};
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) => _multi(
          selected: selected,
          onToggled: (o) => setState(() {
            selected = {...selected};
            if (!selected.remove(o)) selected.add(o);
          }),
        ),
      ),
    );
    await tester.tap(find.text('Pecho'));
    await tester.pump();
    await tester.tap(find.text('Piernas'));
    await tester.pump();
    expect(selected, {'Pecho', 'Piernas'});
    await tester.tap(find.text('Pecho'));
    await tester.pump();
    expect(selected, {'Piernas'});
  });

  testWidgets('selected chips show a check, unselected ones do not', (
    tester,
  ) async {
    await pumpComponent(tester, _multi(selected: {'Espalda', 'Piernas'}));
    expect(find.byIcon(ExomIcons.check), findsNWidgets(2));
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('selection is filled in the selection colour, check on it '
        '(${brightness.name})', (tester) async {
      await pumpComponent(tester, _multi(), brightness: brightness);
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(find.byIcon(ExomIcons.check));
      expect(icon.color, palette.onSelectionFill);
      final text = tester.widget<Text>(find.text('Espalda'));
      expect(
        DefaultTextStyle.of(tester.element(find.text('Espalda'))).style.color ??
            text.style?.color,
        palette.onSelectionFill,
      );
    });
  }

  testWidgets('semantics: checkable buttons, not a mutually exclusive group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _multi());
    expect(
      tester.getSemantics(find.text('Espalda')),
      matchesSemantics(
        label: 'Espalda',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasSelectedState: false,
      ),
    );
    expect(
      tester.getSemantics(find.text('Pecho')),
      matchesSemantics(
        label: 'Pecho',
        isButton: true,
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tap targets are at least 48 x 48', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Padding(padding: const EdgeInsets.all(20), child: _multi()),
    );
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('null onToggled disables every chip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      ExomChoiceChips<String>.multi(
        options: _options,
        selectedValues: const {},
        labelOf: (o) => o,
        onToggled: null,
      ),
    );
    expect(
      tester.getSemantics(find.text('Pecho')),
      matchesSemantics(
        label: 'Pecho',
        isButton: true,
        hasCheckedState: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('a tap during the crossfade acts at once', (tester) async {
    final taps = <String>[];
    await pumpComponent(tester, _multi(onToggled: taps.add));
    await tester.tap(find.text('Pecho'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Piernas'));
    expect(taps, ['Pecho', 'Piernas']);
  });
}
