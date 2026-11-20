import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_panel.dart';
import 'package:flutter/material.dart';

/// Full-width panel band of the L5 redesign (`.x-band`): an [ExomPanel] with
/// its top and bottom rules, 20 px above and below and no side padding (rows
/// inside pad themselves), with an optional [ExomKicker] on top.
///
/// A band that directly follows another one sets [joinsPrevious] to drop its
/// top rule and share the previous band's bottom rule
/// (`.x-band + .x-band{border-top:0}`).
class ExomBand extends StatelessWidget {
  const ExomBand({
    super.key,
    required this.child,
    this.kicker,
    this.joinsPrevious = false,
  });

  final Widget child;

  /// Small label above the content, padded 20 from the start edge.
  final String? kicker;

  /// True when this band directly follows another [ExomBand].
  final bool joinsPrevious;

  /// Gap between the kicker and the content (not in the sketch).
  static const double kickerGap = ExomSpacing.md;

  @override
  Widget build(BuildContext context) {
    final label = kicker;
    return ExomPanel(
      topRule: !joinsPrevious,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ExomKicker(label),
                  ),
                ),
                const SizedBox(height: kickerGap),
                child,
              ],
            ),
    );
  }
}

/// Featured block (`.x-feat`): `panel` fill with a [ExomRule.bar] top bar in
/// the data colour (lime in dark, `#4F6B00` in light: never lime ink), 16 px
/// above and 20 px below the content and no side padding.
///
/// The sketch draws a 3 px bar; the L5 contract fixes it at [ExomRule.bar]
/// (4 px).
class ExomFeatureBlock extends StatelessWidget {
  const ExomFeatureBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.data, width: ExomRule.bar),
        ),
      ),
      child: child,
    );
  }
}
