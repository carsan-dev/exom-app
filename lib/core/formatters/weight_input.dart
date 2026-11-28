import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';

// Weight display helpers for training (decision D5 of the redesign).
//
// Kilograms are the canonical unit everywhere data is stored or sent (Hive
// drafts, offline queue, API). The user's unit preference is a presentation
// concern only: convert to the display unit when painting, and convert a typed
// display value back to kilograms only when the user actually edited it.
//
// Rounding rules:
// - Display: converted value rounded to 2 decimals (half away from zero, on
//   the shortest decimal representation of the double: see
//   [roundToHundredths]), trailing zeros trimmed, locale decimal separator, never thousands grouping
//   ("1102,31", not "1.102,31": a grouped value would be ambiguous to parse).
// - Imperial input: lb -> kg rounded to 3 decimals. The stored error is at most
//   0.0005 kg = 0.0011 lb < 0.005 lb, so re-displaying at 2 decimals reproduces
//   the typed lb value exactly.
// - Metric input: stored exactly as typed (up to 2 decimals).

/// Decimal separator of the app locale: «,» for Spanish, «.» otherwise.
String decimalSeparatorFor(String languageCode) =>
    languageCode == 'es' ? ',' : '.';

/// Kilograms converted to the display unit, full precision.
double kgToDisplay(double kg, UnitSystem unitSystem) =>
    UnitConverters.weightToDisplay(kg, unitSystem);

/// A display-unit value converted to kilograms. Metric returns [value]
/// unchanged; imperial converts and rounds to 3 decimals.
double displayToKg(double value, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.metric) return value;
  return (UnitConverters.lbToKg(value) * 1000).round() / 1000;
}

/// [kg] in the user's unit as text, without the unit symbol: rounded to 2
/// decimals, trailing zeros trimmed, [decimalSeparator] between the integer
/// and the fraction, no thousands grouping. A non-finite value (NaN or
/// infinity) is no value: empty text, the same the set parser reads as
/// "nothing typed".
String formatWeightDisplay(
  double kg,
  UnitSystem unitSystem, {
  required String decimalSeparator,
}) {
  final value = kgToDisplay(kg, unitSystem);
  if (!value.isFinite) return '';
  final hundredths = _absHundredths(value);
  if (hundredths == 0) return '0';
  final whole = hundredths ~/ 100;
  final fraction = hundredths % 100;
  final sign = value < 0 ? '-' : '';
  if (fraction == 0) return '$sign$whole';
  final digits = fraction.toString().padLeft(2, '0').replaceFirst(
    RegExp(r'0$'),
    '',
  );
  return '$sign$whole$decimalSeparator$digits';
}

/// [value] rounded to 2 decimals, half away from zero. NaN and infinities
/// are returned unchanged.
///
/// Rounding `(value * 100).round()` is wrong for typed halves: 1.005 is stored
/// as 1.00499999999999989…, so `1.005 * 100` is 100.49999999999999 and rounds
/// to 1.00. Instead the decision is taken on the shortest decimal text that
/// identifies the double (`double.toString`, the digits the user typed or the
/// API sent): «1.005» has a third decimal of 5, so it rounds up to 1.01. No
/// epsilon is needed, and a value that already has at most 2 decimals parses
/// back to the very same double.
double roundToHundredths(double value) {
  if (!value.isFinite) return value;
  final hundredths = _absHundredths(value);
  final rounded = hundredths / 100;
  return value < 0 && hundredths != 0 ? -rounded : rounded;
}

/// |[value]| in whole hundredths, rounded half up on its decimal text (see
/// [roundToHundredths]). [value] must be finite.
int _absHundredths(double value) {
  final abs = value.abs();
  // Beyond 1e15 the double has no fractional hundredths left to round, and
  // toString may switch to exponent notation; plain arithmetic is exact there.
  if (abs >= 1e15) return (abs * 100).round();
  final text = abs.toString();
  // Tiny values print as «1e-7»: far below half a hundredth.
  if (text.contains('e')) return 0;
  final dot = text.indexOf('.');
  final whole = int.parse(dot < 0 ? text : text.substring(0, dot));
  final decimals = dot < 0 ? '' : text.substring(dot + 1);
  final padded = decimals.padRight(3, '0');
  final fraction = int.parse(padded.substring(0, 2));
  final roundsUp = padded.codeUnitAt(2) >= 0x35; // '5'
  return whole * 100 + fraction + (roundsUp ? 1 : 0);
}

/// A value already in the display unit as text, with the same rules as
/// [formatWeightDisplay] (2 decimals, trimmed, [decimalSeparator], no
/// grouping) and no conversion. Used by the ± controls of the set sheet.
String formatDisplayDecimal(double value, {required String decimalSeparator}) =>
    formatWeightDisplay(
      value,
      UnitSystem.metric,
      decimalSeparator: decimalSeparator,
    );

/// Increment of the ± controls: 2.5 kg or 5 lb.
double weightStep(UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? 5 : 2.5;

/// Upper bound of a typed weight in the display unit (typo guard): 500 kg,
/// or its lb equivalent floored to 2 decimals (1102.31 lb).
double maxWeightDisplay(UnitSystem unitSystem) {
  const maxKg = 500.0;
  if (unitSystem == UnitSystem.metric) return maxKg;
  return (UnitConverters.kgToLb(maxKg) * 100).floor() / 100;
}
