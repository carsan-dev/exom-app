import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:flutter/material.dart';

/// Size of an [ExomTwoLineHeadline]: `.x-h2l` (section) or `.x-h2l-scr`
/// (screen) in the L5 sketch.
enum ExomHeadlineSize { section, screen }

/// Two-line headline of the L5 redesign (`.x-h2l`): Barlow Condensed 800 in
/// upper case, the first line in the text colour and the second in the data
/// colour (the error colour when [isError]).
///
/// Only the painted text is upper case: assistive technology gets one header
/// node with [semanticsLabel] or, by default, `'$first $second'` in its
/// original case (an all-caps label can be read as an acronym; same rule as
/// `HomeTitle`). Each line wraps freely and is never ellipsised.
class ExomTwoLineHeadline extends StatelessWidget {
  const ExomTwoLineHeadline({
    super.key,
    required this.first,
    required this.second,
    this.size = ExomHeadlineSize.section,
    this.semanticsLabel,
    this.isError = false,
  });

  final String first;
  final String second;
  final ExomHeadlineSize size;

  /// Spoken label; defaults to `'$first $second'`.
  final String? semanticsLabel;

  /// Paints the second line in the error colour (caso C3 c).
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final base = switch (size) {
      ExomHeadlineSize.section => ExomType.headline2Section,
      ExomHeadlineSize.screen => ExomType.headline2Screen,
    };
    return Semantics(
      header: true,
      label: semanticsLabel ?? '$first $second',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            first.toUpperCase(),
            style: base.copyWith(color: palette.textPrimary),
          ),
          Text(
            second.toUpperCase(),
            style: base.copyWith(color: isError ? palette.error : palette.data),
          ),
        ],
      ),
    );
  }
}
