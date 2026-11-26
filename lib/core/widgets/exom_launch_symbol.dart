import 'dart:ui' as ui;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Geometry of the brand symbol on the launch path (redesign L5-LOGO, D3).
///
/// The native splash (Android `splash.png` / `android12splash.png`, iOS
/// `LaunchImage`) draws the symbol at this size, centred on the full screen
/// with the system insets ignored. The bootstrap screen in `lib/main.dart`
/// continues it exactly, and the Flutter splash (V4d) starts its first frame
/// from [rectIn] so the symbol does not jump between the three stages.
///
/// The colours follow the platform brightness, like the native splash: carbon
/// background in dark, paper (`#F2F1E9`, the light theme background) in
/// light, with the symbol recoloured by `ExomBrandSymbol` for that brightness.
abstract final class ExomLaunchSymbol {
  /// Symbol box width in logical px (dp).
  static const double width = 80.64;

  /// Symbol box height in logical px: the asset's 120:112 aspect.
  static const double height = width * 112 / 120;

  /// Symbol box for a screen of [screen] logical px: centred, insets ignored.
  static Rect rectIn(Size screen) => Rect.fromCenter(
    center: screen.center(Offset.zero),
    width: width,
    height: height,
  );

  /// Loader of the symbol at the launch size for [brightness], in the app
  /// theme's palette (`AppTheme.light` / `AppTheme.dark`): the one the
  /// bootstrap screen draws, same cache key as `ExomBrandSymbol(height:
  /// height)` under that theme.
  static SvgAssetLoader loaderFor(Brightness brightness) {
    final theme = brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;
    return ExomBrandLogo.loaderFor(
      brightness,
      theme.extension<ExomThemePalette>()!,
      height: height / ExomBrandLogo.symbolHeightEm,
    );
  }

  static final Map<Brightness, PictureInfo> _pictures = {};

  /// Decodes the launch symbol of both brightnesses ahead of the app (L5-D3
  /// r3, D3-E1). The splash's own symbol is decoded asynchronously after its
  /// first frame, so that frame draws this one, already decoded, in the
  /// bootstrap screen's box: no frame without the symbol in between. Both
  /// brightnesses, as the app theme may differ from the system's. Failures
  /// are logged and leave [pictureFor] null (the splash then waits for its
  /// own picture, as before).
  static Future<void> precachePictures() async {
    await Future.wait([
      for (final brightness in Brightness.values)
        if (!_pictures.containsKey(brightness))
          vg
              .loadPicture(loaderFor(brightness), null)
              .then<void>((info) => _pictures[brightness] ??= info)
              .catchError((Object error) {
                debugPrint('[BOOTSTRAP] Launch symbol not decoded: $error');
              }),
    ]);
  }

  /// The decoded launch symbol for [brightness], once [precachePictures] has
  /// finished.
  static PictureInfo? pictureFor(Brightness brightness) =>
      _pictures[brightness];

  @visibleForTesting
  static void debugClearPictures() => _pictures.clear();
}

/// The launch symbol already decoded by [ExomLaunchSymbol.precachePictures],
/// laid out as `ExomBrandSymbol(height: height)` lays out its picture (box
/// height [height], width from the picture's aspect, contained and centred).
/// Placeholder of the splash's symbol while its own picture decodes; empty if
/// the launch symbol is not decoded.
class ExomLaunchSymbolPicture extends StatelessWidget {
  const ExomLaunchSymbolPicture({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final info = ExomLaunchSymbol.pictureFor(Theme.of(context).brightness);
    if (info == null || info.size.isEmpty) {
      return SizedBox(width: height * 120 / 112, height: height);
    }
    return SizedBox(
      width: height / info.size.height * info.size.width,
      height: height,
      child: FittedBox(
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(
          size: info.size,
          child: CustomPaint(painter: _PicturePainter(info.picture)),
        ),
      ),
    );
  }
}

class _PicturePainter extends CustomPainter {
  _PicturePainter(this.picture);

  final ui.Picture picture;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(picture);

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) =>
      oldDelegate.picture != picture;
}
