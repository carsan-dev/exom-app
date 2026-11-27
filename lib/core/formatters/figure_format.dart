import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Figure in the active locale, without thousands separator (owner decision
/// 2026-11-20, L5-D5). Single helper for diets, challenges and profile.
String formatFigure(BuildContext context, num value, {int decimalDigits = 0}) {
  final format = NumberFormat.decimalPatternDigits(
    locale: Localizations.localeOf(context).toLanguageTag(),
    decimalDigits: decimalDigits,
  )..turnOffGrouping();
  return format.format(value);
}
