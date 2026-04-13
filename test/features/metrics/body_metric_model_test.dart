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

  test('parses bilateral measurements from the latest payload contract', () {
    final model = BodyMetricModel.fromJson({
      'id': 'metric-2',
      'date': '2026-03-24T10:00:00.000Z',
      'arm_left_cm': 33,
      'arm_right_cm': 34,
      'forearm_left_cm': 28,
      'forearm_right_cm': 28.5,
      'thigh_left_cm': 57,
      'thigh_right_cm': 57.5,
      'calf_left_cm': 38,
      'calf_right_cm': 38.5,
    });

    expect(model.armLeftCm, 33);
    expect(model.armRightCm, 34);
    expect(model.forearmLeftCm, 28);
    expect(model.forearmRightCm, 28.5);
    expect(model.thighLeftCm, 57);
    expect(model.thighRightCm, 57.5);
    expect(model.calfLeftCm, 38);
    expect(model.calfRightCm, 38.5);
  });

  test('falls back to legacy single-side cache keys', () {
    final model = BodyMetricModel.fromJson({
      'id': 'metric-3',
      'date': '2026-03-24T10:00:00.000Z',
      'arm_cm': 34,
      'forearm_cm': 29,
      'thigh_cm': 58,
      'calf_cm': 39,
    });

    expect(model.armLeftCm, 34);
    expect(model.armRightCm, 34);
    expect(model.forearmLeftCm, 29);
    expect(model.forearmRightCm, 29);
    expect(model.thighLeftCm, 58);
    expect(model.thighRightCm, 58);
    expect(model.calfLeftCm, 39);
    expect(model.calfRightCm, 39);
  });
}
