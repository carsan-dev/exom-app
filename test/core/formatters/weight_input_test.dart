import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decimalSeparatorFor', () {
    test('Spanish uses a comma, English and unknown codes a point', () {
      expect(decimalSeparatorFor('es'), ',');
      expect(decimalSeparatorFor('en'), '.');
      expect(decimalSeparatorFor('fr'), '.');
    });
  });

  group('formatWeightDisplay', () {
    test('metric keeps up to two decimals and trims trailing zeros', () {
      expect(formatWeightDisplay(62.5, UnitSystem.metric, decimalSeparator: ','),
          '62,5');
      expect(
          formatWeightDisplay(62.25, UnitSystem.metric, decimalSeparator: ','),
          '62,25');
      expect(formatWeightDisplay(60, UnitSystem.metric, decimalSeparator: ','),
          '60');
      expect(formatWeightDisplay(62.5, UnitSystem.metric, decimalSeparator: '.'),
          '62.5');
      expect(formatWeightDisplay(0, UnitSystem.metric, decimalSeparator: ','),
          '0');
    });

    test('metric rounds to two decimals, half away from zero', () {
      expect(
          formatWeightDisplay(62.125, UnitSystem.metric, decimalSeparator: '.'),
          '62.13');
      expect(
          formatWeightDisplay(61.23496474, UnitSystem.metric,
              decimalSeparator: '.'),
          '61.23');
      expect(
          formatWeightDisplay(0.004, UnitSystem.metric, decimalSeparator: '.'),
          '0');
    });

    test('imperial converts kg to lb', () {
      expect(
          formatWeightDisplay(62.5, UnitSystem.imperial, decimalSeparator: ','),
          '137,79');
      expect(
          formatWeightDisplay(60, UnitSystem.imperial, decimalSeparator: '.'),
          '132.28');
    });

    test('a non-finite value is no value: empty text, no throw', () {
      // L3 review B-F8: NaN used to throw from round().
      for (final unit in UnitSystem.values) {
        for (final value in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          expect(formatWeightDisplay(value, unit, decimalSeparator: ','), '');
        }
      }
      expect(formatDisplayDecimal(double.nan, decimalSeparator: '.'), '');
    });

    test('never groups thousands', () {
      expect(
          formatWeightDisplay(500, UnitSystem.imperial, decimalSeparator: ','),
          '1102,31');
      expect(formatWeightDisplay(1250, UnitSystem.metric, decimalSeparator: ','),
          '1250');
    });
  });

  group('conversion', () {
    test('metric is the identity in both directions', () {
      expect(kgToDisplay(62.25, UnitSystem.metric), 62.25);
      expect(displayToKg(62.25, UnitSystem.metric), 62.25);
    });

    test('imperial display value converts to kg rounded to 3 decimals', () {
      expect(displayToKg(135, UnitSystem.imperial), 61.235);
      expect(displayToKg(0, UnitSystem.imperial), 0);
      expect(kgToDisplay(61.235, UnitSystem.imperial), closeTo(135.0, 0.005));
    });

    test('imperial round trip reproduces every typed lb value at 2 decimals',
        () {
      // 0.00 .. 1102.31 lb in 0.01 steps, compared in integer hundredths.
      for (var hundredths = 0; hundredths <= 110231; hundredths++) {
        final lb = hundredths / 100;
        final kg = displayToKg(lb, UnitSystem.imperial);
        final back = (kgToDisplay(kg, UnitSystem.imperial) * 100).round();
        if (back != hundredths) {
          fail('$lb lb -> $kg kg -> ${back / 100} lb');
        }
      }
    });

    test('sampled imperial values survive format(displayToKg(x))', () {
      for (final lb in const [135.0, 135.5, 46.25, 1102.31, 0.01, 2.5]) {
        final kg = displayToKg(lb, UnitSystem.imperial);
        expect(
          formatWeightDisplay(kg, UnitSystem.imperial, decimalSeparator: '.'),
          formatWeightDisplay(lb, UnitSystem.metric, decimalSeparator: '.'),
          reason: '$lb lb',
        );
      }
    });

    test('metric values with up to two decimals are stored exactly', () {
      for (final value in const [62.25, 0.5, 1.25, 499.99, 500.0]) {
        expect(displayToKg(value, UnitSystem.metric), value);
        expect(
          formatWeightDisplay(displayToKg(value, UnitSystem.metric),
              UnitSystem.metric,
              decimalSeparator: '.'),
          value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''),
        );
      }
    });
  });

  group('steps and bounds', () {
    test('step is 2.5 kg or 5 lb', () {
      expect(weightStep(UnitSystem.metric), 2.5);
      expect(weightStep(UnitSystem.imperial), 5);
    });

    test('max is 500 kg, floored to 1102.31 lb', () {
      expect(maxWeightDisplay(UnitSystem.metric), 500);
      expect(maxWeightDisplay(UnitSystem.imperial), 1102.31);
      expect(displayToKg(maxWeightDisplay(UnitSystem.imperial),
          UnitSystem.imperial), lessThanOrEqualTo(500));
    });
  });

  // L3 unit 3: ± of the set sheet work in the display unit.
  group('formatDisplayDecimal', () {
    test('formats without converting', () {
      expect(formatDisplayDecimal(142.79, decimalSeparator: ','), '142,79');
      expect(formatDisplayDecimal(65, decimalSeparator: ','), '65');
      expect(formatDisplayDecimal(62.5, decimalSeparator: '.'), '62.5');
      expect(formatDisplayDecimal(1102.31, decimalSeparator: ','), '1102,31');
    });
  });
}
