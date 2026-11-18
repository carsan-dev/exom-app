import 'dart:io';
import 'dart:typed_data';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

List<String> _fills(String svg) => RegExp(
  r'<path\b[^>]*?\bfill="(#[0-9A-Fa-f]{6})"',
).allMatches(svg).map((m) => m.group(1)!.toUpperCase()).toList();

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final source = File('assets/images/logo.svg').readAsBytesSync();
  final message = ByteData.sublistView(Uint8List.fromList(source));

  for (final brightness in Brightness.values) {
    test('two-tone symbol, wordmark in text colour (${brightness.name})', () {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      final loader = ExomBrandLogo.loaderFor(brightness, palette);
      final svg = loader.provideSvg(message);
      final fills = _fills(svg);
      final text = _hex(palette.textPrimary);
      // Asset order: E, M, O, X (wordmark), left half, right half (symbol).
      expect(fills, [text, text, text, text, text, '#BAF23A']);
      expect(svg, isNot(contains('#C5E384')), reason: 'old pale green gone');
      final outlined = RegExp(r'<path\b[^>]*\bstroke="#').allMatches(svg);
      if (brightness == Brightness.light) {
        // The lime half keeps a 1 px carbon outline so it does not vanish on
        // bone (sketch: stroke #101111).
        expect(outlined.length, 1);
        expect(svg, contains('stroke="#101111"'));
      } else {
        expect(outlined, isEmpty);
      }
    });
  }

  test('loaders differ per theme so the SVG cache does not mix them', () {
    final dark = AppTheme.dark.extension<ExomThemePalette>()!;
    final light = AppTheme.light.extension<ExomThemePalette>()!;
    final a = ExomBrandLogo.loaderFor(Brightness.dark, dark);
    final b = ExomBrandLogo.loaderFor(Brightness.light, light);
    expect(a == b, isFalse);
    expect(a.cacheKey(null) == b.cacheKey(null), isFalse);
    expect(a == ExomBrandLogo.loaderFor(Brightness.dark, dark), isTrue);
  });

  test('unexpected asset structure falls back to monochrome text colour', () {
    final palette = AppTheme.dark.extension<ExomThemePalette>()!;
    final loader = ExomBrandLogo.loaderFor(Brightness.dark, palette);
    const odd =
        '<svg viewBox="0 0 10 10"><path d="M0 0H1V1Z" fill="#C5E384"/></svg>';
    final svg = loader.provideSvg(
      ByteData.sublistView(Uint8List.fromList(odd.codeUnits)),
    );
    expect(_fills(svg), [_hex(palette.textPrimary)]);
  });

  testWidgets('renders an SvgPicture at the given height', (tester) async {
    await pumpComponent(tester, const ExomBrandLogo(height: 28));
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.height, 28);
    expect(picture.bytesLoader, isA<SvgAssetLoader>());
    expectNoOverflow(tester);
  });
}
