import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Localized "e.g." hint for numeric inputs, with the number formatted using
/// the decimal separator of the active locale.
String localizedInputExample(
  AppLocalizations l10n,
  num value, {
  int decimals = 1,
}) {
  final formatted = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: decimals,
  ).format(value);
  return l10n.inputExample(formatted);
}
