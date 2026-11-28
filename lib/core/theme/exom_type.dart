import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/painting.dart';

/// Type styles of the L5 redesign (docs/plans/rediseno-app-l5-contrato-v2.md,
/// T0.1).
///
/// Display styles are Barlow Condensed 800; the kicker is DM Sans. None sets a
/// colour (the theme or the widget provides it). Upper case is painted by the
/// widget, never applied to the text here, so assistive technology keeps the
/// original string.
class ExomType {
  const ExomType._();

  static const String _display = AppTheme.displayFontFamily;

  static const TextStyle screenTitle = TextStyle(
    fontFamily: _display,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 0.95,
    letterSpacing: -0.88, // -.02em
  );

  /// Two-line headline, section size.
  static const TextStyle headline2Section = TextStyle(
    fontFamily: _display,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 0.95,
    letterSpacing: -0.56, // -.02em
  );

  /// Two-line headline, screen size.
  static const TextStyle headline2Screen = TextStyle(
    fontFamily: _display,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 0.95,
    letterSpacing: -0.88, // -.02em
  );

  /// Section header.
  static const TextStyle section = TextStyle(
    fontFamily: _display,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.22, // -.01em
  );

  static final TextStyle hero64 = _hero(64);
  static final TextStyle hero96 = _hero(96);
  static final TextStyle hero120 = _hero(120);
  static final TextStyle hero140 = _hero(140);

  /// Small label above content: DM Sans 13 / 600 with wide tracking (.08em).
  static const TextStyle kicker = TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 1.04,
  );
}

/// Protagonist numeral: tight height and tracking from the sketch
/// (`.x-hero-n`: line-height .78, letter-spacing -.035em).
TextStyle _hero(double size) => TextStyle(
  fontFamily: AppTheme.displayFontFamily,
  fontSize: size,
  fontWeight: FontWeight.w800,
  height: 0.78,
  letterSpacing: -0.035 * size,
);
