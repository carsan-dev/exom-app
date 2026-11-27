import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exom_app/core/licenses/font_licenses.dart';

Future<Map<String, String>> _textsByPackage() async {
  final texts = <String, String>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    for (final package in entry.packages) {
      texts[package] = '${texts[package] ?? ''}$text';
    }
  }
  return texts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registra las licencias OFL de DM Sans y Barlow Condensed', () async {
    registerFontLicenses();
    final texts = await _textsByPackage();

    final dmSans = texts['DM Sans'];
    expect(dmSans, isNotNull);
    expect(dmSans, contains('SIL Open Font License'));
    expect(
      dmSans,
      contains(
        'Copyright 2014 The DM Sans Project Authors '
        '(https://github.com/googlefonts/dm-fonts)',
      ),
    );

    final barlow = texts['Barlow Condensed'];
    expect(barlow, isNotNull);
    expect(barlow, contains('SIL Open Font License'));
    expect(
      barlow,
      contains(
        'Copyright 2017 The Barlow Project Authors '
        '(https://github.com/jpt/barlow)',
      ),
    );
  });
}
