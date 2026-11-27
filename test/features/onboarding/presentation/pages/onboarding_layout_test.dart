// L5-D2 · Onboarding layout (contract CC 3): every step at 320 and 360 dp
// with text at 1.0, 1.3 and 1.6 (Android 14+ nonlinear scaler), in es and en,
// without overflow; at 2.0 the main scene («Tu cuerpo») stays reachable by
// scrolling; with the keyboard open the step action stays above it.
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow;
import '../onboarding_test_support.dart';

/// A profile with every field, the longest values of the summary.
FakeOnboardingRepository _fullProfile() => FakeOnboardingRepository(
  profile: ProfileEntity(
    id: 'synthetic',
    firstName: 'Maximiliana',
    lastName: 'Fernández-Villaverde',
    birthDate: DateTime(1994, 3, 14),
    heightCm: 168.5,
    currentWeightKg: 68.45,
    level: 'INTERMEDIO',
    goal: 'Ganar músculo y mejorar la condición física general',
    muscleMassGoalKg: 34.5,
    targetCalories: 2100,
  ),
);

const _actionOf = {
  0: 'onboarding-start',
  1: 'onboarding-basics-next',
  2: 'onboarding-body-next',
  3: 'onboarding-goals-next',
  4: 'onboarding-summary-confirm',
};

Future<void> _show(WidgetTester tester, OnboardingBloc bloc, int step) async {
  bloc.add(OnboardingStepSelected(step));
  await settleOnboarding(tester);
  expect(find.byKey(Key(_actionOf[step]!)), findsOneWidget);
}

void main() {
  const sizes = [(320.0, 640.0), (360.0, 740.0)];
  const scales = [1.0, 1.3, 1.6];
  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final (width, height) in sizes) {
      for (final scale in scales) {
        testWidgets(
          '${locale.languageCode} ${width.toInt()}dp x$scale: no overflow',
          (tester) async {
            final bloc = await pumpOnboardingPage(
              tester,
              _fullProfile(),
              locale: locale,
              width: width,
              height: height,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            for (final step in const [0, 1, 2, 3, 4]) {
              await _show(tester, bloc, step);
              expectNoOverflow(tester);
            }
          },
        );
      }
    }
  }

  testWidgets('2.0x at 360dp: «Tu cuerpo» is reachable by scrolling', (
    tester,
  ) async {
    final bloc = await pumpOnboardingPage(
      tester,
      _fullProfile(),
      width: 360,
      height: 740,
      textScaler: const AndroidNonlinearTextScaler(2.0),
    );
    await _show(tester, bloc, 2);
    expectNoOverflow(tester);
    final hint = find.textContaining('Toca la cifra');
    await tester.ensureVisible(hint);
    await tester.pump();
    expect(tester.getRect(hint).bottom, lessThanOrEqualTo(740));
    await tester.ensureVisible(find.byKey(const Key('onboarding-weight')));
    await tester.pump();
    expectNoOverflow(tester);
  });

  for (final step in const [1, 2, 3]) {
    testWidgets('step $step: the action stays above the keyboard', (
      tester,
    ) async {
      const height = 740.0;
      const keyboard = 300.0;
      final bloc = await pumpOnboardingPage(
        tester,
        _fullProfile(),
        width: 360,
        height: height,
        textScaler: const AndroidNonlinearTextScaler(1.6),
        keyboardInset: keyboard,
      );
      await _show(tester, bloc, step);
      expectNoOverflow(tester);
      final action = tester.getRect(find.byKey(Key(_actionOf[step]!)));
      expect(action.bottom, lessThanOrEqualTo(height - keyboard));
      expect(action.top, greaterThanOrEqualTo(0));
    });
  }

  testWidgets('typing a weight keeps the field above the keyboard', (
    tester,
  ) async {
    const height = 740.0;
    const keyboard = 300.0;
    final bloc = await pumpOnboardingPage(
      tester,
      _fullProfile(),
      width: 360,
      height: height,
      keyboardInset: keyboard,
    );
    await _show(tester, bloc, 2);
    await typeIntoStepper(tester, 'onboarding-weight', '70,5');
    await tester.pump(const Duration(milliseconds: 300));
    final field = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('onboarding-weight')),
        matching: find.byKey(ExomNumeralStepper.fieldKey),
      ),
    );
    expect(field.bottom, lessThanOrEqualTo(height - keyboard));
    final action = tester.getRect(
      find.byKey(const Key('onboarding-body-next')),
    );
    expect(action.bottom, lessThanOrEqualTo(height - keyboard));
    expectNoOverflow(tester);
  });
}
