import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Figure in the active locale, without thousands separator (owner decision
/// 2026-11-20, L5-D5). Single helper for diets, challenges and profile.
///
/// [decimalDigits] fixes the number of decimals. With [maxDecimalDigits] the
/// figure shows up to that many decimals and drops trailing zeros (owner
/// decision 2026-11-27: Retos weights, 79,8 / 79,85 / 80); it takes
/// precedence over [decimalDigits]. Both default to the integer format.
String formatFigure(
  BuildContext context,
  num value, {
  int decimalDigits = 0,
  int? maxDecimalDigits,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  if (maxDecimalDigits != null) {
    final hashes = List.filled(maxDecimalDigits, '#').join();
    final pattern = maxDecimalDigits > 0 ? '0.$hashes' : '0';
    return NumberFormat(pattern, locale).format(value);
  }
  final format = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: decimalDigits,
  )..turnOffGrouping();
  return format.format(value);
}
