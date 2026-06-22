import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _assignment(String id, String date) => {
  'date': date,
  'training': {
    'id': id,
    'name': 'Entrenamiento $id',
    'level': 'INTERMEDIO',
  },
};

void main() {
  group('buildTrainingHistory', () {
    final today = DateTime(2026, 6, 23, 18, 30);

    test('includes completed and incomplete past assignments', () {
      final history = buildTrainingHistory(
        [
          _assignment('older', '2026-06-20'),
          _assignment('completed', '2026-06-22'),
        ],
        [
          {'date': '2026-06-22', 'training_completed': true},
        ],
        today: today,
      );

      expect(history.map((entry) => entry.id), ['completed', 'older']);
      expect(history.first.isCompleted, isTrue);
      expect(history.last.isCompleted, isFalse);
    });

    test('excludes today and future assignments', () {
      final history = buildTrainingHistory(
        [
          _assignment('past', '2026-06-22'),
          _assignment('today', '2026-06-23'),
          _assignment('future', '2026-06-30'),
        ],
        const [],
        today: today,
      );

      expect(history.map((entry) => entry.id), ['past']);
    });

    test('keeps assignments from previous months', () {
      final history = buildTrainingHistory(
        [_assignment('previous-month', '2026-05-31')],
        const [],
        today: today,
      );

      expect(history.single.id, 'previous-month');
    });

    test('ignores malformed assignment dates', () {
      final history = buildTrainingHistory(
        [_assignment('invalid', 'not-a-date')],
        const [],
        today: today,
      );

      expect(history, isEmpty);
    });
  });
}
