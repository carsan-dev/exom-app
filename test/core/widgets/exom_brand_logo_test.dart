import 'dart:io';
import 'dart:typed_data';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_nonlinear_text_scaler.dart';
import 'exom_component_harness.dart';

/// Path `d` of `exom-balance.svg` in exom-site (REDESIGN/prototype-v4).
const _siteD =
    'M46 110C20 106 0 84 0 56C0 33 14 12 35 3C48-2 60 4 62 16C66 29 57 39 44 '
    '39C36 39 28 35 23 28C11 38 5 51 7 65C9 86 24 103 46 109Z';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _tagWithId(String svg, String id) =>
    RegExp('<path\\b[^>]*\\bid="$id"[^>]*>').firstMatch(svg)!.group(0)!;

String _attr(String tag, String name) =>
    RegExp('\\s$name="([^"]*)"').firstMatch(tag)?.group(1) ?? '';

void main() {
  final source = File('assets/images/exom_balance.svg').readAsStringSync();
  final message = ByteData.sublistView(Uint8List.fromList(source.codeUnits));

  test('asset has the site symbol: same d in both paths, rotated lime', () {
    final bone = _tagWithId(source, 'exom-bone');
    final lime = _tagWithId(source, 'exom-lime');
    expect(_attr(bone, 'd'), _siteD);
    expect(_attr(lime, 'd'), _siteD);
    expect(_attr(bone, 'fill').toLowerCase(), '#f2f1e9');
    expect(_attr(lime, 'fill').toLowerCase(), '#baf23a');
    expect(_attr(lime, 'transform'), 'rotate(180 60 56)');
    expect(_attr(bone, 'transform'), isEmpty);
    expect(source, contains('viewBox="0 0 120 112"'));
    expect(source, contains('<title>EXOM</title>'));
  });

  test('dark recolour: bone + lime fills, no stroke', () {
    final palette = AppTheme.dark.extension<ExomThemePalette>()!;
    final svg = ExomBrandLogo.loaderFor(
      Brightness.dark,
      palette,
    ).provideSvg(message);
    expect(
      _attr(_tagWithId(svg, 'exom-bone'), 'fill'),
      _hex(palette.textPrimary),
    );
    expect(_attr(_tagWithId(svg, 'exom-lime'), 'fill'), '#BAF23A');
    expect(svg, isNot(contains('stroke')));
    expect(_hex(palette.textPrimary), '#F2F1E9');
  });

  test('light recolour: carbon bone, lime with 1 px carbon outline', () {
    final palette = AppTheme.light.extension<ExomThemePalette>()!;
    final svg = ExomBrandLogo.loaderFor(
      Brightness.light,
      palette,
      height: 28,
    ).provideSvg(message);
    final bone = _tagWithId(svg, 'exom-bone');
    final lime = _tagWithId(svg, 'exom-lime');
    expect(_attr(bone, 'fill'), '#101111');
    expect(_attr(bone, 'stroke'), isEmpty);
    expect(_attr(lime, 'fill'), '#BAF23A');
    expect(_attr(lime, 'stroke'), '#101111');
    expect(_attr(lime, 'stroke-linejoin'), 'round');
    // 1 logical px = 112 viewBox units / symbol height in px (0.896 * 28).
    expect(
      double.parse(_attr(lime, 'stroke-width')),
      closeTo(112 / (0.896 * 28), 0.001),
    );
  });

  test('viewBox is padded by half the stroke in light, untouched in dark', () {
    final light = AppTheme.light.extension<ExomThemePalette>()!;
    final dark = AppTheme.dark.extension<ExomThemePalette>()!;
    final lightSvg = ExomBrandLogo.loaderFor(
      Brightness.light,
      light,
      height: 28,
    ).provideSvg(message);
    final s = 112 / (0.896 * 28);
    final box = RegExp(
      r'viewBox="([^"]*)"',
    ).firstMatch(lightSvg)!.group(1)!.split(' ').map(double.parse).toList();
    expect(box[0], closeTo(-s / 2, 0.001));
    expect(box[1], closeTo(-s / 2, 0.001));
    expect(box[2], closeTo(120 + s, 0.001));
    expect(box[3], closeTo(112 + s, 0.001));
    final darkSvg = ExomBrandLogo.loaderFor(
      Brightness.dark,
      dark,
    ).provideSvg(message);
    expect(darkSvg, contains('viewBox="0 0 120 112"'));
  });

  test('missing id falls back to monochrome in the bone colour', () {
    const odd =
        '<svg viewBox="0 0 10 10"><path id="exom-bone" d="M0 0H1V1Z" '
        'fill="#f2f1e9"/><path d="M0 0H2V2Z" fill="#baf23a"/></svg>';
    final svg = ExomBrandLogo.recolorSymbol(
      odd,
      bone: const Color(0xFF101111),
      lime: AppColors.primary,
      outline: const Color(0xFF101111),
      outlineWidth: 3,
    );
    final fills = RegExp(
      r'fill="(#[0-9A-F]{6})"',
    ).allMatches(svg).map((m) => m.group(1)).toList();
    expect(fills, ['#101111', '#101111']);
    expect(svg, isNot(contains('stroke')));
  });

  test('loaders differ per theme so the SVG cache does not mix them', () {
    final dark = AppTheme.dark.extension<ExomThemePalette>()!;
    final light = AppTheme.light.extension<ExomThemePalette>()!;
    final a = ExomBrandLogo.loaderFor(Brightness.dark, dark);
    final b = ExomBrandLogo.loaderFor(Brightness.light, light);
    expect(a == b, isFalse);
    expect(a.cacheKey(null) == b.cacheKey(null), isFalse);
    expect(a == ExomBrandLogo.loaderFor(Brightness.dark, dark), isTrue);
    expect(a.hashCode, ExomBrandLogo.loaderFor(Brightness.dark, dark).hashCode);
  });

  Text wordmark(WidgetTester tester) => tester.widget<Text>(
    find.descendant(
      of: find.byType(ExomBrandLogo),
      matching: find.byType(Text),
    ),
  );

  for (final brightness in Brightness.values) {
    testWidgets('letters colours (${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        const ExomBrandLogo(),
        brightness: brightness,
      );
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      final spans = (wordmark(tester).textSpan! as TextSpan).children!
          .cast<TextSpan>();
      expect(spans.map((s) => s.text).join(), 'EXOM');
      final xColor = brightness == Brightness.dark
          ? AppColors.primary
          : palette.textPrimary;
      expect(spans.map((s) => s.style?.color).toList(), [
        palette.textPrimary,
        xColor,
        palette.textPrimary,
        palette.textPrimary,
      ]);
    });
  }

  testWidgets('lockup proportions at h=28 (site .brand-lockup)', (
    tester,
  ) async {
    await pumpComponent(tester, const ExomBrandLogo(height: 28));
    final symbol = tester.getSize(find.byType(SvgPicture));
    expect(symbol.width, closeTo(26.88, 0.001));
    expect(symbol.height, closeTo(25.088, 0.001));
    final gap = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(ExomBrandLogo),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.child == null && w.width != null,
        ),
      ),
    );
    expect(gap.width, closeTo(6.16, 0.001));
    final text = wordmark(tester);
    final style = (text.textSpan! as TextSpan).style!;
    expect(style.fontFamily, 'BarlowCondensed');
    expect(style.fontWeight, FontWeight.w800);
    expect(style.fontSize, 28);
    expect(style.height, 1.0);
    expect(style.letterSpacing, closeTo(-1.12, 0.001));
    expect(text.maxLines, 1);
    expect(text.textScaler, TextScaler.noScaling);
    expect(tester.getSize(find.byType(ExomBrandLogo)).height, 28);
    expectNoOverflow(tester);
  });

  testWidgets('lockup ignores the system text scale', (tester) async {
    await pumpComponent(tester, const ExomBrandLogo(height: 28));
    final base = tester.getSize(find.byType(ExomBrandLogo));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: AndroidNonlinearTextScaler(2.0),
          ),
          child: Scaffold(body: Center(child: ExomBrandLogo(height: 28))),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ExomBrandLogo)), base);
  });

  testWidgets('one semantics node labelled EXOM, children excluded', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, const ExomBrandLogo());
    expect(find.bySemanticsLabel('EXOM'), findsOneWidget);
    await pumpComponent(tester, const ExomBrandLogo(semanticsLabel: 'Inicio'));
    expect(find.bySemanticsLabel('Inicio'), findsOneWidget);
    expect(find.bySemanticsLabel('EXOM'), findsNothing);
    handle.dispose();
  });
}
