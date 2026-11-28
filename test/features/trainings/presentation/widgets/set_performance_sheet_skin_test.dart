// L5-E4 · Hoja de serie (piel), docs/plans/rediseno-app-l5-contrato-v2.md §4.
//
// Skin of the set sheet (sketch e-migradas.html, «Hoja de registro de serie»
// and «Hoja · error de entrada»): values as Barlow numerals in the data
// colour (44 since L6 A-O1, the compact footer rows), the title at the
// section size (`.t1b`, 28), RIR selection in bone (the text colour, never
// lime), the field error in line with its icon and a
// straight sheet. The behaviour is unchanged and pinned here too: the same two
// taps (Registrar → Guardar) with the prefill (D4), the field error (D3), the
// RIR chips (D13 of L3) and the circuit's use of the same sheet, in es/en and
// metric/imperial. Layout: 320 dp at 1.3x/1.6x and 360 dp at 1.6x, es/en, and
// 2.0x (Android nonlinear scaler) with every control reachable by scrolling.
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_performance_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';

typedef _Open = Future<SetPerformanceResult?> Function(BuildContext context);

class _Host extends StatelessWidget {
  const _Host({required this.open, required this.results});
  final _Open open;
  final List<SetPerformanceResult?> results;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () async => results.add(await open(context)),
        child: const Text('open'),
      ),
    );
  }
}

final _open = find.byKey(const Key('open'));
final _count = find.byKey(const Key('set-sheet-count-field'));
final _weight = find.byKey(const Key('set-sheet-weight-field'));
final _save = find.byKey(const Key('set-sheet-save'));

const _previous = SetPerformance(setNumber: 2, reps: 8, weightKg: 60, rir: 2);

/// The active exercise's sheet, as `active_exercise_page.dart` opens it.
Future<List<SetPerformanceResult?>> _pumpExercise(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Locale locale = const Locale('es'),
  UnitSystem unitSystem = UnitSystem.metric,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  double? previousWeight = 62.5,
  bool open = true,
}) async {
  final results = <SetPerformanceResult?>[];
  await pumpComponent(
    tester,
    _Host(
      results: results,
      open: (context) => showSetPerformanceSheet(
        context,
        AppLocalizations.of(context),
        setNumber: 2,
        prescribedReps: '8 reps · RIR 2',
        repsRequired: false,
        timeUnit: null,
        previousWeight: previousWeight,
        previousPerformance: _previous,
        previousSession: const [_previous],
        targetCount: 8,
        targetRir: 2,
        unitSystem: unitSystem,
      ),
    ),
    brightness: brightness,
    locale: locale,
    width: width,
    height: height,
    textScale: textScale,
    textScaler: textScaler,
  );
  if (open) {
    await tester.tap(_open);
    await tester.pumpAndSettle();
  }
  return results;
}

/// The circuit's sheet, as `active_circuit_page.dart` opens it (same widget,
/// its own title and mandatory tracking).
Future<List<SetPerformanceResult?>> _pumpCircuit(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Locale locale = const Locale('es'),
}) async {
  final results = <SetPerformanceResult?>[];
  await pumpComponent(
    tester,
    _Host(
      results: results,
      open: (context) {
        final l10n = AppLocalizations.of(context);
        return showExomSheet<SetPerformanceResult>(
          context: context,
          builder: (_) => SetPerformanceSheet(
            title: l10n.circuitSheetTitle('Flexiones', 2),
            objective: '12 reps',
            timeUnit: null,
            countRequired: true,
            unitSystem: UnitSystem.metric,
            decimalSeparator: locale.languageCode == 'es' ? ',' : '.',
            initialCount: 12,
            initialRir: 2,
            previous: const SetPerformance(setNumber: 2, reps: 10),
          ),
        );
      },
    ),
    brightness: brightness,
    locale: locale,
  );
  await tester.tap(_open);
  await tester.pumpAndSettle();
  return results;
}

ExomThemePalette _palette(WidgetTester tester) =>
    tester.element(_save).exomPalette;

