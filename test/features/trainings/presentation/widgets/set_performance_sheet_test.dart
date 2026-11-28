// Set-logging sheet of the active exercise (L3 unit 3): D3 parsing and field
// errors, D4 prefill, D5 units, RIR chips, the sheet contract
// (showSetPerformanceSheet returns after the sheet is disposed; a duplicate
// trigger resolves to null) and the pinned actions above the keyboard.
import 'dart:ui' show Tristate;

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';

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

Future<List<SetPerformanceResult?>> _pump(
  WidgetTester tester, {
  int setNumber = 2,
  String prescribedReps = '8 reps · RIR 2',
  bool repsRequired = false,
  TimePerformanceUnit? timeUnit,
  double? previousWeight,
  SetPerformance? currentPerformance,
  SetPerformance? previousPerformance,
  List<SetPerformance>? previousSession,
  SetPerformance? lastSetThisExecution,
  int? targetCount,
  int? targetRir,
  UnitSystem unitSystem = UnitSystem.metric,
  Locale locale = const Locale('es'),
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Brightness brightness = Brightness.dark,
}) async {
  final results = <SetPerformanceResult?>[];
  await pumpComponent(
    tester,
    _Host(
      results: results,
      open: (context) => showSetPerformanceSheet(
        context,
        AppLocalizations.of(context),
        setNumber: setNumber,
        prescribedReps: prescribedReps,
        repsRequired: repsRequired,
        timeUnit: timeUnit,
        previousWeight: previousWeight,
        currentPerformance: currentPerformance,
        previousPerformance: previousPerformance,
        previousSession: previousSession,
        lastSetThisExecution: lastSetThisExecution,
        targetCount: targetCount,
        targetRir: targetRir,
        unitSystem: unitSystem,
      ),
    ),
    locale: locale,
    width: width,
    height: height,
    textScale: textScale,
    viewInsets: viewInsets,
    brightness: brightness,
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return results;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(const Key('set-sheet-save'))));

final _count = find.byKey(const Key('set-sheet-count-field'));
final _weight = find.byKey(const Key('set-sheet-weight-field'));
final _save = find.byKey(const Key('set-sheet-save'));

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

