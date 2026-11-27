import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:flutter/material.dart';

/// Numbered section header (`.x-sh`, `.x-sh-row`): a hairline on top, the
/// [ExomIndexNumber] and the title ([ExomType.section], upper case painted),
/// with an optional [trailing] widget (a link, a count) at the end.
///
/// Padding is the sketch's 18 / 20 / 6. The title wraps with larger text, never
/// cut; the trailing widget drops below it when the row is full (`flex-wrap`).
/// Assistive technology gets one header node with the original [title]; the
/// index is decorative.
class ExomNumberedSectionHeader extends StatelessWidget {
  const ExomNumberedSectionHeader({
    super.key,
    required this.n,
    required this.title,
    this.trailing,
  });

  final int n;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final heading = Semantics(
      header: true,
      label: title,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ExomIndexNumber(n),
          SizedBox(width: ExomType.section.fontSize! * 0.5),
          Flexible(
            child: Text(
              title.toUpperCase(),
              style: ExomType.section.copyWith(color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
    final end = trailing;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: palette.borderSoft,
              width: ExomRule.hairline,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExomSpacing.xl,
            18,
            ExomSpacing.xl,
            6,
          ),
          child: end == null
              ? heading
              : Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: ExomSpacing.md,
                  children: [heading, end],
                ),
        ),
      ),
    );
  }
}
