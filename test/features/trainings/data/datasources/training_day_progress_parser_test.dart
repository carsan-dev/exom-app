import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses client note and trainer reply with exercise progress', () {
    final progress = parseTrainingDayProgress({
      'notes': 'Me molestó la rodilla',
      'admin_reply_text': 'Reduce el peso',
      'admin_reply_sent_at': '2026-06-29T12:00:00.000Z',
      'exercises_completed': [
        {
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'weight_used': 20,
          'sets': [
            {'set_number': 1, 'reps': 12, 'weight_kg': 20, 'rir': 0},
          ],
        },
      ],
    });

    expect(progress.ids, {'training-exercise-1'});
    expect(progress.weights, {'training-exercise-1': 20});
    expect(progress.performances['training-exercise-1']?.single.reps, 12);
    expect(progress.performances['training-exercise-1']?.single.rir, 0);
    expect(progress.note, 'Me molestó la rodilla');
    expect(progress.adminReplyText, 'Reduce el peso');
    expect(
      progress.adminReplySentAt,
      DateTime.parse('2026-06-29T12:00:00.000Z'),
    );
  });
}
