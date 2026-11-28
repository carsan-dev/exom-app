// L5-D2 · Onboarding, round 4 (O3): the labels of the fields wrap onto several
// lines in every step; none is cut with an ellipsis («Meta de masa mu…»,
// «Calorías objetivo (opcion…» seen at 411 dp and 1.0x on the emulator).
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../onboarding_test_support.dart';

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

/// Painted texts of the screen that were cut with an ellipsis.
List<String> _ellipsized(WidgetTester tester) => [
  for (final element in find.byType(RichText).evaluate())
    if ((element.renderObject! as RenderParagraph).didExceedMaxLines &&
        (element.renderObject! as RenderParagraph).overflow ==
            TextOverflow.ellipsis)
      (element.renderObject! as RenderParagraph).text.toPlainText(),
];

void main() {
  const sizes = [(320.0, 640.0), (360.0, 740.0), (411.0, 800.0)];
  const scales = [1.0, 1.3, 1.6];
  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final (width, height) in sizes) {
      for (final scale in scales) {
        testWidgets(
          '${locale.languageCode} ${width.toInt()}dp x$scale: no label is '
          'cut with an ellipsis',
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
              bloc.add(OnboardingStepSelected(step));
              await settleOnboarding(tester);
              expect(_ellipsized(tester), isEmpty, reason: 'step $step');
              expect(tester.takeException(), isNull, reason: 'step $step');
            }
          },
        );
      }
    }
  }
}
