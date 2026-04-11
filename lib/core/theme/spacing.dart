import 'package:flutter/widgets.dart';

/// Spacing scale for EXOM. Based on a 4px base unit with an Apple-style
/// dense low-end (4, 8, 12) and generous mid/high (16, 20, 24, 32, 40).
///
/// Use `ExomSpacing.md` instead of hardcoded magic numbers so the
/// vertical/horizontal rhythm stays consistent across the app.
class ExomSpacing {
  const ExomSpacing._();

  /// 2px — hairline separator between glyphs or tiny inline adjustments.
  static const double xxs = 2;

  /// 4px — icon-to-label gap, micro padding.
  static const double xs = 4;

  /// 8px — tight internal padding, chip radius.
  static const double sm = 8;

  /// 12px — compact card content padding, stack gap.
  static const double md = 12;

  /// 16px — default horizontal screen padding, standard card gap.
  static const double lg = 16;

  /// 20px — generous card padding, section gap inside a screen.
  static const double xl = 20;

  /// 24px — section separator, large card padding.
  static const double xxl = 24;

  /// 32px — hero block separator.
  static const double xxxl = 32;

  /// 40px — page-level vertical rhythm between major sections.
  static const double huge = 40;
}

/// Border radius scale — aligned with Apple's 5 / 8 / 11 / 12 / 16 / 24 tiers.
class ExomRadius {
  const ExomRadius._();

  /// 6px — chips, inline tags.
  static const double xs = 6;

  /// 10px — compact buttons, search fields.
  static const double sm = 10;

  /// 14px — standard buttons, inputs.
  static const double md = 14;

  /// 18px — cards default.
  static const double lg = 18;

  /// 24px — sheets, large panels.
  static const double xl = 24;

  /// 28px — hero cards (elevated / featured).
  static const double xxl = 28;

  static BorderRadius allXs() => BorderRadius.circular(xs);
  static BorderRadius allSm() => BorderRadius.circular(sm);
  static BorderRadius allMd() => BorderRadius.circular(md);
  static BorderRadius allLg() => BorderRadius.circular(lg);
  static BorderRadius allXl() => BorderRadius.circular(xl);
  static BorderRadius allXxl() => BorderRadius.circular(xxl);
}
