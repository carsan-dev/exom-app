// L4-I6 / L5-D5: static check. The visible figures of the diets and
// challenges pages must be formatted with the active locale (contract 5.4),
// never with toStringAsFixed. Every toStringAsFixed in these two files was in
// scope, so the files must not contain it at all. L5-D2 adds the onboarding
// steps that show numbers (L4-I19).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    'lib/features/diets/presentation/pages/diets_page.dart',
    'lib/features/challenges/presentation/pages/challenges_page.dart',
    // L5-D2 · Onboarding (L4-I19): fields, control labels and summary.
    'lib/features/onboarding/presentation/widgets/onboarding_body_step.dart',
    'lib/features/onboarding/presentation/widgets/onboarding_goals_step.dart',
    'lib/features/onboarding/presentation/widgets/onboarding_summary_step.dart',
  ];

  for (final path in files) {
    test('$path formats figures with the locale, not toStringAsFixed', () {
      final lines = File(path).readAsLinesSync();
      final offenders = [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].contains('toStringAsFixed('))
            '${i + 1}: ${lines[i].trim()}',
      ];
      expect(offenders, isEmpty);
    });
  }
}
