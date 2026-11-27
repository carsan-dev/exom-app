// A counted unit never prints a number followed by a fixed plural word: with 1
// it reads «1 serie» / «1 set», with several «4 series» / «4 sets». Covers the
// series counts of Entrenar and the detail (metadata line, session progress
// summary, the «series hechas» caption and the close-exercise dialog).
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('exerciseMetadata', () {
    test('es', () {
      expect(es.exerciseMetadata(1, '8 reps', 60), '1 serie x 8 reps · Descanso 60s');
      expect(es.exerciseMetadata(4, '8 reps', 60), '4 series x 8 reps · Descanso 60s');
    });
    test('en', () {
      expect(en.exerciseMetadata(1, '8 reps', 60), '1 set x 8 reps · Rest 60s');
      expect(en.exerciseMetadata(4, '8 reps', 60), '4 sets x 8 reps · Rest 60s');
    });
  });

  group('calendarWeekTrainings', () {
    test('es', () {
      expect(es.calendarWeekTrainings('1', 1), '1 de 1 entreno esta semana');
      expect(es.calendarWeekTrainings('2', 3), '2 de 3 entrenos esta semana');
      expect(es.calendarWeekTrainings('0', 0), '0 de 0 entrenos esta semana');
    });
    test('en', () {
      expect(en.calendarWeekTrainings('1', 1), '1 of 1 workout this week');
      expect(en.calendarWeekTrainings('2', 3), '2 of 3 workouts this week');
    });
  });

  group('trainingExecutionLabel', () {
    test('es', () => expect(es.trainingExecutionLabel(2), 'Sesión 2'));
    test('en', () => expect(en.trainingExecutionLabel(2), 'Session 2'));
  });

  group('activeExerciseCloseMessage', () {
    test('es', () {
      expect(
        es.activeExerciseCloseMessage(0, 1),
        'Has completado 0 de 1 serie. Podrás retomarlo después.',
      );
      expect(
        es.activeExerciseCloseMessage(1, 4),
        'Has completado 1 de 4 series. Podrás retomarlo después.',
      );
    });
    test('en', () {
      expect(
        en.activeExerciseCloseMessage(0, 1),
        'You have completed 0 of 1 set. You can resume later.',
      );
      expect(
        en.activeExerciseCloseMessage(1, 4),
        'You have completed 1 of 4 sets. You can resume later.',
      );
    });
  });

  group('trainingDetailProgressSemantics', () {
    test('es', () {
      expect(
        es.trainingDetailProgressSemantics(0, 1, 0, 1),
        '0 de 1 ejercicio hecho, 0 de 1 serie hecha',
      );
      expect(
        es.trainingDetailProgressSemantics(1, 5, 4, 16),
        '1 de 5 ejercicios hechos, 4 de 16 series hechas',
      );
    });
    test('en', () {
      expect(
        en.trainingDetailProgressSemantics(0, 1, 0, 1),
        '0 of 1 exercise done, 0 of 1 set done',
      );
      expect(
        en.trainingDetailProgressSemantics(1, 5, 4, 16),
        '1 of 5 exercises done, 4 of 16 sets done',
      );
    });
  });

  group('trainingDetailSetsDoneLabel', () {
    test('es', () {
      expect(es.trainingDetailSetsDoneLabel(1), 'serie hecha');
      expect(es.trainingDetailSetsDoneLabel(16), 'series hechas');
    });
    test('en', () {
      expect(en.trainingDetailSetsDoneLabel(1), 'set done');
      expect(en.trainingDetailSetsDoneLabel(16), 'sets done');
    });
  });

  group('homeFigureSets (figure captions of Entrenar, detail and milestone)', () {
    test('es', () {
      expect(es.homeFigureSets(1), 'serie');
      expect(es.homeFigureSets(4), 'series');
    });
    test('en', () {
      expect(en.homeFigureSets(1), 'set');
      expect(en.homeFigureSets(4), 'sets');
    });
  });
}
