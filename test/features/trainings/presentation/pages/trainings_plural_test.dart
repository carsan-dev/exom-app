// Plural of «ejercicios» / «exercises» on Entrenar: the figure column of the
// day's session and the facts line of its rows must agree with the number
// they print («1 ejercicio», «2 ejercicios»).
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trainings_redesign_fixture.dart';

TrainingEntity _training(int exercises) => TrainingEntity(
  id: 'training-$exercises',
  name: 'Sesion $exercises',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  estimatedDurationMin: 10,
  tags: const [],
  exercises: kSceneTraining.exercises.take(exercises).toList(),
);

List<String> _texts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null) t.data!,
];

void main() {
  for (final (locale, count, label, wrong) in [
    ('es', 1, 'ejercicio', 'ejercicios'),
    ('es', 2, 'ejercicios', null),
    ('en', 1, 'exercise', 'exercises'),
    ('en', 2, 'exercises', null),
  ]) {
    testWidgets('$locale with $count: figure label and row facts', (
      tester,
    ) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(today: [_training(count), _training(count)]),
        locale: Locale(locale),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final texts = _texts(tester);
      expect(
        texts,
        contains(label),
        reason: 'figure column label for $count exercise(s)',
      );
      expect(
        texts.where((t) => t.contains('$count $label')),
        isNotEmpty,
        reason: 'row facts «$count $label»',
      );
      if (wrong != null) {
        expect(
          texts.where((t) => t.contains('$count $wrong')),
          isEmpty,
          reason: 'no «$count $wrong»',
        );
        expect(texts, isNot(contains(wrong)));
      }
    });
  }
}
