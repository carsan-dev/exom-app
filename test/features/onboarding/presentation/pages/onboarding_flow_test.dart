// L5-D2 · Onboarding (docs/plans/rediseno-app-l5-contrato-v2.md), page level:
// D17-5 back arrow between steps (none on step 1; what was typed is kept going
// back and forward; OnboardingBloc untouched; the system back is not taken
// over; M9 in the opposite direction), D14-3/8 save error inline with the data
// kept, and the whole flow sending the typed numbers unchanged.
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../onboarding_test_support.dart';

const _back = 'onboarding-back';
const _transition = 'onboarding-step-transition';

Future<void> _start(WidgetTester tester) async {
  await tapKey(tester, 'onboarding-start');
  await settleOnboarding(tester);
}

Future<void> _next(WidgetTester tester, String key) async {
  await tapKey(tester, key);
  await settleOnboarding(tester);
}

/// Plays the first ~140 ms of a step change (M9): the new step is still
/// entering (since L5-C5b a 280 ms push with the step that goes out); the
/// full transition has its own tests (`onboarding_transition_test.dart`).
Future<void> _pastLeave(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 110));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

/// Horizontal offset of the step entrance (M9) right now: the step on
/// screen or entering, which the page paints last.
double _entranceOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byKey(const Key(_transition)).last,
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.getTranslation().x;
}

