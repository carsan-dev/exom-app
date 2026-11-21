import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:flutter/material.dart';

/// Kind of an [ExomInlineMessage].
enum ExomMessageKind { error, pendiente, ok, info }

/// Inline message of the L5 redesign (`.x-alert`, `.msg-*`): icon, title, an
/// optional body and an optional action link.
///
/// Colour by kind: `error` in `palette.error` with a 2 px leading edge
/// (`.x-alert`); `pendiente` in the semantic `warning`; `ok` (a system state:
/// confirmed) in the text colour with a check, never lime (D19); `info` in the
/// secondary text colour. Icon and text always say the kind, never colour
/// alone.
///
/// Announced once: the icon, title and body form the only `liveRegion` node.
/// The action sits outside it as its own link (no nested live region, L4-I26b)
/// and appears only when both [actionLabel] and [onAction] are given.
class ExomInlineMessage extends StatelessWidget {
  const ExomInlineMessage({
    super.key,
    required this.kind,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final ExomMessageKind kind;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Icon size at text scale 1.0 and the gap to the text column.
  static const double _iconBase = 18;
  static const double _iconGap = 8;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final (IconData icon, Color colour) = switch (kind) {
      ExomMessageKind.error => (ExomIcons.error, palette.error),
      ExomMessageKind.pendiente => (ExomIcons.time, semantic.warning),
      ExomMessageKind.ok => (ExomIcons.check, palette.textPrimary),
      ExomMessageKind.info => (ExomIcons.info, palette.textSecondary),
    };
    final iconSize = MediaQuery.textScalerOf(context).scale(_iconBase);
    final bodyText = body;
    final label = actionLabel;
    final onTap = onAction;

    final message = Semantics(
      liveRegion: true,
      container: true,
      label: bodyText == null ? title : '$title. $bodyText',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: iconSize, color: colour),
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: colour,
                  ),
                ),
                if (bodyText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    bodyText,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        message,
        if (label != null && onTap != null)
          Padding(
            // Same column as the title: the scaled icon plus its gap.
            padding: EdgeInsetsDirectional.only(start: iconSize + _iconGap),
            child: ExomTextLink(label: label, onTap: onTap),
          ),
      ],
    );

    if (kind != ExomMessageKind.error) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: palette.error, width: ExomRule.replyEdge),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 4),
        child: content,
      ),
    );
  }
}
