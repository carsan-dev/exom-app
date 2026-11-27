// Redesign L5-D2 golden (docs/plans/rediseno-app-l5-contrato-v2.md, L5-D2 and
// section 5.3): the main scene «Tu cuerpo» (height and weight steppers) and
// the summary, in dark and light at text scale 1.0 and 1.6 on a 390x844
// surface, without animation, with contrast and tap-target guidelines.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_d2_onboarding_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../core/widgets/expect_no_lime_ink.dart';
import '../features/onboarding/presentation/onboarding_test_support.dart';

FakeOnboardingRepository _profile() => FakeOnboardingRepository(
  profile: ProfileEntity(
    id: 'synthetic',
    firstName: 'Lucía',
    lastName: 'Martín',
    birthDate: DateTime(1994, 3, 14),
    heightCm: 168,
    currentWeightKg: 68.4,
    level: 'INTERMEDIO',
    goal: 'Ganar músculo',
    targetCalories: 2100,
  ),
);

void main() {
  const scenes = {2: 'cuerpo', 4: 'resumen'};
  for (final MapEntry(key: step, value: scene) in scenes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        final name =
            'onboarding_${scene}_${brightness.name}_'
            '${scale == 1.0 ? '1_0x' : '1_6x'}';
        testWidgets('golden $name', (tester) async {
          final bloc = await pumpOnboardingPage(
            tester,
            _profile(),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
          );
          bloc.add(OnboardingStepSelected(step));
          await settleOnboarding(tester);
          expectNoOverflow(tester);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          await expectTapTargetGuidelines(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