TextStyle _fieldStyle(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .style;

void _expectDataNumeral(WidgetTester tester, Finder field) {
  final style = _fieldStyle(tester, field);
  expect(style.fontFamily, AppTheme.displayFontFamily);
  expect(style.fontSize, 44);
  expect(style.fontWeight, FontWeight.w800);
  expect(style.color, _palette(tester).data);
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

void main() {
  group('skin', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'values are Barlow 44 in the data colour (${brightness.name})',
        (tester) async {
          await _pumpExercise(tester, brightness: brightness);
          _expectDataNumeral(tester, _count);
          _expectDataNumeral(tester, _weight);
          expectNoLimeInk(tester);
        },
      );

      testWidgets(
        'title at the section size, upper case (${brightness.name})',
        (tester) async {
          await _pumpExercise(tester, brightness: brightness);
          final title = tester.widget<Text>(find.text('SERIE 2'));
          expect(title.style?.fontFamily, AppTheme.displayFontFamily);
          expect(title.style?.fontSize, 28);
          expect(title.style?.color, _palette(tester).textPrimary);
        },
      );

      testWidgets('the chosen RIR is filled in bone, never lime '
          '(${brightness.name})', (tester) async {
        await _pumpExercise(tester, brightness: brightness);
        final palette = _palette(tester);
        final selected = tester
            .widgetList<Container>(
              find.ancestor(
                of: find.text('2'),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.color != null)
            .map((d) => d.color);
        expect(selected, contains(palette.textPrimary));
        expect(selected, isNot(contains(palette.limeFill)));
      });

      testWidgets('the field error is in line, with its icon, in the error '
          'colour and keeps the text (${brightness.name})', (tester) async {
        final results = await _pumpExercise(tester, brightness: brightness);
        final l10n = AppLocalizations.of(tester.element(_save));
        await tester.enterText(_weight, '62,,5');
        await _tapSave(tester);
        // The app's own text (the sketch caption: «el texto del error es el de la
        // app»), not the sketch's sample sentence.
        final message = l10n.setInputNotANumber('62,,5', '62,5');
        final text = tester.widget<Text>(find.text(message));
        final palette = _palette(tester);
        expect(text.style?.color, palette.error);
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.ancestor(
              of: find.text(message),
              matching: find.byType(Row),
            ),
            matching: find.byIcon(ExomIcons.error),
          ),
        );
        expect(icon.color, palette.error);
        expect(tester.widget<TextField>(_weight).controller!.text, '62,,5');
        expect(results, isEmpty, reason: 'nothing saved');
        // The typed numeral keeps the skin while invalid.
        _expectDataNumeral(tester, _weight);
        expectNoLimeInk(tester);
      });
    }
  });

  group('two taps, prefill and units (behaviour unchanged)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final unitSystem in UnitSystem.values) {
        testWidgets('Registrar → Guardar saves the prefill exactly '
            '(${locale.languageCode}, ${unitSystem.name})', (tester) async {
          final results = await _pumpExercise(
            tester,
            locale: locale,
            unitSystem: unitSystem,
            open: false,
          );
          var taps = 0;
          await tester.tap(_open);
          taps++;
          await tester.pumpAndSettle();
          _expectDataNumeral(tester, _weight);
          await tester.tap(_save);
          taps++;
          await tester.pumpAndSettle();
          expect(taps, 2);
          expect(results, hasLength(1));
          final result = results.single!;
          expect(result.reps, 8);
          expect(result.weight, 62.5, reason: 'untouched kg, never converted');
          expect(result.rir, 2);
          expect(result.seconds, isNull);
          expect(result.skipped, isFalse);
        });
      }
    }

    testWidgets('«Igual que la anterior» copies the previous set (D4)', (
      tester,
    ) async {
      final results = await _pumpExercise(tester, previousWeight: null);
      await tester.tap(find.byKey(const Key('set-sheet-same-as-previous')));
      await tester.pump();
      _expectDataNumeral(tester, _weight);
      await _tapSave(tester);
      final result = results.single!;
      expect((result.reps, result.weight, result.rir), (8, 60.0, 2));
    });
  });

  group('circuit sheet (behaviour unchanged)', () {
    for (final brightness in Brightness.values) {
      testWidgets('same widget, same result (${brightness.name})', (
        tester,
      ) async {
        final results = await _pumpCircuit(tester, brightness: brightness);
        expect(find.text('FLEXIONES · RONDA 2'), findsOneWidget);
        // Mandatory tracking: no «Completar sin registrar».
        expect(find.byKey(const Key('set-sheet-skip-tracking')), findsNothing);
        _expectDataNumeral(tester, _count);
        _expectDataNumeral(tester, _weight);
        await _tapSave(tester);
        final result = results.single!;
        expect(
          (result.reps, result.weight, result.rir, result.skipped),
          (12, null, 2, false),
        );
      });
    }

    testWidgets('empty reps on the circuit still shows the reps error', (
      tester,
    ) async {
      final results = await _pumpCircuit(tester, locale: const Locale('en'));
      await tester.enterText(_count, '');
      await _tapSave(tester);
      final l10n = AppLocalizations.of(tester.element(_save));
      expect(find.text(l10n.setPerformanceRepsError), findsOneWidget);
      expect(results, isEmpty);
    });
  });

  group('layout', () {
    testWidgets(
      'a long value shrinks to fit between ± (not below 36 when it fits at 36)',
      (tester) async {
        await _pumpExercise(tester, width: 320, height: 640, textScale: 1.6);
        await tester.enterText(_weight, '62,5,5');
        await tester.pump();
        final size = _fieldStyle(tester, _weight).fontSize!;
        expect(size, lessThan(44));
        expect(size, greaterThanOrEqualTo(36));
        // The short reps value keeps the full size.
        expect(_fieldStyle(tester, _count).fontSize, 44);
        expect(tester.widget<TextField>(_weight).controller!.text, '62,5,5');
      },
    );

    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in const [
        (320.0, 1.3),
        (320.0, 1.6),
        (360.0, 1.6),
      ]) {
        testWidgets('${width.toInt()} dp at ${scale}x '
            '(${locale.languageCode}), with an error: no overflow', (
          tester,
        ) async {
          await _pumpExercise(
            tester,
            locale: locale,
            width: width,
            height: 640,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          await tester.enterText(_weight, '62,,5');
          await _tapSave(tester);
          expect(tester.takeException(), isNull);
          expect(_save.hitTestable(), findsOneWidget);
        });
      }

      testWidgets('2.0x (Android nonlinear, ${locale.languageCode}): every '
          'control is reachable by scrolling', (tester) async {
        final results = await _pumpExercise(
          tester,
          locale: locale,
          width: 320,
          height: 640,
          textScaler: const AndroidNonlinearTextScaler(2.0),
        );
        expect(tester.takeException(), isNull);
        final rir = find.text('5+');
        await tester.scrollUntilVisible(
          rir,
          80,
          scrollable: find
              .descendant(
                of: find.byType(SetPerformanceSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(rir.hitTestable(), findsOneWidget);
        await tester.tap(rir);
        await tester.pump();
        expect(_save.hitTestable(), findsOneWidget);
        await _tapSave(tester);
        expect(results.single?.rir, 5);
      });
    }
  });
}
