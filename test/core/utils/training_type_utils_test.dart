import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';

void main() {
  group('training_type_utils', () {
    test('normalizes spaces in training labels', () {
      expect(
        normalizeTrainingTypeLabel('  full   body   fuerza  '),
        'full body fuerza',
      );
    });

    test('builds stable key without accents', () {
      expect(trainingTypeKey('  Tirón  '), 'tiron');
      expect(trainingTypeKey('Pierná'), 'pierna');
      expect(trainingTypeKey('Full Body'), 'full body');
    });
  });
}
