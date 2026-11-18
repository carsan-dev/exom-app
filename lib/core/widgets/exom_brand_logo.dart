import 'dart:convert';
import 'dart:typed_data';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// EXOM symbol + wordmark for the shell header (redesign L2).
///
/// Plan §6 brand exception: the header symbol keeps its lime half; it is not
/// an action. Following the approved sketch («A «Sesión de hoy» · Inicio»),
/// the left half of the symbol and the «EXOM» wordmark use the theme `text`
/// colour (bone in dark, carbon in light) and the right half is lime
/// #BAF23A. In the light theme the lime half gets a 1 px carbon outline so it
/// does not vanish on bone. Nothing else in the header is lime.
///
/// The existing `assets/images/logo.svg` has one flat fill for every path, so
/// it is recoloured on load ([ExomBrandLogo.loaderFor]) instead of adding new
/// asset files. If the asset no longer has the expected six paths (wordmark
/// E, M, O, X, then the two halves of the symbol), every path is painted in
/// the text colour (monochrome) rather than guessing which path is which.
class ExomBrandLogo extends StatelessWidget {
  const ExomBrandLogo({super.key, this.height = 28, this.semanticsLabel});

  final double height;
  final String? semanticsLabel;

  static const assetName = 'assets/images/logo.svg';

  /// Loader that recolours [assetName] for [brightness] and [palette]; the
  /// outline is computed so that it is 1 logical pixel at [height].
  static SvgAssetLoader loaderFor(
    Brightness brightness,
    ExomThemePalette palette, {
    double height = 28,
  }) {
    return _BrandLogoLoader(
      textColor: palette.textPrimary,
      accentColor: AppColors.primary,
      outlineColor: brightness == Brightness.light ? palette.textPrimary : null,
      outlineWidth: _viewBoxHeight / height,
    );
  }

  static const double _viewBoxHeight = 40;

  @override
  Widget build(BuildContext context) {
    return SvgPicture(
      loaderFor(
        Theme.of(context).brightness,
        context.exomPalette,
        height: height,
      ),
      height: height,
      semanticsLabel: semanticsLabel,
    );
  }
}

class _BrandLogoLoader extends SvgAssetLoader {
  const _BrandLogoLoader({
    required this.textColor,
    required this.accentColor,
    required this.outlineColor,
    required this.outlineWidth,
  }) : super(ExomBrandLogo.assetName);

  final Color textColor;
  final Color accentColor;
  final Color? outlineColor;
  final double outlineWidth;

  static const _expectedPaths = 6;
  static const _accentPathIndex = 5;
  static final _path = RegExp(r'<path\b[^>]*?/?>');
  static final _fill = RegExp(r'\sfill="[^"]*"');

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  String provideSvg(ByteData? message) {
    final svg = utf8.decode(
      Uint8List.sublistView(message!),
      allowMalformed: true,
    );
    final twoTone = _path.allMatches(svg).length == _expectedPaths;
    var index = 0;
    return svg.replaceAllMapped(_path, (match) {
      final accent = twoTone && index == _accentPathIndex;
      index++;
      final tag = match.group(0)!.replaceAll(_fill, '');
      final close = tag.endsWith('/>') ? '/>' : '>';
      final body = tag.substring(0, tag.length - close.length);
      final buffer = StringBuffer(body)
        ..write(' fill="${_hex(accent ? accentColor : textColor)}"');
      if (accent && outlineColor != null) {
        buffer
          ..write(' stroke="${_hex(outlineColor!)}"')
          ..write(' stroke-width="${outlineWidth.toStringAsFixed(3)}"')
          ..write(' stroke-linejoin="round"');
      }
      buffer.write(close);
      return buffer.toString();
    });
  }

  Object get _key => (
    ExomBrandLogo.assetName,
    textColor,
    accentColor,
    outlineColor,
    outlineWidth,
  );

  @override
  SvgCacheKey cacheKey(BuildContext? context) =>
      SvgCacheKey(theme: getTheme(context), colorMapper: null, keyData: _key);

  @override
  int get hashCode => _key.hashCode;

  @override
  bool operator ==(Object other) =>
      other is _BrandLogoLoader && other._key == _key;
}
