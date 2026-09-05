import 'package:exom_app/features/trainings/data/models/training_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
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
        'assignment_training_id': 'assignment-training-1',
        'assignment_date': '2026-09-01',
        'requires_last_set_video': true,
        'exercises': [
          {
            'id': 'training-exercise-1',
            'order': 1,
            'sets': 1,
            'repsOrDuration': '12',
            'measureType': 'SECONDS',
            'targetValue': 45,
            'targetRir': 2,
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
      expect(trainingExercise.measureType, ExerciseMeasureType.seconds);
      expect(trainingExercise.targetValue, 45);
      expect(trainingExercise.targetRir, 2);
      expect(trainingExercise.restSeconds, 15);
      expect(trainingExercise.blockId, 'block-1');
      expect(trainingExercise.positionInBlock, 0);
      expect(trainingExercise.restBetweenRoundsSeconds, 60);
      expect(trainingExercise.exercise.videoUrl, contains('prensa.mp4'));
      expect(trainingExercise.exercise.thumbnailUrl, contains('prensa.jpg'));
      expect(trainingExercise.exercise.techniqueText, 'Pies firmes');
      expect(trainingExercise.exercise.commonErrorsText, 'Bloquear rodillas');
      expect(trainingExercise.exercise.explanationText, 'Empuja controlado');
      expect(model.assignmentTrainingId, 'assignment-training-1');
      expect(model.assignmentDate, '2026-09-01');
      expect(model.requiresLastSetVideo, isTrue);
    });

    test('parses structured target ranges from API response keys', () {
      final exercise = TrainingExerciseModel.fromJson({
        'id': 'training-exercise-range',
        'order': 0,
        'sets': 3,
        'reps_or_duration': '8-10',
        'measure_type': 'REPS',
        'target_value': null,
        'target_value_min': 8,
        'target_value_max': 10,
        'rest_seconds': 60,
        'exercise': {'id': 'exercise-1', 'name': 'Sentadilla'},
      });

      expect(exercise.measureType, ExerciseMeasureType.reps);
      expect(exercise.targetValue, isNull);
      expect(exercise.targetValueMin, 8);
      expect(exercise.targetValueMax, 10);
      expect(exercise.repsOrDuration, '8-10');
    });
  });
}
