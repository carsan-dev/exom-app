// L5-D2 · Onboarding (docs/plans/rediseno-app-l5-contrato-v2.md): L4-I19 and
// D14-4. The body and goals steps accept a decimal with the separator of the
// language («70,5» in es, «70.5» in en) and show it with that separator in the
// field, in the control's accessible value and in the summary; the value sent
// (`height`, `current_weight`, `muscle_mass_goal`) is the same number. The
// sliders become ExomNumeralStepper with today's range, step and typed entry
// (table «Rangos de los steppers»: 140-220 cm and 40-200 kg, step 1; a typed
// value > 0 has no cap). Invalid or ambiguous text is never turned silently
// into another number: it shows an inline error and nothing advances.
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_body_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_goals_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_summary_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../onboarding_test_support.dart';

const _height = 'onboarding-height';
const _weight = 'onboarding-weight';
const _bodyNext = 'onboarding-body-next';
const _muscle = 'onboarding-muscle-goal';
const _goalsNext = 'onboarding-goals-next';

class _Sent {
  final List<Map<String, dynamic>> data = [];
  Map<String, dynamic> get last => data.last;
}

Future<_Sent> _pumpBody(
  WidgetTester tester, {
  Locale locale = const Locale('es'),
  Map<String, dynamic> initialData = const {},
}) async {
  final sent = _Sent();
  await pumpOnboardingStep(
    tester,
    OnboardingBodyStep(
      initialData: initialData,
      onNext: sent.data.add,
      onSkip: () {},
    ),
    locale: locale,
  );
  return sent;
}

Future<_Sent> _pumpGoals(
  WidgetTester tester, {
  Locale locale = const Locale('es'),
  Map<String, dynamic> initialData = const {},
}) async {
  final sent = _Sent();
  await pumpOnboardingStep(
    tester,
    OnboardingGoalsStep(
      initialData: initialData,
      onNext: sent.data.add,
      onSkip: () {},
    ),
    locale: locale,
  );
  return sent;
}

Future<void> _pumpSummary(
  WidgetTester tester,
  Map<String, dynamic> data, {
  Locale locale = const Locale('es'),
}) => pumpOnboardingStep(
  tester,
  OnboardingSummaryStep(
    accumulatedData: data,
    avatarUrl: null,
    onConfirm: () {},
    onEditBasics: () {},
    onEditBody: () {},
    onEditGoals: () {},
  ),
  locale: locale,
);

/// Accessible value of the stepper with [key] («70,5 kg»).
String? _stepperValue(WidgetTester tester, String key) {
  final node = tester.getSemantics(
    find
        .descendant(
          of: find.byKey(Key(key)),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.value != null,
          ),
        )
        .first,
  );
  return node.value;
}

