import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Notice row (`.notice`): a 6 dp dot, the [title], the [time] at the end and
/// the [body] under them.
///
/// Unread: the dot is filled in the text colour, the title is 600 and the
/// screen reader hears «No leído» ([AppLocalizations.noticeUnreadA11y]) before
/// the title. Read: the dot keeps its place but is empty and the title is
/// regular. Body and time are in the secondary colour; the body wraps in full
/// (the sketch clamps it to two lines, but L5 text is never cut).
///
/// At least 56 tall, padded 12 above and below, 14 at the start and 20 at the
/// end, with a 1 px `rule` on top. One merged semantics node, a button when
/// [onTap] is set; pressed and disabled behave as [ExomRowSurface].
///
/// An optional [leading] widget (e.g. the `.x-thumb` icon square of a notice
/// type) sits between the dot and the text, 10 after the dot and 14 before the
/// text, aligned to the top. Without it the row is exactly as before.
class ExomNoticeRow extends StatelessWidget {
  const ExomNoticeRow({
    super.key,
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
    this.onTap,
    this.leading,
  });

  final String title;
  final String body;

  /// Already formatted with the active locale (e.g. «10:42», «Ayer»).
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  /// Optional square before the text (decorative: it adds no semantics of
  /// its own unless the caller gives it some).
  final Widget? leading;

  static const double dotSize = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: palette.textPrimary,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
      height: 1.3,
    );
    // `.notice-dot { margin-top: .6em }` of the 16 px title line.
    final dotTop = MediaQuery.textScalerOf(context).scale(16) * 0.6;
    final leadingWidget = leading;
    final dot = Container(
      key: const Key('exom-notice-dot'),
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: unread ? palette.textPrimary : null,
        borderRadius: BorderRadius.circular(dotSize / 2),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: ExomRowSurface(
          onTap: onTap,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: dotTop),
                child: unread
                    ? Semantics(
                        label: AppLocalizations.of(context).noticeUnreadA11y,
                        child: dot,
                      )
                    : ExcludeSemantics(child: dot),
              ),
              const SizedBox(width: 10),
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(title, style: titleStyle)),
                        const SizedBox(width: 10),
                        Text(
                          time,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
