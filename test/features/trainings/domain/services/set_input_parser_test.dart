import 'package:exom_app/features/trainings/domain/services/set_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Decision D3 (owner, 2026-11-18): invalid or ambiguous input keeps the typed
// text and shows a field error; «62,5» and «62.5» are accepted and normalised.
// Upper bounds: 500 kg (1102.31 lb), 999 reps, 6 hours.

Matcher _valid(num value) => isA<ParsedValue<num>>().having(
  (parsed) => parsed.value,
  'value',
  value,
);

Matcher _invalid(SetInputError error) => isA<ParsedInvalid<num>>().having(
  (parsed) => parsed.error,
  'error',
  error,
);

final Matcher _empty = isA<ParsedEmpty<num>>();

void main() {
  group('parseWeight (kg, max 500)', () {
    ParsedInput<double> kg(String raw) =>
        parseWeight(raw, max: 500, unitSymbol: 'kg');

    test('accepts the comma and the point as decimal separator', () {
      expect(kg('62,5'), _valid(62.5));
      expect(kg('62.5'), _valid(62.5));
      expect(kg('62,25'), _valid(62.25));
      expect(kg('62'), _valid(62));
      expect(kg('0'), _valid(0));
      expect(kg('500'), _valid(500));
    });

    test('normalises surrounding spaces and a trailing unit', () {
      expect(kg(' 62,5 '), _valid(62.5));
      expect(kg(' 62,5 '), _valid(62.5));
      expect(kg(' 62,5 kg '), _valid(62.5));
      expect(kg('62.5KG'), _valid(62.5));
    });

    test('parses to the same double as the pre-L3 parser', () {
      // Old sheet: double.tryParse(text.replaceAll(',', '.')).
      for (final raw in ['62,5', '62.5', '60', '12.25', '0,5']) {
        final parsed = kg(raw) as ParsedValue<double>;
        expect(parsed.value, double.parse(raw.replaceAll(',', '.')));
      }
    });

    test('empty text is empty, not zero', () {
      expect(kg(''), _empty);
      expect(kg('   '), _empty);
    });

    test('rejects what it cannot read without guessing', () {
      expect(kg('62,5,5'), _invalid(SetInputError.notANumber));
      expect(kg('abc'), _invalid(SetInputError.notANumber));
      expect(kg('6x'), _invalid(SetInputError.notANumber));
      expect(kg('.5'), _invalid(SetInputError.notANumber));
      expect(kg('5.'), _invalid(SetInputError.notANumber));
      expect(kg('+5'), _invalid(SetInputError.notANumber));
      expect(kg('6 2'), _invalid(SetInputError.notANumber));
      expect(kg('1.250,5'), _invalid(SetInputError.notANumber));
      expect(kg('62 lb'), _invalid(SetInputError.notANumber));
    });

    test('rejects a thousands-like separator as ambiguous', () {
      expect(kg('1.250'), _invalid(SetInputError.ambiguous));
      expect(kg('1,250'), _invalid(SetInputError.ambiguous));
      expect(kg('62.125'), _invalid(SetInputError.ambiguous));
    });

    test('rejects more than two decimals', () {
      expect(kg('62.1234'), _invalid(SetInputError.tooManyDecimals));
      expect(kg('1250,125'), _invalid(SetInputError.tooManyDecimals));
    });

    test('rejects negative values and values above the maximum', () {
      expect(kg('-5'), _invalid(SetInputError.negative));
      expect(kg('-0,5'), _invalid(SetInputError.negative));
      expect(kg('500,01'), _invalid(SetInputError.aboveMax));
      expect(kg('1000'), _invalid(SetInputError.aboveMax));
    });
  });

  group('parseWeight (lb, max 1102.31)', () {
    ParsedInput<double> lb(String raw) =>
        parseWeight(raw, max: 1102.31, unitSymbol: 'lb');

    test('accepts both separators and the lb suffix', () {
      expect(lb('135'), _valid(135));
      expect(lb('135 lb'), _valid(135));
      expect(lb('137,79'), _valid(137.79));
      expect(lb('137.79'), _valid(137.79));
      expect(lb('1102,31'), _valid(1102.31));
    });

    test('rejects above the lb maximum and a kg suffix', () {
      expect(lb('1102,32'), _invalid(SetInputError.aboveMax));
      expect(lb('62 kg'), _invalid(SetInputError.notANumber));
      expect(lb('1.102'), _invalid(SetInputError.ambiguous));
    });
  });

  group('parseCount', () {
    ParsedInput<int> reps(String raw) => parseCount(raw, max: 999);

    test('accepts whole numbers within bounds', () {
      expect(reps('8'), _valid(8));
      expect(reps(' 12 '), _valid(12));
      expect(reps('999'), _valid(999));
      expect(reps(''), _empty);
    });

    test('rejects zero, decimals, negatives, ambiguity and junk', () {
      expect(reps('0'), _invalid(SetInputError.belowMin));
      expect(reps('8.5'), _invalid(SetInputError.notInteger));
      expect(reps('8,5'), _invalid(SetInputError.notInteger));
      expect(reps('1.250'), _invalid(SetInputError.ambiguous));
      expect(reps('-3'), _invalid(SetInputError.negative));
      expect(reps('abc'), _invalid(SetInputError.notANumber));
      expect(reps('8x'), _invalid(SetInputError.notANumber));
      expect(reps('1000'), _invalid(SetInputError.aboveMax));
      expect(reps('99999999999999999999'), _invalid(SetInputError.aboveMax));
    });

    test('seconds accept up to 6 hours and a trailing s', () {
      expect(parseCount('21600', max: 21600, unitSymbol: 's'), _valid(21600));
      expect(parseCount('45 s', max: 21600, unitSymbol: 's'), _valid(45));
      expect(
        parseCount('21601', max: 21600, unitSymbol: 's'),
        _invalid(SetInputError.aboveMax),
      );
      expect(parseCount('360', max: 360, unitSymbol: 'min'), _valid(360));
    });
  });

  group('validateSetForm', () {
    const empty = ParsedEmpty<int>();
    const emptyWeight = ParsedEmpty<double>();

    test('valid reps, weight and RIR', () {
      final result = validateSetForm(
        count: const ParsedValue(8),
        weight: const ParsedValue(62.5),
        countRequired: true,
      );
      expect(result.isValid, isTrue);
      expect(result.count, 8);
      expect(result.weight, 62.5);
    });

    test('mandatory tracking requires the count', () {
      final result = validateSetForm(
        count: empty,
        weight: const ParsedValue(62.5),
        countRequired: true,
      );
      expect(result.isValid, isFalse);
      expect(result.countError, SetFormError.countRequired);
      expect(result.weightError, isNull);
    });

    test('optional tracking with everything empty is not a set', () {
      final result = validateSetForm(
        count: empty,
        weight: emptyWeight,
        countRequired: false,
      );
      expect(result.isValid, isFalse);
      expect(result.countError, SetFormError.noData);
    });

    test('RIR alone is never a set (the API rejects it with 400)', () {
      // validateSetForm does not even take the RIR: a set needs reps,
      // seconds or weight whatever the RIR is.
      final result = validateSetForm(
        count: empty,
        weight: emptyWeight,
        countRequired: false,
      );
      expect(result.isValid, isFalse);
    });

    test('weight alone is a set when tracking is optional', () {
      final result = validateSetForm(
        count: empty,
        weight: const ParsedValue(40),
        countRequired: false,
      );
      expect(result.isValid, isTrue);
      expect(result.count, isNull);
      expect(result.weight, 40);
    });

    test('reports every invalid field, count first', () {
      final result = validateSetForm(
        count: const ParsedInvalid(SetInputError.notInteger),
        weight: const ParsedInvalid(SetInputError.notANumber),
        countRequired: false,
      );
      expect(result.isValid, isFalse);
      expect(result.countError, SetFormError.invalid);
      expect(result.countInputError, SetInputError.notInteger);
      expect(result.weightError, SetFormError.invalid);
      expect(result.weightInputError, SetInputError.notANumber);
    });
  });
}
