// Parsing and validation of a logged set's typed values (decision D3 of the
// redesign, approved 2026-11-18). Pure Dart: shared by the active exercise
// sheet and, later, the circuit.
//
// Rules (Postel's law: accept the unambiguous, reject the ambiguous):
// - Surrounding spaces (including no-break spaces) are ignored, and so is one
//   trailing unit token equal to the field's own unit («62,5 kg», «45 s»).
// - Weight accepts a whole number or one decimal separator («,» or «.») with
//   one or two decimals: «62,5» and «62.5» are the same value.
// - One to three digits, a separator and exactly three digits («1.250»,
//   «62.125») could be a thousands separator or a decimal: ambiguous.
// - Anything else is not a number («62,5,5», «abc», «.5», «+5», «6 2»).
// - Counts (reps, seconds, minutes) are whole numbers within [min, max].
// The typed text is never rewritten here; callers keep it on screen.

/// Why a typed value was rejected.
enum SetInputError {
  notANumber,
  ambiguous,
  negative,
  notInteger,
  tooManyDecimals,
  belowMin,
  aboveMax,
}

/// Result of parsing one field.
sealed class ParsedInput<T> {
  const ParsedInput();
}

/// The field holds a valid value.
final class ParsedValue<T> extends ParsedInput<T> {
  const ParsedValue(this.value);
  final T value;
}

/// The field is empty (or only spaces).
final class ParsedEmpty<T> extends ParsedInput<T> {
  const ParsedEmpty();
}

/// The field holds text that is not a valid value.
final class ParsedInvalid<T> extends ParsedInput<T> {
  const ParsedInvalid(this.error);
  final SetInputError error;
}

final RegExp _whole = RegExp(r'^\d+$');
final RegExp _oneOrTwoDecimals = RegExp(r'^\d+[.,]\d{1,2}$');
final RegExp _thousandsLike = RegExp(r'^\d{1,3}[.,]\d{3}$');
final RegExp _threeOrMoreDecimals = RegExp(r'^\d+[.,]\d{3,}$');

String _normalise(String raw, String? unitSymbol) {
  var text = raw.trim();
  if (unitSymbol != null && unitSymbol.isNotEmpty) {
    final lower = text.toLowerCase();
    final unit = unitSymbol.toLowerCase();
    if (lower.endsWith(unit)) {
      final rest = text.substring(0, text.length - unit.length).trimRight();
      // Only a unit after a number: «kg» alone stays not-a-number.
      if (rest.isNotEmpty && RegExp(r'\d$').hasMatch(rest)) text = rest;
    }
  }
  return text;
}

/// Parses a weight typed in the display unit ([unitSymbol], e.g. «kg» or
/// «lb»). The value is returned in that same unit; [max] is the upper bound in
/// that unit. Converting to kilograms is the caller's job.
ParsedInput<double> parseWeight(
  String raw, {
  required double max,
  String? unitSymbol,
}) {
  final text = _normalise(raw, unitSymbol);
  if (text.isEmpty) return const ParsedEmpty();
  if (text.startsWith('-')) return const ParsedInvalid(SetInputError.negative);
  if (_whole.hasMatch(text) || _oneOrTwoDecimals.hasMatch(text)) {
    final value = double.parse(text.replaceAll(',', '.'));
    if (value > max) return const ParsedInvalid(SetInputError.aboveMax);
    return ParsedValue(value);
  }
  if (_thousandsLike.hasMatch(text)) {
    return const ParsedInvalid(SetInputError.ambiguous);
  }
  if (_threeOrMoreDecimals.hasMatch(text)) {
    return const ParsedInvalid(SetInputError.tooManyDecimals);
  }
  return const ParsedInvalid(SetInputError.notANumber);
}

/// Parses a whole count (reps, seconds or minutes) within [min]..[max].
ParsedInput<int> parseCount(
  String raw, {
  int min = 1,
  required int max,
  String? unitSymbol,
}) {
  final text = _normalise(raw, unitSymbol);
  if (text.isEmpty) return const ParsedEmpty();
  if (text.startsWith('-')) return const ParsedInvalid(SetInputError.negative);
  if (_whole.hasMatch(text)) {
    // Longer than 9 digits is above any bound and could overflow.
    if (text.length > 9) return const ParsedInvalid(SetInputError.aboveMax);
    final value = int.parse(text);
    if (value < min) return const ParsedInvalid(SetInputError.belowMin);
    if (value > max) return const ParsedInvalid(SetInputError.aboveMax);
    return ParsedValue(value);
  }
  if (_thousandsLike.hasMatch(text)) {
    return const ParsedInvalid(SetInputError.ambiguous);
  }
  if (_oneOrTwoDecimals.hasMatch(text) || _threeOrMoreDecimals.hasMatch(text)) {
    return const ParsedInvalid(SetInputError.notInteger);
  }
  return const ParsedInvalid(SetInputError.notANumber);
}

/// Field-level outcome of [validateSetForm].
enum SetFormError {
  /// The text is not a valid value; see the [SetInputError].
  invalid,

  /// Set tracking is mandatory and the reps/seconds field is empty.
  countRequired,

  /// Neither reps/seconds nor weight: not a set (RIR alone is not enough).
  noData,
}

/// Result of validating the set form before saving.
class SetFormValidation {
  const SetFormValidation({
    this.count,
    this.weight,
    this.countError,
    this.countInputError,
    this.weightError,
    this.weightInputError,
  });

  /// Valid reps/seconds/minutes as typed (null when empty).
  final int? count;

  /// Valid weight in the display unit (null when empty).
  final double? weight;
  final SetFormError? countError;
  final SetInputError? countInputError;
  final SetFormError? weightError;
  final SetInputError? weightInputError;

  bool get isValid => countError == null && weightError == null;
}

/// Sheet-level rules of a set: any invalid field blocks the save; an empty
/// count is allowed unless [countRequired]; and a set must carry reps,
/// seconds or weight. The RIR is deliberately not an input: the API rejects a
/// set whose only value is the RIR («Cada serie debe incluir repeticiones,
/// segundos o peso», 400), so it can never make a set valid on its own.
SetFormValidation validateSetForm({
  required ParsedInput<int> count,
  required ParsedInput<double> weight,
  required bool countRequired,
}) {
  SetFormError? countError;
  SetInputError? countInputError;
  SetFormError? weightError;
  SetInputError? weightInputError;
  int? countValue;
  double? weightValue;

  switch (count) {
    case ParsedValue<int>(:final value):
      countValue = value;
    case ParsedInvalid<int>(:final error):
      countError = SetFormError.invalid;
      countInputError = error;
    case ParsedEmpty<int>():
      if (countRequired) countError = SetFormError.countRequired;
  }
  switch (weight) {
    case ParsedValue<double>(:final value):
      weightValue = value;
    case ParsedInvalid<double>(:final error):
      weightError = SetFormError.invalid;
      weightInputError = error;
    case ParsedEmpty<double>():
      break;
  }
  if (countError == null &&
      weightError == null &&
      countValue == null &&
      weightValue == null) {
    countError = SetFormError.noData;
  }
  return SetFormValidation(
    count: countValue,
    weight: weightValue,
    countError: countError,
    countInputError: countInputError,
    weightError: weightError,
    weightInputError: weightInputError,
  );
}
