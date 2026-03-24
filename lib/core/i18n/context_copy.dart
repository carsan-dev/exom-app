import 'package:flutter/widgets.dart';

extension ContextCopy on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';

  String copy(String es, String en) => isEnglish ? en : es;
}
