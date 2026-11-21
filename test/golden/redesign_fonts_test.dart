// The golden helper must load the Lucide font; if it cannot find it, it throws
// instead of leaving every icon as an Ahem box.
import 'package:flutter_test/flutter_test.dart';

import 'redesign_scenes.dart';

void main() {
  test('the Lucide font is found on disk and is a real font file', () {
    final font = findLucideFontFile();
    expect(font.existsSync(), isTrue);
    expect(font.path.replaceAll(r'\', '/'), contains('lucide_icons_flutter'));
    expect(font.lengthSync(), greaterThan(100000));
  });

  test('loadRedesignFonts loads the fonts without throwing', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRedesignFonts();
  });
}
