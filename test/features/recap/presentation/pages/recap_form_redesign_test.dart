// L5-C5a · Recap, formulario por pasos: validation in line (D14-3), the body
// map with a Frontal/Posterior segmented control that keeps the selection, the
// M9 step transition with its reduced variant, and the copy of the form (D15).
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';

import 'recap_list_redesign_test.dart' show pumpRecapList, recapListOpen;

RecapBloc _bloc(WidgetTester tester) =>
    BlocProvider.of<RecapBloc>(tester.element(find.byType(Scaffold).first));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _openStep(
  WidgetTester tester,
  int step, {
  Locale locale = const Locale('es'),
}) async {
  await pumpRecapList(tester, recaps: recapListOpen(), locale: locale);
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await _settle(tester);
  _bloc(tester).add(RecapStepChanged(step));
  await _settle(tester);
}

/// Opens the form of a new recap at [step] on the list harness. With [rich] the
/// scene carries what makes the step longest: an invalid number of steps with
/// its reason, many chosen zones, the optional switches on and a long note.
Future<void> pumpRecapForm(
  WidgetTester tester, {
  required int step,
  Locale locale = const Locale('es'),
  double width = 390,
  double height = 844,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
  bool rich = false,
}) async {
  await pumpRecapList(
    tester,
    recaps: recapListOpen(),
    locale: locale,
    width: width,
    height: height,
    dark: dark,
    textScaler: textScaler,
  );
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await _settle(tester);
  final bloc = _bloc(tester);
  if (rich) {
    final long = List.filled(12, 'Observaciones largas').join(' ');
    for (final (field, value) in <(String, Object?)>[
      ('average_daily_steps', 250000),
      (
        'muscle_pain_zones',
        [
          'neck_front',
          'shoulder_left_front',
          'shoulder_right_front',
          'glutes_left',
          'calves_right',
        ],
      ),
      ('hydration_enabled', true),
      ('stress_enabled', true),
      ('training_notes', long),
      ('improvement_areas', ['ENTRENAMIENTO', 'NUTRICION', 'APP']),
    ]) {
      bloc.add(RecapFieldUpdated(field: field, value: value));
    }
    await _settle(tester);
  }
  bloc.add(RecapStepChanged(step));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  tearDown(() async => sl.reset());

  group('validation in line (D14-3)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('an invalid value gives the reason under the field and a '
          'line above the button, with no SnackBar (${locale.languageCode})', (
        tester,
      ) async {
        await _openStep(tester, 1, locale: locale);
        final l10n = _l10n(tester);
        final steps = find.byType(TextField).first;
        await tester.ensureVisible(steps);
        await tester.enterText(steps, '250000');
        await tester.pump(const Duration(milliseconds: 300));

        final field = find.byType(RecapIntegerField);
        final reason = find.descendant(
          of: field,
          matching: find.byType(ExomInlineMessage),
        );
        expect(reason, findsOneWidget);
        expect(
          tester.widget<ExomInlineMessage>(reason).kind,
          ExomMessageKind.error,
        );
        expect(
          find.descendant(
            of: reason,
            matching: find.text(l10n.averageDailyStepsRangeError),
          ),
          findsOneWidget,
        );

        final line = find.descendant(
          of: find.byType(ExomPinnedFooter),
          matching: find.byType(ExomInlineMessage),
        );
        expect(line, findsOneWidget);
        expect(
          find.descendant(
            of: line,
            matching: find.text(l10n.correctInvalidRecapFields),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);

        // Saving is blocked (the button is disabled), says why in line and
        // pressing it does nothing, never a SnackBar.
        final save = find.byWidgetPredicate(
          (widget) =>
              widget is ExomQuietButton && widget.label == l10n.recapSaveDraft,
        );
        expect(tester.widget<ExomQuietButton>(save).onPressed, isNull);
        await tester.tap(save, warnIfMissed: false);
        await _settle(tester);
        expect(_bloc(tester).state, isA<RecapFormActive>());
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('a valid value shows neither the reason nor the line', (
      tester,
    ) async {
      await _openStep(tester, 1);
      final steps = find.byType(TextField).first;
      await tester.ensureVisible(steps);
      await tester.enterText(steps, '8500');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExomInlineMessage), findsNothing);
    });
  });

  group('body map: Frontal / Posterior', () {
    testWidgets('it uses the segmented control and keeps the selection when '
        'the view changes', (tester) async {
      var selected = <String>{'neck_front', 'glutes_left'};
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => RecapAnatomySelector(
                  selectedZoneIds: selected,
                  onZoneSelected: (id) {
                    taps.add(id);
                    setState(() => selected = {...selected, id});
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final control = find.byType(ExomSegmentedControl<RecapAnatomyView>);
      expect(control, findsOneWidget);
      expect(
        tester.widget<ExomSegmentedControl<RecapAnatomyView>>(control).selected,
        RecapAnatomyView.front,
      );
      await tester.tap(find.text('Posterior'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<ExomSegmentedControl<RecapAnatomyView>>(control).selected,
        RecapAnatomyView.back,
      );
      await tester.tap(find.text('Frontal'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, {'neck_front', 'glutes_left'});
      expect(taps, isEmpty);
    });

    testWidgets('in the form the chosen zones stay chosen across views and '
        'reach the draft', (tester) async {
      await _openStep(tester, 3);
      _bloc(tester).add(
        const RecapFieldUpdated(
          field: 'muscle_pain_zones',
          value: ['neck_front', 'glutes_left'],
        ),
      );
      await _settle(tester);
      await tester.ensureVisible(find.text('Posterior'));
      await tester.tap(find.text('Posterior'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Frontal'));
      await tester.pump(const Duration(milliseconds: 300));
      final form = _bloc(tester).state as RecapFormActive;
      expect(form.formData['muscle_pain_zones'], ['neck_front', 'glutes_left']);
      expect(find.byType(ExomSegmentedControl<RecapAnatomyView>), findsOne);
    });
  });

  group('M9 step transition', () {
    double slide(WidgetTester tester) {
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(ExomStepTransition),
          matching: find.byType(Transform),
        ),
      );
      var largest = 0.0;
      for (final transform in transforms) {
        final x = transform.transform.getTranslation().x.abs();
        if (x > largest) largest = x;
      }
      return largest;
    }

    Future<void> advance(WidgetTester tester) async {
      _bloc(tester).add(const RecapStepChanged(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the steps change inside ExomStepTransition and slide', (
      tester,
    ) async {
      await _openStep(tester, 1);
      expect(find.byType(ExomStepTransition), findsOneWidget);
      await advance(tester);
      expect(slide(tester), greaterThan(0));
      await _settle(tester);
      expect(slide(tester), 0);
    });

    testWidgets('reduced motion: the step fades and does not slide', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openStep(tester, 1);
      expect(find.byType(ExomStepTransition), findsOneWidget);
      await advance(tester);
      expect(slide(tester), 0);
      await _settle(tester);
      expect(find.byType(ExomScaleChips), findsWidgets);
    });
  });

  group('copy (D15)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('the form says five steps (${locale.languageCode})', (
        tester,
      ) async {
        await pumpRecapList(tester, recaps: recapListOpen(), locale: locale);
        await tester.tap(find.byKey(const ValueKey('recap-new')));
        await _settle(tester);
        final l10n = _l10n(tester);
        final word = locale.languageCode == 'es' ? 'cinco' : 'five';
        final stale = locale.languageCode == 'es' ? 'cuatro' : 'four';
        expect(l10n.recapStartDescription, contains(word));
        expect(l10n.recapStartDescription, isNot(contains(stale)));
        expect(
          l10n.completeTheFourBlocksAndSendYourWeeklySummary,
          contains(word),
        );
        expect(
          l10n.completeTheFourBlocksAndSendYourWeeklySummary,
          isNot(contains(stale)),
        );
        expect(
          l10n.recapListEmptyCoachText,
          locale.languageCode == 'es'
              ? 'Cuéntame cómo ha ido tu semana en cinco pasos.'
              : 'Tell me how your week went in five steps.',
        );
        expect(find.textContaining(stale), findsNothing);
      });
    }

    testWidgets('the last step sends with «ENVIAR RECAP»', (tester) async {
      await _openStep(tester, 5);
      expect(find.text('ENVIAR RECAP'), findsOneWidget);
    });
  });

  group('large text', () {
    for (final step in const [1, 3, 4]) {
      testWidgets('step $step at 320 dp, 2.0x: the last question and the '
          'action stay reachable by scrolling', (tester) async {
        await pumpRecapForm(
          tester,
          step: step,
          width: 320,
          height: 640,
          rich: true,
          textScaler: AndroidNonlinearTextScaler(2.0),
        );
        final last = find.byType(TextField).last;
        await tester.scrollUntilVisible(
          last,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(last, findsOneWidget);
        expect(find.byKey(const ValueKey('recap-step-action')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('guidelines', () {
    testWidgets('step 5 valid: the send action reaches the contrast in dark', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRecapForm(tester, step: 5, dark: true);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    for (final dark in [true, false]) {
      for (final step in const [0, 1, 2, 3, 4, 5]) {
        testWidgets('step $step: tap targets, labels, contrast (dark=$dark)', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await pumpRecapForm(tester, step: step, dark: dark, rich: step != 0);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // With an invalid value the send action is inactive (WCAG 1.4.3
          // exempts it); the shared button paints it 4.25:1 in the dark theme.
          if (!(step == 5 && dark)) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          if (!dark) expectNoLimeInk(tester);
          handle.dispose();
        });
      }
    }
  });
}
