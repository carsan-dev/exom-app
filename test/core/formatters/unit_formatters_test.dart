import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';

void main() {
  group('UnitConverters', () {
    test('converts kilograms to pounds and back', () {
      final pounds = UnitConverters.kgToLb(75);

      expect(pounds, closeTo(165.35, 0.01));
      expect(UnitConverters.lbToKg(pounds), closeTo(75, 0.001));
    });

    test('converts centimeters to inches and back', () {
      final inches = UnitConverters.cmToIn(180);

      expect(inches, closeTo(70.87, 0.01));
      expect(UnitConverters.inToCm(inches), closeTo(180, 0.001));
    });
  });

  group('UnitFormatters', () {
    test('formats metric weight and length', () {
      expect(formatWeight(75, UnitSystem.metric), '75.0 kg');
      expect(formatLength(180, UnitSystem.metric), '180.0 cm');
    });

    test('formats imperial weight and length', () {
      expect(formatWeight(75, UnitSystem.imperial), '165.3 lb');
      expect(formatLength(180, UnitSystem.imperial), '70.9 in');
    });
  });
}
