import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/recap/data/models/recap_model.dart';

void main() {
  test('preserves recap anatomy ids and legacy zones in create payload', () {
    final payload = RecapModel.toCreateJson({
      'sleep_hours_range': 'ENTRE_6_7',
      'muscle_pain_zones': ['quadriceps_left', 'lower_back', 'thigh'],
      'improvement_areas': <String>[],
    });

    expect(payload['muscle_pain_zones'], [
      'quadriceps_left',
      'lower_back',
      'thigh',
    ]);
  });

  test('parses recap anatomy ids from detail payload', () {
    final model = RecapModel.fromJson({
      'id': 'recap-1',
      'week_start_date': '2026-05-18T00:00:00.000Z',
      'week_end_date': '2026-05-24T00:00:00.000Z',
      'status': 'DRAFT',
      'muscle_pain_zones': ['calves_right', 'calf'],
      'created_at': '2026-05-24T10:00:00.000Z',
    });

    expect(model.musclePainZones, ['calves_right', 'calf']);
  });
}
