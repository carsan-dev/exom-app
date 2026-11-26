import 'dart:convert';
import 'dart:typed_data';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// EXOM lockup: balance symbol + «EXOM» wordmark (redesign L5-LOGO).
///
/// Mirrors the site's `.brand-lockup` (exom-site `exom-balance.svg`): a row
/// centred on the cross axis, gap `.22em`, symbol `.96em × .896em`, wordmark
/// Barlow Condensed 800 with `-.04em` letter spacing and line height 1, where
/// `em` is [height]. The lockup does not follow the system text scale.
///
/// Colours (palette `textPrimary` is bone in dark, carbon in light):
/// * dark: bone comma, lime comma, letters in `textPrimary` and the X lime;
/// * light: carbon comma, lime comma with a 1 logical px carbon outline and
///   all four letters in `textPrimary` (no lime X on bone, approved).
///
/// The symbol asset is recoloured on load by path id (`exom-bone`,
/// `exom-lime`, see [recolorSymbol]); if either id is missing every path is
/// painted in the bone colour (monochrome) rather than guessing.
class ExomBrandLogo extends StatelessWidget {
  const ExomBrandLogo({super.key, this.height = 28, this.semanticsLabel});

  final double height;
  final String? semanticsLabel;

  static const assetName = 'assets/images/exom_balance.svg';

  /// Id of the left (bone) comma in [assetName].
  static const boneId = 'exom-bone';

  /// Id of the right (lime) comma in [assetName].
  static const limeId = 'exom-lime';

  // Site `.brand-lockup` proportions, in em (1 em = [height]).
  static const double symbolWidthEm = 0.96;
  static const double symbolHeightEm = 0.896;
  static const double gapEm = 0.22;
  static const double letterSpacingEm = -0.04;
  static const String wordmark = 'EXOM';
  static const String fontFamily = 'BarlowCondensed';

  static const double _viewBoxHeight = 112;

  /// Loader that recolours [assetName] for [brightness] and [palette]; the
  /// outline of the lime comma (light only) is 1 logical pixel at [height].
  static SvgAssetLoader loaderFor(
    Brightness brightness,
    ExomThemePalette palette, {
    double height = 28,
  }) {
    return _BrandSymbolLoader(
      bone: palette.textPrimary,
      lime: AppColors.primary,
      outline: brightness == Brightness.light ? palette.textPrimary : null,
      outlineWidth: _viewBoxHeight / (height * symbolHeightEm),
    );
  }

  /// Recolours the symbol SVG by path id. Pure, so the PDF can reuse it.
  ///
  /// [bone] fills `exom-bone`, [lime] fills `exom-lime`; [outline] (with
  /// [outlineWidth], in viewBox units) strokes only the lime comma. If either
  /// id is absent, every path is painted [bone] with no stroke.
  static String recolorSymbol(
    String svg, {
    required Color bone,
    required Color lime,
    Color? outline,
    double outlineWidth = 1,
  }) {
    final paths = _path.allMatches(svg).map((m) => m.group(0)!).toList();
    final hasBone = paths.any((tag) => _idOf(tag) == boneId);
    final hasLime = paths.any((tag) => _idOf(tag) == limeId);
    final twoTone = hasBone && hasLime;
    final outlined = twoTone && outline != null;
    final source = outlined ? _padViewBox(svg, outlineWidth) : svg;
    return source.replaceAllMapped(_path, (match) {
      final tag = match.group(0)!;
      final id = _idOf(tag);
      final isLime = twoTone && id == limeId;
      final color = isLime ? lime : bone;
      final close = tag.endsWith('/>') ? '/>' : '>';
      final body = tag
          .substring(0, tag.length - close.length)
          .replaceAll(_fill, '')
          .replaceAll(_stroke, '');
      final buffer = StringBuffer(body)..write(' fill="${_hex(color)}"');
      if (isLime && outline != null) {
        buffer
          ..write(' stroke="${_hex(outline)}"')
          ..write(' stroke-width="${outlineWidth.toStringAsFixed(3)}"')
          ..write(' stroke-linejoin="round"');
      }
      buffer.write(close);
      return buffer.toString();
    });
  }

  /// Grows the viewBox by half the stroke on every side so the outline is
  /// not clipped; the rendered box keeps its size (shapes shrink slightly).
  static String _padViewBox(String svg, double stroke) {
    return svg.replaceFirstMapped(_viewBox, (m) {
      final v = m.group(1)!.trim().split(RegExp(r'[\s,]+'));
      if (v.length != 4) return m.group(0)!;
      final n = v.map(double.tryParse).toList();
      if (n.contains(null)) return m.group(0)!;
      final h = stroke / 2;
      String f(double x) => x.toStringAsFixed(3);
      return 'viewBox="${f(n[0]! - h)} ${f(n[1]! - h)} '
          '${f(n[2]! + stroke)} ${f(n[3]! + stroke)}"';
    });
  }

  static final _viewBox = RegExp(r'viewBox="([^"]*)"');
  static final _path = RegExp(r'<path\b[^>]*?/?>');
  static final _fill = RegExp(r'\sfill="[^"]*"');
  static final _stroke = RegExp(r'\sstroke(?:-[a-z]+)?="[^"]*"');
  static final _id = RegExp(r'\sid="([^"]*)"');

