import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/recap/data/models/recap_model.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

void main() {
  test('preserves recap anatomy ids and legacy zones in create payload', () {
    final payload = RecapModel.toCreateJson({
      'average_daily_steps': 8500,
      'sleep_hours_range': 'ENTRE_6_7',
      'muscle_pain_zones': ['quadriceps_left', 'lower_back', 'thigh'],
      'improvement_areas': <String>[],
    });

    expect(payload['muscle_pain_zones'], [
      'quadriceps_left',
      'lower_back',
      'thigh',
    ]);
    expect(payload['average_daily_steps'], 8500);
  });

  test('parses recap anatomy ids from detail payload', () {
    final model = RecapModel.fromJson({
      'id': 'recap-1',
      'week_start_date': '2026-05-18T00:00:00.000Z',
      'week_end_date': '2026-05-24T00:00:00.000Z',
      'status': 'DRAFT',
      'average_daily_steps': 12345,
      'muscle_pain_zones': ['calves_right', 'calf'],
      'created_at': '2026-05-24T10:00:00.000Z',
    });

    expect(model.musclePainZones, ['calves_right', 'calf']);
    expect(model.averageDailySteps, 12345);
  });

  test(
    'preserves null average daily steps so a saved value can be cleared',
    () {
      final payload = RecapModel.toUpdateJson({
        'average_daily_steps': null,
        'muscle_pain_zones': <String>[],
        'improvement_areas': <String>[],
      });

      expect(payload, containsPair('average_daily_steps', null));
    },
  );

  test('create omits nulls while update preserves explicit clears', () {
    final formData = {
      'average_daily_steps': null,
      'training_notes': '',
      'hydration_enabled': false,
      'hydration_level': 'ALTA',
      'stress_enabled': false,
      'stress_level': 4,
    };

    expect(
      RecapModel.toCreateJson(formData),
      isNot(contains('average_daily_steps')),
    );

    final update = RecapModel.toUpdateJson(formData);
    expect(update, containsPair('average_daily_steps', null));
    expect(update, containsPair('training_notes', null));
    expect(update, containsPair('hydration_level', null));
    expect(update, containsPair('stress_level', null));
  });

  test('validates the shared average daily steps range', () {
    expect(isValidRecapAverageDailySteps(null), isTrue);
    expect(isValidRecapAverageDailySteps(0), isTrue);
    expect(isValidRecapAverageDailySteps(recapAverageDailyStepsMax), isTrue);
    expect(isValidRecapAverageDailySteps(-1), isFalse);
    expect(
      isValidRecapAverageDailySteps(recapAverageDailyStepsMax + 1),
      isFalse,
    );
    expect(isValidRecapAverageDailySteps('8500'), isFalse);
  });
}
