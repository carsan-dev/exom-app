import 'dart:ui' show Tristate;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_accordion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

const _title = '¿Qué pasa si entreno sin conexión?';
const _body =
    'Cada serie se guarda en este móvil y se envía sola cuando vuelve la '
    'conexión.';

Widget _accordion({bool open = false, int? number}) => ExomAccordion(
  title: _title,
  number: number,
  initiallyOpen: open,
  // Callers style the body; the theme's bodyLarge is the text colour.
  body: Builder(
    builder: (context) =>
        Text(_body, style: Theme.of(context).textTheme.bodyLarge),
  ),
);

double _height(WidgetTester tester) => tester
    .widget<SizeTransition>(
      find.descendant(
        of: find.byType(ExomAccordion),
        matching: find.byType(SizeTransition),
      ),
    )
    .sizeFactor
    .value;

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.byKey(const Key('exom-accordion-fade')))
    .opacity
    .value;

double _turns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.descendant(
        of: find.byType(ExomAccordion),
        matching: find.byType(RotationTransition),
      ),
    )
    .turns
    .value;

Tristate _expanded(WidgetTester tester) => tester
    .getSemantics(find.byKey(const Key('exom-accordion-header')))
    .getSemanticsData()
    .flagsCollection
    .isExpanded;

void main() {
  registerTextComponentMatrix(
    'ExomAccordion open',
    () => _accordion(open: true),
  );
  registerTextComponentMatrix(
    'ExomAccordion closed numbered',
    () => _accordion(number: 3),
  );

  testWidgets('tap targets meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _accordion(number: 1), width: 320);
    await expectTapTargetGuidelines(tester);
    expect(
      tester.getSize(find.byKey(const Key('exom-accordion-header'))).height,
      greaterThanOrEqualTo(56),
    );
    handle.dispose();
  });

  testWidgets('closed: body hidden, collapsed button; opens on tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _accordion());
    expect(find.text(_body), findsNothing);
    final header = tester.getSemantics(
      find.byKey(const Key('exom-accordion-header')),
    );
    expect(header.flagsCollection.isButton, isTrue);
    expect(_expanded(tester), Tristate.isFalse);
    expect(header.label, contains(_title));

    await tester.tap(find.text(_title));
    await tester.pump();
    expect(_expanded(tester), Tristate.isTrue);
    await tester.pumpAndSettle();
    expect(find.text(_body), findsOneWidget);
    expect(_height(tester), 1);
    expect(_turns(tester), 0.5);
    handle.dispose();
  });

  testWidgets('initiallyOpen shows the body and an expanded state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _accordion(open: true));
    expect(find.text(_body), findsOneWidget);
    expect(_expanded(tester), Tristate.isTrue);
    expect(_height(tester), 1);
    expect(_opacity(tester), 1);

    await tester.tap(find.text(_title));
    await tester.pumpAndSettle();
    expect(find.text(_body), findsNothing);
    expect(_expanded(tester), Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('M7: height 200 ms, chevron 180° with it, content 120 ms', (
    tester,
  ) async {
    await pumpComponent(tester, _accordion());
    await tester.tap(find.text(_title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_height(tester), allOf(greaterThan(0), lessThan(1)));
    expect(_turns(tester), allOf(greaterThan(0), lessThan(0.5)));
    expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 20));
    expect(_opacity(tester), 1);
    expect(_height(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_height(tester), 1);
    expect(_turns(tester), 0.5);
  });

  testWidgets('a tap during the animation acts at once (reverses from where '
      'it is)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _accordion());
    await tester.tap(find.text(_title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _height(tester);
    expect(mid, allOf(greaterThan(0), lessThan(1)));
    await tester.tap(find.text(_title));
    await tester.pump();
    expect(_expanded(tester), Tristate.isFalse);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_height(tester), lessThan(mid));
    await tester.pumpAndSettle();
    expect(find.text(_body), findsNothing);
    handle.dispose();
  });

  testWidgets('reduced motion: no height animation, 120 ms fade', (
    tester,
  ) async {
    await pumpComponent(tester, _accordion(), disableAnimations: true);
    await tester.tap(find.text(_title));
    await tester.pump();
    expect(_height(tester), 1);
    expect(_turns(tester), 0.5);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester), 1);

    // Closing fades out over 120 ms, then the space goes at once.
    await tester.tap(find.text(_title));
    await tester.pump();
    expect(_turns(tester), 0);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_height(tester), 1);
    expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 61));
    await tester.pump();
    expect(find.text(_body), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('title 600 in text, chevron and rule in the theme '
        '(${brightness.name})', (tester) async {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        _accordion(number: 2),
        brightness: brightness,
      );
      final title = tester.widget<Text>(find.text(_title));
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.color, palette.textPrimary);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.expand_more)).color,
        palette.textSecondary,
      );
      expect(find.text('02'), findsOneWidget);
    });
  }
}