void main() {
  group('D3 field errors', () {
    testWidgets('«62,5,5» keeps the text, shows the error under the weight, '
        'moves focus and does not save; correcting it saves 62.5 kg', (
      tester,
    ) async {
      final results = await _pump(tester, targetCount: 8);
      await tester.enterText(_weight, '62,5,5');
      await tester.pump();
      await _tapSave(tester);

      final l10n = _l10n(tester);
      expect(results, isEmpty, reason: 'nothing saved');
      expect(find.byType(ExomSheetRoute<SetPerformanceResult>), findsNothing);
      expect(_text(tester, _weight), '62,5,5');
      expect(find.text(l10n.setInputNotANumber('62,5,5', '62,5')), findsOneWidget);
      expect(tester.widget<TextField>(_weight).focusNode!.hasFocus, isTrue);

      // Live clearing once the text is valid again.
      await tester.enterText(_weight, '62,5');
      await tester.pump();
      expect(find.text(l10n.setInputNotANumber('62,5,5', '62,5')), findsNothing);
      await _tapSave(tester);
      expect(results.single?.weight, 62.5);
      expect(results.single?.reps, 8);
    });

    testWidgets('«abc» in the weight never becomes a silent null', (
      tester,
    ) async {
      // Replaces the pre-L3 behaviour (D3): double.tryParse turned «abc» into
      // a set without weight.
      final results = await _pump(tester, targetCount: 8);
      await tester.enterText(_weight, 'abc');
      await _tapSave(tester);
      expect(results, isEmpty);
      expect(_text(tester, _weight), 'abc');
    });

    for (final raw in ['62,5', '62.5', ' 62,5 ']) {
      testWidgets('«$raw» is saved as 62.5 kg', (tester) async {
        final results = await _pump(tester, targetCount: 8);
        await tester.enterText(_weight, raw);
        await _tapSave(tester);
        expect(results.single?.weight, 62.5);
      });
    }

    testWidgets('ambiguous, too many decimals and above max are rejected', (
      tester,
    ) async {
      final results = await _pump(tester, targetCount: 8);
      final l10n = _l10n(tester);
      await tester.enterText(_weight, '1.250');
      await _tapSave(tester);
      expect(find.text(l10n.setInputWeightAmbiguous('1.250', '62,5')),
          findsOneWidget);
      await tester.enterText(_weight, '62,1234');
      await _tapSave(tester);
      expect(find.text(l10n.setInputTooManyDecimals('62,5')), findsOneWidget);
      await tester.enterText(_weight, '500,5');
      await _tapSave(tester);
      expect(find.text(l10n.setInputAboveMax('500 kg')), findsOneWidget);
      await tester.enterText(_weight, '-5');
      await _tapSave(tester);
      expect(find.text(l10n.setPerformanceWeightError), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('reps «8.5» and «0» are errors on the reps field', (
      tester,
    ) async {
      final results = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.enterText(_count, '8.5');
      await _tapSave(tester);
      expect(find.text(l10n.setInputNotInteger('8')), findsOneWidget);
      expect(_text(tester, _count), '8.5');
      expect(tester.widget<TextField>(_count).focusNode!.hasFocus, isTrue);
      await tester.enterText(_count, '0');
      await _tapSave(tester);
      expect(find.text(l10n.setPerformanceRepsError), findsOneWidget);
      await tester.enterText(_count, '1000');
      await _tapSave(tester);
      expect(find.text(l10n.setInputAboveMax('999')), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('mandatory tracking with empty reps shows the reps error', (
      tester,
    ) async {
      final results = await _pump(tester, repsRequired: true);
      final l10n = _l10n(tester);
      await tester.enterText(_weight, '60');
      await _tapSave(tester);
      expect(find.text(l10n.setPerformanceRepsError), findsOneWidget);
      expect(results, isEmpty);
      expect(find.text(l10n.completeWithoutTracking), findsNothing);
    });

    testWidgets('a RIR-only set is refused (the API would answer 400)', (
      tester,
    ) async {
      final results = await _pump(tester, targetRir: 2);
      final l10n = _l10n(tester);
      // RIR 2 is preselected; reps and weight are empty.
      expect(_text(tester, _count), '');
      expect(_text(tester, _weight), '');
      await _tapSave(tester);
      expect(find.text(l10n.setPerformanceDataError), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('± are disabled while the field text is invalid', (
      tester,
    ) async {
      await _pump(tester, previousWeight: 60);
      final l10n = _l10n(tester);
      final step = '2,5 kg';
      await tester.tap(find.bySemanticsLabel(l10n.setSheetWeightIncrement(step)));
      await tester.pump();
      expect(_text(tester, _weight), '62,5');
      await tester.enterText(_weight, '6x');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.setSheetWeightIncrement(step)));
      await tester.pump();
      expect(_text(tester, _weight), '6x', reason: '± ignored, text kept');
    });
  });

  group('weight step rounding (L6-RND1)', () {
    testWidgets('the step rounds half up like the rest of the weight code', (
      tester,
    ) async {
      // 1.515 kg + 2.5 = 4.015: the old `(v * 100).round() / 100` gave 4.01
      // (4.015 * 100 = 401.49999999999994); roundToHundredths gives 4.02.
      final semantics = tester.ensureSemantics();
      await _pump(tester, previousWeight: 1.515);
      await tester.enterText(_weight, '');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp('Sumar 2,5')));
      await tester.pump();
      expect(_text(tester, _weight), '4,02');
      semantics.dispose();
    });
  });

  group('optional tracking', () {
    testWidgets('«Completar sin registrar» returns skipped', (tester) async {
      final results = await _pump(tester, repsRequired: false);
      await tester.tap(find.byKey(const Key('set-sheet-skip-tracking')));
      await tester.pumpAndSettle();
      expect(results.single?.skipped, isTrue);
      expect(results.single?.reps, isNull);
    });

    testWidgets('weight alone is a valid set', (tester) async {
      final results = await _pump(tester);
      await tester.enterText(_weight, '40');
      await _tapSave(tester);
      expect(results.single?.weight, 40);
      expect(results.single?.reps, isNull);
    });

    testWidgets('Cancelar returns null (nothing happened)', (tester) async {
      final results = await _pump(tester, targetCount: 8);
      await tester.tap(find.byKey(const Key('set-sheet-cancel')));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });

  group('D4 prefill', () {
    const previous = [
      SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
      SetPerformance(setNumber: 2, reps: 7, weightKg: 57.5, rir: 1),
    ];

    testWidgets("today's value wins", (tester) async {
      await _pump(
        tester,
        currentPerformance: const SetPerformance(
          setNumber: 2,
          reps: 9,
          weightKg: 70,
        ),
        previousWeight: 65,
        previousSession: previous,
        previousPerformance: previous[1],
        targetCount: 8,
      );
      expect(_text(tester, _count), '9');
      expect(_text(tester, _weight), '70');
    });

    testWidgets('then the last weight of this session', (tester) async {
      await _pump(
        tester,
        previousWeight: 65,
        previousSession: previous,
        previousPerformance: previous[1],
        lastSetThisExecution: const SetPerformance(setNumber: 1, reps: 6),
        targetCount: 8,
      );
      expect(_text(tester, _count), '6');
      expect(_text(tester, _weight), '65');
    });

    testWidgets('then the previous session, same set', (tester) async {
      final results = await _pump(
        tester,
        previousSession: previous,
        previousPerformance: previous[1],
        targetCount: 8,
      );
      expect(_text(tester, _count), '7');
      expect(_text(tester, _weight), '57,5');
      await _tapSave(tester);
      expect(results.single?.weight, 57.5);
    });

    testWidgets('then the last weighted set of the previous session', (
      tester,
    ) async {
      await _pump(
        tester,
        setNumber: 3,
        previousSession: previous,
        targetCount: 8,
      );
      expect(_text(tester, _weight), '57,5');
      expect(_text(tester, _count), '8', reason: 'target reps');
    });

    testWidgets('empty without any source', (tester) async {
      await _pump(tester);
      expect(_text(tester, _count), '');
      expect(_text(tester, _weight), '');
    });

    testWidgets('«Igual que la anterior» copies the previous set exactly', (
      tester,
    ) async {
      final results = await _pump(
        tester,
        previousWeight: 62.5,
        previousSession: previous,
        previousPerformance: const SetPerformance(
          setNumber: 2,
          reps: 8,
          weightKg: 60.125,
          rir: 3,
        ),
        targetCount: 10,
        targetRir: 2,
      );
      final l10n = _l10n(tester);
      expect(
        find.text(l10n.setSheetSameAsPrevious('8 × 60,13 kg')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('set-sheet-same-as-previous')));
      await tester.pump();
      expect(_text(tester, _count), '8');
      expect(_text(tester, _weight), '60,13');
      await _tapSave(tester);
      // The previous session's kg, not the 2-decimal text.
      expect(results.single?.weight, 60.125);
      expect(results.single?.reps, 8);
      expect(results.single?.rir, 3);
    });

    testWidgets('«Igual que la anterior» is hidden without previous data', (
      tester,
    ) async {
      await _pump(tester, targetCount: 8);
      expect(find.byKey(const Key('set-sheet-same-as-previous')), findsNothing);
    });
  });

  group('RIR chips', () {
    testWidgets('the target RIR is preselected for a new set and saved', (
      tester,
    ) async {
      final results = await _pump(tester, targetCount: 8, targetRir: 2);
      await _tapSave(tester);
      expect(results.single?.rir, 2);
      expect(results.single?.reps, 8);
    });

    testWidgets('no target, nothing preselected', (tester) async {
      final results = await _pump(tester, targetCount: 8);
      await _tapSave(tester);
      expect(results.single?.rir, isNull);
    });

    testWidgets('a stored RIR 8 shows as 5+ and is kept untouched', (
      tester,
    ) async {
      final results = await _pump(
        tester,
        currentPerformance: const SetPerformance(setNumber: 2, reps: 8, rir: 8),
        targetRir: 2,
      );
      final chip = tester.getSemantics(find.bySemanticsLabel('RIR 5 o más'));
      expect(chip.flagsCollection.isSelected, Tristate.isTrue);
      await _tapSave(tester);
      expect(results.single?.rir, 8);
    });

    testWidgets('picking another chip replaces it; deselecting clears it', (
      tester,
    ) async {
      final results = await _pump(tester, targetCount: 8, targetRir: 2);
      await tester.tap(find.text('5+'));
      await tester.pump();
      await _tapSave(tester);
      expect(results.single?.rir, 5);

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pump();
      await _tapSave(tester);
      expect(results.last?.rir, isNull);
      expect(results.last?.reps, 8);
    });
  });

  group('D5 units', () {
    testWidgets('imperial: typed lb are saved as kg rounded to 3 decimals', (
      tester,
    ) async {
      final results = await _pump(
        tester,
        unitSystem: UnitSystem.imperial,
        targetCount: 8,
      );
      expect(find.text('lb'), findsWidgets);
      await tester.enterText(_weight, '135');
      await _tapSave(tester);
      expect(results.single?.weight, 61.235);
    });

    testWidgets('imperial: the stored kg reopens as the typed lb', (
      tester,
    ) async {
      await _pump(
        tester,
        unitSystem: UnitSystem.imperial,
        previousWeight: 61.235,
      );
      expect(_text(tester, _weight), '135');
    });

    testWidgets('imperial: an untouched prefill is saved exactly', (
      tester,
    ) async {
      final results = await _pump(
        tester,
        unitSystem: UnitSystem.imperial,
        previousWeight: 62.5,
        targetCount: 8,
      );
      expect(_text(tester, _weight), '137,79');
      await _tapSave(tester);
      expect(results.single?.weight, 62.5);
    });

    testWidgets('imperial: ± steps 5 lb and the maximum is 1102.31 lb', (
      tester,
    ) async {
      final results = await _pump(
        tester,
        unitSystem: UnitSystem.imperial,
        previousWeight: 61.235,
        targetCount: 8,
      );
      final l10n = _l10n(tester);
      await tester.tap(
        find.bySemanticsLabel(l10n.setSheetWeightIncrement('5 lb')),
      );
      await tester.pump();
      expect(_text(tester, _weight), '140');
      await tester.enterText(_weight, '1102,32');
      await _tapSave(tester);
      expect(find.text(l10n.setInputAboveMax('1102,31 lb')), findsOneWidget);
      await tester.enterText(_weight, '140');
      await _tapSave(tester);
      expect(results.single?.weight, 63.503);
    });

    testWidgets('metric: an untouched 62.25 kg is not rounded to 62.3', (
      tester,
    ) async {
      final results = await _pump(tester, previousWeight: 62.25, targetCount: 8);
      expect(_text(tester, _weight), '62,25');
      await _tapSave(tester);
      expect(results.single?.weight, 62.25);
    });

    testWidgets('English uses the point', (tester) async {
      final results = await _pump(
        tester,
        locale: const Locale('en'),
        previousWeight: 62.5,
        targetCount: 8,
      );
      expect(_text(tester, _weight), '62.5');
      final l10n = _l10n(tester);
      await tester.enterText(_weight, '62,5,5');
      await _tapSave(tester);
      expect(find.text(l10n.setInputNotANumber('62,5,5', '62.5')), findsOneWidget);
      await tester.enterText(_weight, '62,75');
      await _tapSave(tester);
      expect(results.single?.weight, 62.75);
    });
  });

  group('contract', () {
    testWidgets('a duplicate trigger resolves to null and opens nothing', (
      tester,
    ) async {
      final results = <SetPerformanceResult?>[];
      late BuildContext hostContext;
      await pumpComponent(
        tester,
        Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.expand();
          },
        ),
      );
      Future<void> open() async => results.add(
        await showSetPerformanceSheet(
          hostContext,
          AppLocalizations.of(hostContext),
          setNumber: 1,
          prescribedReps: '8 reps',
          repsRequired: true,
          timeUnit: null,
          targetCount: 8,
        ),
      );
      final first = open();
      final second = open();
      await tester.pumpAndSettle();
      await second;
      expect(results, [null], reason: 'the duplicate resolved to null');
      expect(find.byKey(const Key('set-sheet-save')), findsOneWidget);
      await tester.tap(_save);
      await tester.pumpAndSettle();
      await first;
      expect(results.last?.reps, 8);
    });

    testWidgets('returns only after the sheet subtree is disposed', (
      tester,
    ) async {
      final results = await _pump(tester, targetCount: 8);
      await tester.tap(_save);
      await tester.pump();
      // Popped but still animating out: no result yet.
      expect(results, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(results, isEmpty);
      await tester.pumpAndSettle();
      expect(results.single?.reps, 8);
    });

    testWidgets('repeated taps on Guardar save once', (tester) async {
      final results = await _pump(tester, targetCount: 8);
      await tester.tap(_save);
      await tester.pump();
      await tester.tap(_save, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(results, hasLength(1));
    });

    testWidgets('ten sets in a row, two taps each (principle 20)', (
      tester,
    ) async {
      final results = <SetPerformanceResult?>[];
      await pumpComponent(
        tester,
        _Host(
          results: results,
          open: (context) => showSetPerformanceSheet(
            context,
            AppLocalizations.of(context),
            setNumber: results.length + 1,
            prescribedReps: '8 reps',
            repsRequired: true,
            timeUnit: null,
            previousWeight: 60,
            targetCount: 8,
          ),
        ),
      );
      // Only the motion tokens are waited for (sheet in 280 ms, out 200 ms,
      // plus the disposal frame): no settle, no extra delay per set.
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byKey(const Key('open')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 280));
        await tester.tap(_save);
        await tester.pump();
        var frames = 0;
        while (results.length < i + 1 && frames < 10) {
          await tester.pump(const Duration(milliseconds: 50));
          frames++;
        }
        expect(frames, lessThanOrEqualTo(6), reason: 'set ${i + 1} closed late');
      }
      expect(results, hasLength(10));
      expect(results.every((r) => r?.reps == 8 && r?.weight == 60), isTrue);
    });
  });

  group('timed sets', () {
    testWidgets('minutes input is saved as seconds', (tester) async {
      final results = await _pump(
        tester,
        timeUnit: TimePerformanceUnit.minutes,
        targetCount: 600,
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.setPerformanceMinutes), findsOneWidget);
      expect(_text(tester, _count), '10');
      await _tapSave(tester);
      expect(results.single?.seconds, 600);
      expect(results.single?.reps, isNull);
    });

    testWidgets('seconds step by 5', (tester) async {
      final results = await _pump(
        tester,
        timeUnit: TimePerformanceUnit.seconds,
        targetCount: 45,
      );
      final l10n = _l10n(tester);
      await tester.tap(find.bySemanticsLabel(l10n.setSheetSecondsIncrement(5)));
      await tester.pump();
      await _tapSave(tester);
      expect(results.single?.seconds, 50);
    });
  });

  group('layout', () {
    for (final brightness in Brightness.values) {
      testWidgets('320 dp at 1.6x with errors, no overflow (${brightness.name})',
          (tester) async {
        await _pump(
          tester,
          width: 320,
          height: 640,
          textScale: 1.6,
          brightness: brightness,
          previousSession: const [
            SetPerformance(setNumber: 2, reps: 8, weightKg: 60, rir: 2),
          ],
          previousPerformance: const SetPerformance(
            setNumber: 2,
            reps: 8,
            weightKg: 60,
            rir: 2,
          ),
          targetCount: 8,
          targetRir: 2,
        );
        await tester.enterText(_count, '8.5');
        await tester.enterText(_weight, '62,5,5');
        await _tapSave(tester);
        expect(tester.takeException(), isNull);
        expect(_save.hitTestable(), findsOneWidget);
        await expectTapTargetGuidelines(tester);
      });
    }

    testWidgets('with the keyboard open the save button stays reachable', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 360,
        height: 740,
        textScale: 1.3,
        viewInsets: const EdgeInsets.only(bottom: 300),
        targetCount: 8,
      );
      expect(_save.hitTestable(), findsOneWidget);
      final saveRect = tester.getRect(_save);
      expect(saveRect.bottom, lessThanOrEqualTo(740 - 300));
      await tester.enterText(_weight, 'abc');
      await _tapSave(tester);
      expect(_save.hitTestable(), findsOneWidget);
      final weightRect = tester.getRect(_weight);
      expect(weightRect.bottom, lessThanOrEqualTo(saveRect.top));
    });
  });
}