Future<void> _finishTyping(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('L4-I19 (a) accepts the decimal of the language', () {
    final cases = {
      const Locale('es'): ('70,5', '180,5'),
      const Locale('en'): ('70.5', '180.5'),
    };
    for (final MapEntry(key: locale, value: (weight, height))
        in cases.entries) {
      testWidgets('${locale.languageCode}: body sends the typed numbers', (
        tester,
      ) async {
        final sent = await _pumpBody(tester, locale: locale);
        await typeIntoStepper(tester, _weight, weight);
        await _finishTyping(tester);
        await typeIntoStepper(tester, _height, height);
        await _finishTyping(tester);
        await tapKey(tester, _bodyNext);
        expect(sent.data, hasLength(1));
        expect(sent.last['current_weight'], 70.5);
        expect(sent.last['height'], 180.5);
      });

      testWidgets('${locale.languageCode}: goals send the typed muscle goal', (
        tester,
      ) async {
        final sent = await _pumpGoals(tester, locale: locale);
        await tester.enterText(find.byKey(const Key(_muscle)), weight);
        await tapKey(tester, _goalsNext);
        expect(sent.data, hasLength(1));
        expect(sent.last['muscle_mass_goal'], 70.5);
      });
    }
  });

  group('L4-I19 (b) shows the separator of the language', () {
    final cases = {const Locale('es'): '70,5', const Locale('en'): '70.5'};
    for (final MapEntry(key: locale, value: shown) in cases.entries) {
      final code = locale.languageCode;
      testWidgets('$code: field and control label of a typed weight', (
        tester,
      ) async {
        await _pumpBody(tester, locale: locale);
        await typeIntoStepper(tester, _weight, shown);
        await _finishTyping(tester);
        expect(
          find.descendant(
            of: find.byKey(const Key(_weight)),
            matching: findFigure(shown),
          ),
          findsOneWidget,
        );
        expect(_stepperValue(tester, _weight), '$shown kg');
      });

      testWidgets('$code: field and control label of a loaded weight', (
        tester,
      ) async {
        await _pumpBody(
          tester,
          locale: locale,
          initialData: const {'height': 180.5, 'current_weight': 70.5},
        );
        final height = code == 'es' ? '180,5' : '180.5';
        expect(
          find.descendant(
            of: find.byKey(const Key(_weight)),
            matching: findFigure(shown),
          ),
          findsOneWidget,
        );
        expect(_stepperValue(tester, _weight), '$shown kg');
        expect(_stepperValue(tester, _height), '$height cm');
      });

      testWidgets('$code: loaded muscle goal in its field', (tester) async {
        await _pumpGoals(
          tester,
          locale: locale,
          initialData: const {'muscle_mass_goal': 70.5},
        );
        final field = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key(_muscle)),
            matching: find.byType(EditableText),
          ),
        );
        expect(field.controller.text, shown);
      });

      testWidgets('$code: summary keeps every field with the separator', (
        tester,
      ) async {
        await _pumpSummary(tester, const {
          'first_name': 'Lucía',
          'last_name': 'Martín',
          'height': 180.5,
          'current_weight': 70.5,
          'muscle_mass_goal': 34.5,
          'target_calories': 2100,
        }, locale: locale);
        final height = code == 'es' ? '180,5' : '180.5';
        final muscle = code == 'es' ? '34,5' : '34.5';
        expect(findFigure(height), findsOneWidget);
        expect(findFigure(shown), findsOneWidget);
        expect(findFigure(muscle), findsOneWidget);
        expect(findFigure('2100'), findsOneWidget);
        if (code == 'es') expect(findFigure('70.5'), findsNothing);
        // R20: the muscle mass goal and the calories stay in the summary.
        final muscleLabel = code == 'es'
            ? 'Meta de masa muscular'
            : 'Muscle mass goal';
        final caloriesLabel = code == 'es'
            ? 'Calorías objetivo'
            : 'Target calories';
        expect(find.textContaining(muscleLabel), findsOneWidget);
        expect(find.textContaining(caloriesLabel), findsOneWidget);
      });
    }
  });

  group('D14-4 steppers keep today\'s range, step and typed entry', () {
    testWidgets('untouched sends the starting values, as the sliders did', (
      tester,
    ) async {
      final sent = await _pumpBody(tester);
      await tapKey(tester, _bodyNext);
      expect(sent.last['height'], 170.0);
      expect(sent.last['current_weight'], 70.0);
    });

    testWidgets('± moves by 1 and stops at 140-220 cm and 40-200 kg', (
      tester,
    ) async {
      final sent = await _pumpBody(
        tester,
        initialData: const {'height': 220.0, 'current_weight': 40.0},
      );
      Finder button(String key, IconData icon) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byIcon(icon),
      );
      await tester.tap(button(_height, ExomIcons.add));
      await tester.tap(button(_weight, ExomIcons.remove));
      await tester.pump();
      await tapKey(tester, _bodyNext);
      expect(sent.last['height'], 220.0);
      expect(sent.last['current_weight'], 40.0);
      await tester.tap(button(_height, ExomIcons.remove));
      await tester.tap(button(_weight, ExomIcons.add));
      await tester.pump();
      await tapKey(tester, _bodyNext);
      expect(sent.last['height'], 219.0);
      expect(sent.last['current_weight'], 41.0);
    });

    testWidgets('a typed value outside the ± range is sent as typed', (
      tester,
    ) async {
      final sent = await _pumpBody(tester);
      await typeIntoStepper(tester, _height, '250');
      await _finishTyping(tester);
      await typeIntoStepper(tester, _weight, '30,25');
      await _finishTyping(tester);
      await tapKey(tester, _bodyNext);
      expect(sent.last['height'], 250.0);
      expect(sent.last['current_weight'], 30.25);
    });

    testWidgets('the other language separator reads as a decimal', (
      tester,
    ) async {
      final sent = await _pumpBody(tester);
      await typeIntoStepper(tester, _weight, '70.5');
      await _finishTyping(tester);
      await tapKey(tester, _bodyNext);
      expect(sent.last['current_weight'], 70.5);
      expect(_stepperValue(tester, _weight), '70,5 kg');
    });

    testWidgets('en: a typed value outside the ± range is sent as typed', (
      tester,
    ) async {
      final sent = await _pumpBody(tester, locale: const Locale('en'));
      await typeIntoStepper(tester, _height, '250');
      await _finishTyping(tester);
      await typeIntoStepper(tester, _weight, '30.25');
      await _finishTyping(tester);
      await tapKey(tester, _bodyNext);
      expect(sent.last['height'], 250.0);
      expect(sent.last['current_weight'], 30.25);
    });

    testWidgets('en: the other language separator reads as a decimal', (
      tester,
    ) async {
      final sent = await _pumpBody(tester, locale: const Locale('en'));
      await typeIntoStepper(tester, _weight, '70,5');
      await _finishTyping(tester);
      await tapKey(tester, _bodyNext);
      expect(sent.last['current_weight'], 70.5);
      expect(_stepperValue(tester, _weight), '70.5 kg');
    });

    // Accepted behaviour, the same rule as Perfil (B4) and the metrics: a
    // comma or a point is always a decimal separator, never grouping. In
    // English «1,750» is therefore 1.75, not 1750 (the old English field
    // dropped it silently and kept the previous value). A thousand is not a
    // plausible height, weight or muscle mass here.
    testWidgets('en: «1,750» is read as 1.75, never as a thousand', (
      tester,
    ) async {
      final sent = await _pumpBody(tester, locale: const Locale('en'));
      await typeIntoStepper(tester, _weight, '1,750');
      await _finishTyping(tester);
      await tapKey(tester, _bodyNext);
      expect(sent.last['current_weight'], 1.75);
    });
  });

  // (locale, «not a number» text, «not greater than 0» text) of the inline
  // errors; the same texts are rejected in both languages.
  final languages = {
    const Locale('es'): (
      'Introduce un número válido.',
      'Introduce un valor mayor que 0.',
    ),
    const Locale('en'): (
      'Enter a valid number.',
      'Enter a value greater than 0.',
    ),
  };
  for (final MapEntry(key: locale, value: (invalid, notPositive))
      in languages.entries) {
    group('invalid or ambiguous text is never sent as another number '
        '(${locale.languageCode})', () {
      for (final raw in const ['70,5,3', '1.234,5', '7..5', '']) {
        testWidgets('body: «$raw» shows an error and does not advance', (
          tester,
        ) async {
          final sent = await _pumpBody(tester, locale: locale);
          await typeIntoStepper(tester, _weight, raw);
          await tapKey(tester, _bodyNext);
          expect(sent.data, isEmpty);
          expect(find.text(invalid), findsOneWidget);
          // Fixing the text clears the error and sends what is typed.
          await tester.enterText(find.byType(EditableText).first, '71.5');
          await tester.pump();
          expect(find.text(invalid), findsNothing);
          await tapKey(tester, _bodyNext);
          expect(sent.last['current_weight'], 71.5);
        });
      }

      testWidgets('body: 0 is not greater than 0', (tester) async {
        final sent = await _pumpBody(tester, locale: locale);
        await typeIntoStepper(tester, _height, '0');
        await _finishTyping(tester);
        await tapKey(tester, _bodyNext);
        expect(sent.data, isEmpty);
        expect(find.text(notPositive), findsOneWidget);
      });

      for (final raw in const ['70,5,3', '1.234,5']) {
        testWidgets('goals: «$raw» shows an error and does not advance', (
          tester,
        ) async {
          final sent = await _pumpGoals(tester, locale: locale);
          await tester.enterText(find.byKey(const Key(_muscle)), raw);
          await tapKey(tester, _goalsNext);
          expect(sent.data, isEmpty);
          expect(find.text(invalid), findsOneWidget);
        });
      }

      testWidgets('goals: an empty optional goal advances without it', (
        tester,
      ) async {
        final sent = await _pumpGoals(tester, locale: locale);
        await tester.enterText(find.byKey(const Key(_muscle)), '');
        await tapKey(tester, _goalsNext);
        expect(sent.data, hasLength(1));
        expect(sent.last.containsKey('muscle_mass_goal'), isFalse);
      });
    });
  }

  group('no floating point residue is shown, the stored number is kept', () {
    testWidgets('a loaded 70.50000002 shows 70,5 and is sent unchanged', (
      tester,
    ) async {
      final sent = await _pumpBody(
        tester,
        initialData: const {'current_weight': 70.50000002},
      );
      expect(_stepperValue(tester, _weight), '70,5 kg');
      await tapKey(tester, _bodyNext);
      expect(sent.last['current_weight'], 70.50000002);
    });

    testWidgets('a loaded 0.1 + 0.2 shows 0,3', (tester) async {
      await _pumpBody(tester, initialData: {'current_weight': 0.1 + 0.2});
      expect(_stepperValue(tester, _weight), '0,3 kg');
    });

    testWidgets('± from a typed 70,5 gives exactly 71.5', (tester) async {
      final sent = await _pumpBody(tester);
      await typeIntoStepper(tester, _weight, '70,5');
      await _finishTyping(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key(_weight)),
          matching: find.byIcon(ExomIcons.add),
        ),
      );
      await tester.pump();
      await tapKey(tester, _bodyNext);
      expect(sent.last['current_weight'], 71.5);
      expect(_stepperValue(tester, _weight), '71,5 kg');
    });

    testWidgets('an untouched muscle goal of 34.567 is sent unchanged', (
      tester,
    ) async {
      final sent = await _pumpGoals(
        tester,
        initialData: const {'muscle_mass_goal': 34.567},
      );
      await tapKey(tester, _goalsNext);
      expect(sent.last['muscle_mass_goal'], 34.567);
    });

    testWidgets('summary of 0.1 + 0.2 and 70.50000002', (tester) async {
      await _pumpSummary(tester, {
        'height': 0.1 + 0.2,
        'current_weight': 70.50000002,
      });
      expect(findFigure('0,3'), findsOneWidget);
      expect(findFigure('70,5'), findsOneWidget);
      expect(findFigure('0000'), findsNothing);
    });
  });
}
