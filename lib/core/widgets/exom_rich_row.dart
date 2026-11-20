import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:flutter/material.dart';

/// Leading square of an [ExomRichRow] (`.x-thumb`, 56x56): an image, a date or
/// an icon.
sealed class ExomRowLeading {
  const ExomRowLeading();

  /// Photo cropped to the square (`object-fit: cover`); decorative.
  const factory ExomRowLeading.image(
    ImageProvider image, {
    AlignmentGeometry alignment,
  }) = ExomRowImage;

  /// Date box (`.x-date`): [day] in Barlow Condensed 800 over a short [label]
  /// (e.g. «nov»), both already formatted with the active locale.
  const factory ExomRowLeading.date({
    required String day,
    required String label,
  }) = ExomRowDate;

  /// Icon on the `raised` fill, in the secondary colour.
  const factory ExomRowLeading.icon(IconData icon) = ExomRowIcon;
}

class ExomRowImage extends ExomRowLeading {
  const ExomRowImage(this.image, {this.alignment = Alignment.center});

  final ImageProvider image;
  final AlignmentGeometry alignment;
}

class ExomRowDate extends ExomRowLeading {
  const ExomRowDate({required this.day, required this.label});

  final String day;
  final String label;
}

class ExomRowIcon extends ExomRowLeading {
  const ExomRowIcon(this.icon);

  final IconData icon;
}

/// Rich row (`.x-row`): a 56x56 [leading] square, a 600 [title], a secondary
/// line of [facts] and an optional [status] (e.g. `ExomSyncStatus`) under
/// them, with a chevron when [onTap] is set.
///
/// At least 72 tall; 20 px at the start, 12 at the end and 12 above and below;
/// 1 px `rule` on top (close a list with `ExomFlatRowGroup`). Pressed and
/// disabled behave as [ExomRowSurface]. One merged semantics node, a button
/// when tappable; the image is decorative. The date box grows with large text
/// instead of cutting it.
class ExomRichRow extends StatelessWidget {
  const ExomRichRow({
    super.key,
    required this.leading,
    required this.title,
    this.facts,
    this.status,
    this.onTap,
  });

  final ExomRowLeading leading;
  final String title;
  final String? facts;
  final Widget? status;
  final VoidCallback? onTap;

  static const double thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final factsText = facts;
    final statusWidget = status;
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: ExomRowSurface(
          onTap: onTap,
          minHeight: 72,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
          // Stretched so the chevron can centre on the whole row (sketch
          // `.x-row-chev{align-self:center}`); the thumbnail stays on top.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: _Leading(leading: leading),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (factsText != null) ...[
                        const SizedBox(height: ExomSpacing.xs),
                        Text(
                          factsText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (statusWidget != null) ...[
                        const SizedBox(height: ExomSpacing.xs),
                        statusWidget,
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Center(
                    child: Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.leading});

  final ExomRowLeading leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    const key = Key('exom-row-leading');
    const size = ExomRichRow.thumbSize;
    switch (leading) {
      case ExomRowImage(:final image, :final alignment):
        return Container(
          key: key,
          width: size,
          height: size,
          color: palette.surfaceElevated,
          child: Image(
            image: image,
            fit: BoxFit.cover,
            alignment: alignment,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        );
      case ExomRowIcon(:final icon):
        return Container(
          key: key,
          width: size,
          height: size,
          decoration: BoxDecoration(color: palette.surfaceElevated),
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: palette.textSecondary),
        );
      case ExomRowDate(:final day, :final label):
        return Container(
          key: key,
          constraints: const BoxConstraints(minWidth: size, minHeight: size),
          padding: const EdgeInsets.all(ExomSpacing.xs),
          decoration: BoxDecoration(
            border: Border.all(
              color: palette.borderSoft,
              width: ExomRule.hairline,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                day,
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 0.85,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: ExomSpacing.xxs),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 13,
                  height: 1.2,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        );
    }
  }
}