  static String? _idOf(String tag) => _id.firstMatch(tag)?.group(1);

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? 'EXOM',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _symbolFor(context, height),
          SizedBox(width: height * gapEm),
          _wordmarkFor(context, height),
        ],
      ),
    );
  }
}

/// Symbol of the lockup for an em of [em] logical px (symbol `.96em × .896em`).
Widget _symbolFor(
  BuildContext context,
  double em, {
  WidgetBuilder? placeholderBuilder,
}) {
  return SvgPicture(
    ExomBrandLogo.loaderFor(
      Theme.of(context).brightness,
      context.exomPalette,
      height: em,
    ),
    width: em * ExomBrandLogo.symbolWidthEm,
    height: em * ExomBrandLogo.symbolHeightEm,
    fit: BoxFit.contain,
    placeholderBuilder: placeholderBuilder,
  );
}

/// «EXOM» text of the lockup for an em of [em] logical px.
Widget _wordmarkFor(BuildContext context, double em) {
  final palette = context.exomPalette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final letter = TextStyle(color: palette.textPrimary);
  final accent = TextStyle(
    color: isDark ? AppColors.primary : palette.textPrimary,
  );
  return Text.rich(
    TextSpan(
      style: TextStyle(
        fontFamily: ExomBrandLogo.fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: em,
        height: 1.0,
        letterSpacing: em * ExomBrandLogo.letterSpacingEm,
        color: palette.textPrimary,
      ),
      children: [
        TextSpan(text: 'E', style: letter),
        TextSpan(text: 'X', style: accent),
        TextSpan(text: 'O', style: letter),
        TextSpan(text: 'M', style: letter),
      ],
    ),
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.clip,
    textScaler: TextScaler.noScaling,
  );
}

/// Wraps [child] with the semantics rules shared by the standalone parts:
/// excluded entirely when [excludeSemantics], otherwise one node labelled
/// [semanticsLabel] (default `EXOM`) that replaces the children's semantics.
Widget _semantic(
  Widget child, {
  required String? semanticsLabel,
  required bool excludeSemantics,
}) {
  if (excludeSemantics) return ExcludeSemantics(child: child);
  return Semantics(
    label: semanticsLabel ?? 'EXOM',
    excludeSemantics: true,
    child: child,
  );
}

/// The balance symbol alone, with the lockup's theme recolour (dark: bone and
/// lime commas; light: carbon comma and lime comma with a 1 px carbon outline).
///
/// [height] is the symbol box height; its width follows the asset's 120:112
/// aspect. Semantics: one node labelled `EXOM` (or [semanticsLabel]); set
/// [excludeSemantics] when another widget on screen already announces the
/// brand, so it is not announced twice.
class ExomBrandSymbol extends StatelessWidget {
  const ExomBrandSymbol({
    super.key,
    this.height = 28,
    this.semanticsLabel,
    this.excludeSemantics = false,
    this.placeholderBuilder,
  });

  final double height;
  final String? semanticsLabel;
  final bool excludeSemantics;

  /// Shown while the picture decodes (default: an empty box of its size).
  final WidgetBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return _semantic(
      _symbolFor(
        context,
        height / ExomBrandLogo.symbolHeightEm,
        placeholderBuilder: placeholderBuilder,
      ),
      semanticsLabel: semanticsLabel,
      excludeSemantics: excludeSemantics,
    );
  }
}

/// The «EXOM» wordmark alone, same style and colour rules as the lockup
/// (Barlow Condensed 800, letter spacing `-.04em`, line height 1, no text
/// scaling; X lime in dark, all letters `textPrimary` in light).
///
/// [height] is the em (font size, and the box height). Semantics as in
/// [ExomBrandSymbol]: one `EXOM` node unless [excludeSemantics].
class ExomWordmark extends StatelessWidget {
  const ExomWordmark({
    super.key,
    this.height = 28,
    this.semanticsLabel,
    this.excludeSemantics = false,
  });

  final double height;
  final String? semanticsLabel;
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    return _semantic(
      _wordmarkFor(context, height),
      semanticsLabel: semanticsLabel,
      excludeSemantics: excludeSemantics,
    );
  }
}

class _BrandSymbolLoader extends SvgAssetLoader {
  const _BrandSymbolLoader({
    required this.bone,
    required this.lime,
    required this.outline,
    required this.outlineWidth,
  }) : super(ExomBrandLogo.assetName);

  final Color bone;
  final Color lime;
  final Color? outline;
  final double outlineWidth;

  @override
  String provideSvg(ByteData? message) {
    final svg = utf8.decode(
      Uint8List.sublistView(message!),
      allowMalformed: true,
    );
    return ExomBrandLogo.recolorSymbol(
      svg,
      bone: bone,
      lime: lime,
      outline: outline,
      outlineWidth: outlineWidth,
    );
  }

  Object get _key =>
      (ExomBrandLogo.assetName, bone, lime, outline, outlineWidth);

  @override
  SvgCacheKey cacheKey(BuildContext? context) =>
      SvgCacheKey(theme: getTheme(context), colorMapper: null, keyData: _key);

  @override
  int get hashCode => _key.hashCode;

  @override
  bool operator ==(Object other) =>
      other is _BrandSymbolLoader && other._key == _key;
}
