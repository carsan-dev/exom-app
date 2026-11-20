// L4-I25a: the Spanish description of the imperial unit system in Settings.
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Spanish imperial description says «libras y pulgadas»', () {
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.imperialDescription, contains('libras y pulgadas'));
    expect(es.imperialDescription, isNot(contains('libras e pulgadas')));
  });

  test('English imperial description keeps «pounds and inches»', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.imperialDescription, contains('pounds and inches'));
  });
}
