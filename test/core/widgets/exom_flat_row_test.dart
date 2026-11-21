import 'dart:ui' show Tristate;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

ExomThemePalette _palette(Brightness b) =>
    themeFor(b).extension<ExomThemePalette>()!;

Widget _row({VoidCallback? onTap, Widget? trailing}) => ExomFlatRowGroup(
  children: [
    ExomFlatRow(
      leading: const Icon(ExomIcons.diet),
      title: 'Definición · 2.150 kcal',
      subtitles: const ['1 de 4 comidas hechas', 'Siguiente: merienda'],
      trailing: trailing,
      onTap: onTap,
    ),
  ],
);

/// Fill of the row surface (null when transparent).
Color? _rowFill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ExomRowSurface),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  group('ExomFlatRow', () {
    registerTextComponentMatrix('ExomFlatRow', () => _row(onTap: () {}));

    testWidgets('tap targets meet the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, _row(onTap: () {}), width: 320);
      await expectTapTargetGuidelines(tester);
      handle.dispose();
    });

    testWidgets(
      'at least 56 tall, full width, top rule and group bottom rule',
      (tester) async {
        final palette = _palette(Brightness.dark);
        await pumpComponent(
          tester,
          ExomFlatRowGroup(
            children: [ExomFlatRow(title: 'Racha', onTap: () {})],
          ),
          width: 320,
        );
        final size = tester.getSize(find.byType(ExomFlatRow));
        expect(size.height, greaterThanOrEqualTo(56));
        expect(size.width, 320);
        final surface = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(ExomRowSurface),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final top = (surface.decoration as BoxDecoration).border! as Border;
        expect(top.top, BorderSide(color: palette.borderSoft, width: 1));
        final group = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(ExomFlatRowGroup),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final bottom = (group.decoration as BoxDecoration).border! as Border;
        expect(bottom.bottom, BorderSide(color: palette.borderSoft, width: 1));
      },
    );

    for (final brightness in Brightness.values) {
      // Sketch base.css `.r:active`: the press fill eases in over 90 ms. It
      // is a decision of T0.3a (the sketch rules the duration) that motion M6
      // («filas a elevado al instante») still holds with reduced motion.
      testWidgets('pressed: elevated fill in 90 ms, cleared in 90 ms on '
          'release (${brightness.name})', (tester) async {
        final palette = _palette(brightness);
        var taps = 0;
        await pumpComponent(
          tester,
          _row(onTap: () => taps++),
          brightness: brightness,
        );
        expect(_rowFill(tester), isNull);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ExomFlatRow)),
        );
        await tester.pump();
        expect(_rowFill(tester), isNot(palette.surfaceElevated));
        await tester.pump(const Duration(milliseconds: 45));
        final halfway = _rowFill(tester);
        expect(halfway, isNotNull);
        expect(halfway, isNot(palette.surfaceElevated));
        await tester.pump(const Duration(milliseconds: 45));
        expect(_rowFill(tester), palette.surfaceElevated);
        await gesture.up();
        await tester.pump();
        expect(_rowFill(tester), palette.surfaceElevated);
        await tester.pump(const Duration(milliseconds: 90));
        expect(_rowFill(tester), isNull);
        expect(taps, 1);
      });

      testWidgets('pressed with reduced motion: elevated fill at once, '
          'cleared at once (${brightness.name})', (tester) async {
        final palette = _palette(brightness);
        await pumpComponent(
          tester,
          _row(onTap: () {}),
          brightness: brightness,
          disableAnimations: true,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ExomFlatRow)),
        );
        await tester.pump();
        expect(_rowFill(tester), palette.surfaceElevated);
        await gesture.up();
        await tester.pump();
        expect(_rowFill(tester), isNull);
      });
    }

    testWidgets('disabled (no onTap): no chevron, no press fill, no button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, _row());
      expect(find.byIcon(ExomIcons.next), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ExomFlatRow)),
      );
      await tester.pump(kPressTimeout);
      expect(_rowFill(tester), isNull);
      await gesture.up();
      final node = tester.getSemantics(find.byType(ExomFlatRow));
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('enabled: one merged button node with chevron', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, _row(onTap: () {}));
      expect(find.byIcon(ExomIcons.next), findsOneWidget);
      final node = tester.getSemantics(find.byType(ExomFlatRow));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, contains('Definición · 2.150 kcal'));
      expect(node.label, contains('1 de 4 comidas hechas'));
      handle.dispose();
    });

    testWidgets('trailing replaces the chevron', (tester) async {
      await pumpComponent(
        tester,
        _row(onTap: () {}, trailing: const Text('Hecha')),
      );
      expect(find.byIcon(ExomIcons.next), findsNothing);
      expect(find.text('Hecha'), findsOneWidget);
    });

    testWidgets('empty group paints nothing', (tester) async {
      await pumpComponent(tester, const ExomFlatRowGroup(children: []));
      expect(
        find.descendant(
          of: find.byType(ExomFlatRowGroup),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  group('ExomValueRow', () {
    Widget value() => const ExomValueRow(
      label: 'Media diaria de pasos',
      value: '8.500 pasos/día',
    );

    registerTextComponentMatrix('ExomValueRow', value);

    for (final brightness in Brightness.values) {
      testWidgets('label in text, value in secondary aligned to the end '
          '(${brightness.name})', (tester) async {
        final palette = _palette(brightness);
        await pumpComponent(tester, value(), brightness: brightness);
        final label = tester.widget<Text>(find.text('Media diaria de pasos'));
        final valueText = tester.widget<Text>(find.text('8.500 pasos/día'));
        expect(label.style?.color, palette.textPrimary);
        expect(valueText.style?.color, palette.textSecondary);
        expect(valueText.textAlign, TextAlign.end);
      });
    }

    testWidgets('value never takes more than half the row content', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const ExomValueRow(
          label: 'Notas',
          value: 'Un valor muy largo que tendría que partirse en varias líneas',
        ),
        width: 320,
      );
      final valueWidth = tester
          .getSize(
            find.text(
              'Un valor muy largo que tendría que partirse en varias líneas',
            ),
          )
          .width;
      // 320 minus 20 + 20 padding = 280 of content.
      expect(valueWidth, lessThanOrEqualTo(140));
      expectNoOverflow(tester);
    });

    testWidgets('reads label and value as one node, not a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, value());
      final node = tester.getSemantics(find.byType(ExomValueRow));
      expect(node.label, contains('Media diaria de pasos'));
      expect(node.label, contains('8.500 pasos/día'));
      expect(node.flagsCollection.isButton, isFalse);
      handle.dispose();
    });
  });

  group('ExomSwitchRow', () {
    Widget switchRow({
      bool value = true,
      ValueChanged<bool>? onChanged,
      String? errorText,
      bool busy = false,
    }) => ExomSwitchRow(
      label: 'Sonido al acabar el descanso',
      value: value,
      onChanged: busy ? null : (onChanged ?? (_) {}),
      errorText: errorText,
    );

    registerTextComponentMatrix('ExomSwitchRow on', switchRow);
    registerTextComponentMatrix(
      'ExomSwitchRow off',
      () => switchRow(value: false),
    );
    registerTextComponentMatrix(
      'ExomSwitchRow error',
      () =>
          switchRow(errorText: 'No se ha podido guardar. Inténtalo otra vez.'),
    );
    registerTextComponentMatrix(
      'ExomSwitchRow busy',
      () => switchRow(busy: true),
    );

    BoxDecoration track(WidgetTester tester) =>
        tester
                .widget<Container>(find.byKey(const Key('exom-switch-track')))
                .decoration!
            as BoxDecoration;
    BoxDecoration knob(WidgetTester tester) =>
        tester
                .widget<Container>(find.byKey(const Key('exom-switch-knob')))
                .decoration!
            as BoxDecoration;

    for (final brightness in Brightness.values) {
      testWidgets('square switch: 52x32, radius 4, on = text fill, off = '
          'secondary outline (${brightness.name})', (tester) async {
        final palette = _palette(brightness);
        await pumpComponent(tester, switchRow(), brightness: brightness);
        expect(
          tester.getSize(find.byKey(const Key('exom-switch-track'))),
          const Size(52, 32),
        );
        expect(track(tester).color, palette.textPrimary);
        expect(track(tester).borderRadius, BorderRadius.circular(4));
        expect(
          (track(tester).border! as Border).top,
          BorderSide(color: palette.textPrimary, width: 1.5),
        );
        expect(knob(tester).color, palette.background);
        expect(knob(tester).borderRadius, BorderRadius.circular(2));
        expect(
          tester.getSize(find.byKey(const Key('exom-switch-knob'))),
          const Size(21, 21),
        );

        await pumpComponent(
          tester,
          switchRow(value: false),
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expect(track(tester).color, isNull);
        expect(
          (track(tester).border! as Border).top,
          BorderSide(color: palette.textSecondary, width: 1.5),
        );
        expect(knob(tester).color, palette.textSecondary);
      });
    }

    testWidgets('knob sits 4 from the start when off and 4 from the end when '
        'on', (tester) async {
      await pumpComponent(tester, switchRow(value: false));
      await tester.pumpAndSettle();
      var t = tester.getRect(find.byKey(const Key('exom-switch-track')));
      var k = tester.getRect(find.byKey(const Key('exom-switch-knob')));
      expect(k.left - t.left, closeTo(1.5 + 4, 0.01));
      await pumpComponent(tester, switchRow());
      await tester.pumpAndSettle();
      t = tester.getRect(find.byKey(const Key('exom-switch-track')));
      k = tester.getRect(find.byKey(const Key('exom-switch-knob')));
      expect(t.right - k.right, closeTo(1.5 + 4, 0.01));
    });

    testWidgets('tapping anywhere on the row toggles the value', (
      tester,
    ) async {
      final values = <bool>[];
      await pumpComponent(tester, switchRow(onChanged: values.add));
      await tester.tap(find.text('Sonido al acabar el descanso'));
      await tester.pump();
      expect(values, [false]);
      await pumpComponent(
        tester,
        switchRow(value: false, onChanged: values.add),
      );
      await tester.tap(find.byKey(const Key('exom-switch-track')));
      await tester.pump();
      expect(values, [false, true]);
    });

    testWidgets('semantics: toggled switch, enabled, labelled, tappable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, switchRow());
      final node = tester.getSemantics(find.byType(ExomRowSurface));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isToggled, Tristate.isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains('Sonido al acabar el descanso'));
      await pumpComponent(tester, switchRow(value: false));
      expect(
        tester
            .getSemantics(find.byType(ExomRowSurface))
            .getSemanticsData()
            .flagsCollection
            .isToggled,
        Tristate.isFalse,
      );
      handle.dispose();
    });

    testWidgets('busy: indicator, no toggle, announced as disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const ExomSwitchRow(label: 'Notificaciones push', value: true),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Busy means no callback (onChanged null): the tap is inert, so the row
      // neither paints a press fill nor reacts in any way (the enabled row
      // reporting its toggled value is covered above).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ExomSwitchRow)),
      );
      await tester.pump(kPressTimeout);
      expect(_rowFill(tester), isNull);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_rowFill(tester), isNull);
      final data = tester
          .getSemantics(find.byType(ExomRowSurface))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.flagsCollection.isToggled, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.label, contains('En curso'));
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('busy indicator is never lime (${brightness.name})', (
        tester,
      ) async {
        final palette = _palette(brightness);
        await pumpComponent(
          tester,
          switchRow(busy: true),
          brightness: brightness,
        );
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.color, palette.textSecondary);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('error: text in the error colour below the row '
          '(${brightness.name})', (tester) async {
        final palette = _palette(brightness);
        await pumpComponent(
          tester,
          switchRow(errorText: 'No se ha podido guardar.'),
          brightness: brightness,
        );
        final text = tester.widget<Text>(find.text('No se ha podido guardar.'));
        expect(text.style?.color, palette.error);
        expect(
          tester.getRect(find.text('No se ha podido guardar.')).top,
          greaterThanOrEqualTo(
            tester.getRect(find.byKey(const Key('exom-switch-track'))).bottom,
          ),
        );
      });
    }

    testWidgets('error is one live region, announced once', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        switchRow(errorText: 'No se ha podido guardar.'),
      );
      final live = find.semantics.byFlag(SemanticsFlag.isLiveRegion);
      expect(live, findsOne);
      expect(live.evaluate().single.label, 'No se ha podido guardar.');
      // The row itself is not a live region.
      final row = tester.getSemantics(find.byType(ExomRowSurface));
      expect(row.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    testWidgets('tap targets meet the guidelines in every state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final row in [
        switchRow(),
        switchRow(value: false),
        switchRow(busy: true),
        switchRow(errorText: 'No se ha podido guardar.'),
      ]) {
        await pumpComponent(tester, row, width: 320);
        await expectTapTargetGuidelines(tester);
        final size = tester.getSize(find.byType(ExomRowSurface));
        expect(size.height, greaterThanOrEqualTo(56));
      }
      handle.dispose();
    });
  });
}