void main() {
  group('D17-5 back arrow between steps', () {
    testWidgets('no arrow on the welcome or on step 1', (tester) async {
      await pumpOnboardingPage(tester, FakeOnboardingRepository());
      expect(find.byKey(const Key(_back)), findsNothing);
      await _start(tester);
      expect(find.byKey(const Key('onboarding-basics-next')), findsOneWidget);
      expect(find.byKey(const Key(_back)), findsNothing);
    });

    testWidgets('step 2 back to step 1 keeps what was typed in both', (
      tester,
    ) async {
      await pumpOnboardingPage(tester, FakeOnboardingRepository());
      await _start(tester);
      await tester.enterText(
        find.byKey(const Key('onboarding-first-name')),
        'Lucía Ana',
      );
      await _next(tester, 'onboarding-basics-next');
      await typeIntoStepper(tester, 'onboarding-weight', '70,5');
      expect(find.byKey(const Key(_back)), findsOneWidget);
      await tapKey(tester, _back);
      await settleOnboarding(tester);
      // Back on step 1 with the typed name, and no arrow there.
      expect(find.byKey(const Key('onboarding-basics-next')), findsOneWidget);
      expect(find.byKey(const Key(_back)), findsNothing);
      expect(find.text('Lucía Ana'), findsOneWidget);
      // Forward again: the weight typed on step 2 (never sent) is still there.
      await _next(tester, 'onboarding-basics-next');
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-weight')),
          matching: findFigure('70,5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('summary back to goals, goals back to body', (tester) async {
      await pumpOnboardingPage(tester, FakeOnboardingRepository());
      await _start(tester);
      await _next(tester, 'onboarding-basics-next');
      await _next(tester, 'onboarding-body-next');
      await _next(tester, 'onboarding-goals-next');
      expect(
        find.byKey(const Key('onboarding-summary-confirm')),
        findsOneWidget,
      );
      await tapKey(tester, _back);
      await settleOnboarding(tester);
      expect(find.byKey(const Key('onboarding-goals-next')), findsOneWidget);
      await tapKey(tester, _back);
      await settleOnboarding(tester);
      expect(find.byKey(const Key('onboarding-body-next')), findsOneWidget);
    });

    testWidgets('the system back is not taken over by the page', (
      tester,
    ) async {
      await pumpOnboardingPage(tester, FakeOnboardingRepository());
      await _start(tester);
      await _next(tester, 'onboarding-basics-next');
      expect(
        find.descendant(
          of: find.byType(OnboardingPage),
          matching: find.byType(PopScope),
        ),
        findsNothing,
      );
    });

    testWidgets('M9: forward enters from the end, back from the start', (
      tester,
    ) async {
      await pumpOnboardingPage(
        tester,
        FakeOnboardingRepository(),
        disableAnimations: false,
      );
      await _start(tester);
      await tapKey(tester, 'onboarding-basics-next');
      await _pastLeave(tester);
      expect(_entranceOffset(tester), greaterThan(0));
      await settleOnboarding(tester);
      expect(_entranceOffset(tester), 0);
      await tapKey(tester, _back);
      await _pastLeave(tester);
      expect(_entranceOffset(tester), lessThan(0));
      await settleOnboarding(tester);
      expect(_entranceOffset(tester), 0);
    });

    testWidgets('M9 reduced: a fade without offset', (tester) async {
      await pumpOnboardingPage(tester, FakeOnboardingRepository());
      await _start(tester);
      await tapKey(tester, 'onboarding-basics-next');
      // Reduced, the crossfade lasts 100 ms from the tap (round 5, overlap):
      // half-way both steps fade, neither moves.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_entranceOffset(tester), 0);
      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(const Key(_transition)),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1));
      await settleOnboarding(tester);
    });
  });

  group('the whole flow sends the typed numbers unchanged', () {
    final cases = {
      const Locale('es'): ('70,5', '34,5'),
      const Locale('en'): ('70.5', '34.5'),
    };
    for (final MapEntry(key: locale, value: (weight, muscle))
        in cases.entries) {
      testWidgets(locale.languageCode, (tester) async {
        final repository = FakeOnboardingRepository();
        await pumpOnboardingPage(tester, repository, locale: locale);
        await _start(tester);
        await _next(tester, 'onboarding-basics-next');
        await typeIntoStepper(tester, 'onboarding-weight', weight);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await _next(tester, 'onboarding-body-next');
        await tester.enterText(
          find.byKey(const Key('onboarding-muscle-goal')),
          muscle,
        );
        await _next(tester, 'onboarding-goals-next');
        expect(findFigure(weight), findsOneWidget);
        expect(findFigure(muscle), findsOneWidget);
        await _next(tester, 'onboarding-summary-confirm');
        expect(repository.updates, hasLength(1));
        final sent = repository.updates.single;
        expect(sent['height'], 170.0);
        expect(sent['current_weight'], 70.5);
        expect(sent['muscle_mass_goal'], 34.5);
        expect(sent['first_name'], 'Lucía');
      });
    }
  });

  group('D14-3/8 save error inline, data kept', () {
    Future<FakeOnboardingRepository> toSummary(WidgetTester tester) async {
      final repository = FakeOnboardingRepository()..failUpdates = true;
      await pumpOnboardingPage(tester, repository);
      await _start(tester);
      await _next(tester, 'onboarding-basics-next');
      await typeIntoStepper(tester, 'onboarding-weight', '70,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await _next(tester, 'onboarding-body-next');
      await _next(tester, 'onboarding-goals-next');
      return repository;
    }

    testWidgets('the error stays above Confirm and the summary keeps data', (
      tester,
    ) async {
      await toSummary(tester);
      await _next(tester, 'onboarding-summary-confirm');
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
      expect(find.textContaining('tus datos siguen aquí'), findsOneWidget);
      expect(find.text('Lucía'), findsOneWidget);
      expect(findFigure('70,5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
    });

    testWidgets('while saving the summary stays and Confirm is busy; the '
        'error goes away when the next attempt starts', (tester) async {
      final repository = await toSummary(tester);
      await _next(tester, 'onboarding-summary-confirm');
      expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
      repository.holdUpdates = true;
      await tapKey(tester, 'onboarding-summary-confirm');
      await tester.pump();
      expect(find.byKey(const Key('onboarding-save-error')), findsNothing);
      expect(find.text('Lucía'), findsOneWidget);
      final confirm = tester.widget<ExomPrimaryButton>(
        find.byKey(const Key('onboarding-summary-confirm')),
      );
      expect(confirm.busy, isTrue);
      repository.releaseUpdate();
      await settleOnboarding(tester);
      expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
      expect(repository.updates, hasLength(2));
      expect(repository.updates.last['current_weight'], 70.5);
    });
  });
}
