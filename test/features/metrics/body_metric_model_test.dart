import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/metrics/data/models/body_metric_model.dart';

void main() {
  test('parses height and muscle mass from metrics payload', () {
    final model = BodyMetricModel.fromJson({
      'id': 'metric-1',
      'date': '2026-03-24T10:00:00.000Z',
      'weight_kg': 80.5,
      'height_cm': 182,
      'muscle_mass_kg': 34.2,
    });

    expect(model.id, 'metric-1');
    expect(model.weightKg, 80.5);
    expect(model.heightCm, 182);
    expect(model.muscleMassKg, 34.2);
  });
}
