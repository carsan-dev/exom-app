import 'package:exom_app/features/trainings/data/models/training_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainingModel', () {
    test('parses exercise media from camelCase response keys', () {
      final model = TrainingModel.fromJson({
        'id': 'training-1',
        'name': 'Circuito',
        'type': 'Fuerza',
        'level': 'PRINCIPIANTE',
        'tags': <String>[],
        'exercises': [
          {
            'id': 'training-exercise-1',
            'order': 1,
            'sets': 1,
            'repsOrDuration': '12',
            'restSeconds': 15,
            'blockId': 'block-1',
            'positionInBlock': 0,
            'block': {
              'name': 'Circuito 1',
              'order': 0,
              'rounds': 3,
              'restBetweenRoundsSeconds': 60,
            },
            'exercise': {
              'id': 'exercise-1',
              'name': 'Prensa',
              'muscleGroups': ['Pierna'],
              'videoUrl': 'https://cdn.example.com/prensa.mp4',
              'thumbnailUrl': 'https://cdn.example.com/prensa.jpg',
              'techniqueText': 'Pies firmes',
              'commonErrorsText': 'Bloquear rodillas',
              'explanationText': 'Empuja controlado',
            },
          },
        ],
      });

      final trainingExercise = model.exercises.single;

      expect(trainingExercise.repsOrDuration, '12');
      expect(trainingExercise.restSeconds, 15);
      expect(trainingExercise.blockId, 'block-1');
      expect(trainingExercise.positionInBlock, 0);
      expect(trainingExercise.restBetweenRoundsSeconds, 60);
      expect(trainingExercise.exercise.videoUrl, contains('prensa.mp4'));
      expect(trainingExercise.exercise.thumbnailUrl, contains('prensa.jpg'));
      expect(trainingExercise.exercise.techniqueText, 'Pies firmes');
      expect(trainingExercise.exercise.commonErrorsText, 'Bloquear rodillas');
      expect(trainingExercise.exercise.explanationText, 'Empuja controlado');
    });
  });
}
