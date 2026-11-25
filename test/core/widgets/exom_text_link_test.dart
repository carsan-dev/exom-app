import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'expect_no_lime_ink.dart';

Widget _link({bool danger = false, VoidCallback? onTap}) => Align(
  alignment: AlignmentDirectional.centerStart,
  child: ExomTextLink(label: 'Ver todo', onTap: onTap ?? () {}, danger: danger),
);

void main() {
  registerTextComponentMatrix('ExomTextLink', () => _link());

  testWidgets('touch target measures at least 48 x 48 and passes guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _link());
    final size = tester.getSize(find.byType(InkWell));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('short label still measures 48 x 48', (tester) async {
    await pumpComponent(
      tester,
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ExomTextLink(label: 'Ok', onTap: () {}),
      ),
    );
    final size = tester.getSize(find.byType(InkWell));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('semantics: link and button with the label, tap fires', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(tester, _link(onTap: () => taps++));
    final data = tester
        .getSemantics(find.byType(ExomTextLink))
        .getSemanticsData();
    expect(data.label, 'Ver todo');
    expect(data.flagsCollection.isLink, isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.text('Ver todo'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('null onTap has no tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const Align(
        alignment: AlignmentDirectional.centerStart,
        child: ExomTextLink(label: 'Ver todo', onTap: null),
      ),
    );
    final data = tester
        .getSemantics(find.byType(ExomTextLink))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('colours: text and underline in data; danger in error '
        '(${brightness.name})', (tester) async {
      await pumpComponent(tester, _link(), brightness: brightness);
      var style = tester.widget<Text>(find.text('Ver todo')).style!;
      expect(style.color, palette.textPrimary);
      expect(style.decoration, TextDecoration.underline);
      expect(style.decorationColor, palette.data);
      expect(style.fontWeight, FontWeight.w600);

      await pumpComponent(tester, _link(danger: true), brightness: brightness);
      style = tester.widget<Text>(find.text('Ver todo')).style!;
      expect(style.color, palette.error);
      expect(style.decorationColor, palette.error);
    });
  }

  // L5-F1 (sketch `.x-link.f-ic`): optional leading icon and accessible
  // label; without them the link is exactly as before.
  testWidgets('default: no icon and the visible label is the spoken one', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _link());
    expect(
      find.descendant(
        of: find.byType(ExomTextLink),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(
      tester.getSemantics(find.byType(ExomTextLink)).getSemanticsData().label,
      'Ver todo',
    );
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('icon in the label colour, semantics label '
        'overrides the visible one (${brightness.name})', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpComponent(
        tester,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExomTextLink(
            label: 'Añadir',
            semanticsLabel: 'Añadir Espalda',
            icon: ExomIcons.add,
            onTap: () => taps++,
          ),
        ),
        brightness: brightness,
      );
      final icon = tester.widget<Icon>(find.byIcon(ExomIcons.add));
      expect(icon.color, palette.textPrimary);
      final iconLeft = tester.getTopLeft(find.byIcon(ExomIcons.add)).dx;
      final textLeft = tester.getTopLeft(find.text('Añadir')).dx;
      expect(iconLeft, lessThan(textLeft));
      final data = tester
          .getSemantics(find.byType(ExomTextLink))
          .getSemanticsData();
      expect(data.label, 'Añadir Espalda');
      expect(data.flagsCollection.isLink, isTrue);
      final size = tester.getSize(find.byType(InkWell));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byIcon(ExomIcons.add));
      expect(taps, 1);
      handle.dispose();
    });
  }

  testWidgets('danger has no lime ink in the light theme', (tester) async {
    await pumpComponent(
      tester,
      _link(danger: true),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  // L5-E5 (owner decision 2026-11-25): optional leading icon («Ver técnica»
  // with a play icon when there is a video). Without it the link is as before.
  group('icon (L5-E5)', () {
    testWidgets('default has no icon', (tester) async {
      await pumpComponent(tester, _link());
      expect(
        find.descendant(
          of: find.byType(ExomTextLink),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('icon before the label in the link ink; target still 48 '
          '(${brightness.name})', (tester) async {
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        final handle = tester.ensureSemantics();
        await pumpComponent(
          tester,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomTextLink(
              label: 'Ver técnica',
              icon: ExomIcons.play,
              onTap: () {},
            ),
          ),
          brightness: brightness,
        );
        final icon = tester.widget<Icon>(find.byIcon(ExomIcons.play));
        expect(icon.color, palette.textPrimary);
        expect(
          tester.getTopRight(find.byIcon(ExomIcons.play)).dx,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Ver técnica')).dx),
        );
        final size = tester.getSize(find.byType(InkWell));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        await expectTapTargetGuidelines(tester);
        final data = tester
            .getSemantics(find.byType(ExomTextLink))
            .getSemanticsData();
        expect(data.label, 'Ver técnica');
        handle.dispose();
      });
    }
  });
}
