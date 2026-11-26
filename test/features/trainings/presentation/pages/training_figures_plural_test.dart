// Plural of the «series» figure caption («1 serie», «4 series») on the three
// places that print the planned sets of a session as a figure: Entrenar (the
// day's session), the session detail header and the «Sesión hecha» milestone.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_milestone_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trainings_redesign_fixture.dart';

TrainingEntity _trainingWithSets(int sets) => TrainingEntity(
  id: 'training-sets-$sets',
  name: 'Sesion $sets',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  estimatedDurationMin: 10,
  tags: const [],
  exercises: [
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: sets,
      repsOrDuration: '8',
      restSeconds: 60,
      exercise: const ExerciseEntity(
        id: 'ex-1',
        name: 'Sentadilla',
        muscleGroups: [],
      ),
    ),
  ],
);

List<String> _texts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null) t.data!,
];

const _cases = [
  ('es', 1, 'serie', 'series'),
  ('es', 4, 'series', null),
  ('en', 1, 'set', 'sets'),
  ('en', 4, 'sets', null),
];

void main() {
  for (final (locale, sets, label, wrong) in _cases) {
    testWidgets('Entrenar $locale with $sets set(s): figure caption', (
      tester,
    ) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(today: [_trainingWithSets(sets)]),
        locale: Locale(locale),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final texts = _texts(tester);
      expect(texts, contains(label));
      if (wrong != null) expect(texts, isNot(contains(wrong)));
    });

    testWidgets('milestone $locale with $sets set(s): figure caption', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: TrainingMilestonePage(
              trainingName: 'Pierna fuerza',
              exercises: 1,
              sets: sets,
              isSameSession: () => true,
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final texts = _texts(tester);
      expect(texts, contains(label));
      if (wrong != null) expect(texts, isNot(contains(wrong)));
    });
  }
}
