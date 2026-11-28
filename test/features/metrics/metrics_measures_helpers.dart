// Finders and actions of section «06 Medidas corporales» of the metrics form
// (L6-D2): the list rows, the measure sheet and its steppers. Not a test
// file: it has no `main` and is only imported.
import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder measureRow(BodyZone zone) =>
    find.byKey(Key('metrics-measure-row-${zone.name}'));

Finder measureValue(BodyZone zone) =>
    find.byKey(Key('metrics-measure-value-${zone.name}'));

Finder measureEdited(BodyZone zone) =>
    find.byKey(Key('metrics-measure-edited-${zone.name}'));

Finder measureSheet() => find.byKey(const Key('metrics-measure-sheet'));

Finder measureStepper(String fieldKey) =>
    find.byKey(Key('metrics-measure-stepper-$fieldKey'));

Finder measureDone() => find.byKey(const Key('metrics-measure-done'));

Finder measureLast() => find.byKey(const Key('metrics-measure-last'));

/// Plain text of a Text or Text.rich with no-break spaces read as spaces.
String plainText(WidgetTester tester, Finder finder) {
  final widget = tester.widget<Text>(finder);
  final text = widget.data ?? widget.textSpan!.toPlainText();
  return text.replaceAll(' ', ' ');
}

/// Value shown at the end of the row of [zone].
String measureValueText(WidgetTester tester, BodyZone zone) =>
    plainText(tester, measureValue(zone));

/// Scrolls the row of [zone] clear of the pinned save bar and taps it.
Future<void> openMeasureSheet(WidgetTester tester, BodyZone zone) async {
  await tester.scrollUntilVisible(
    measureRow(zone),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
  await tester.pump();
  await tester.tap(measureRow(zone));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Taps the numeral of the stepper of [fieldKey] and types [text] into it.
Future<void> typeMeasure(
  WidgetTester tester,
  String fieldKey,
  String text,
) async {
  final numeral = find.descendant(
    of: measureStepper(fieldKey),
    matching: find.byKey(ExomNumeralStepper.valueKey),
  );
  await tester.ensureVisible(numeral);
  await tester.tap(numeral);
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: measureStepper(fieldKey),
      matching: find.byKey(ExomNumeralStepper.fieldKey),
    ),
    text,
  );
  await tester.pump();
}

/// Taps «+» (or «−» with [up] false) of the stepper of [fieldKey].
Future<void> stepMeasure(
  WidgetTester tester,
  String fieldKey, {
  bool up = true,
}) async {
  final button = find.descendant(
    of: measureStepper(fieldKey),
    matching: find.byIcon(up ? ExomIcons.add : ExomIcons.remove),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

/// «Hecho»: applies the sheet to the draft and waits for it to close.
Future<void> tapMeasureDone(WidgetTester tester) async {
  await tester.ensureVisible(measureDone());
  await tester.tap(measureDone());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // The result arrives once the sheet is disposed; the draft repaints next.
  await tester.pump();
}
