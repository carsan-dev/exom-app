import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Long date of [isoDate] in the active locale (TEXTOS-2 O6, L5-D52); shared
/// with the pending-sessions box of Entrenar. An
/// unparseable value is shown as it came.
String sessionDateLabel(BuildContext context, String isoDate) {
  final day = DateTime.tryParse(isoDate);
  if (day == null) return isoDate;
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMMd(locale).format(day);
}
