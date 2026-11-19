import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

/// Quiet Inicio row (sketch `.r`): icon, title, optional secondary lines and a
/// chevron, separated from its neighbours by a 1 px `rule` hairline on top.
/// Minimum height 56 and full width, so the tap target is always >= 48x48.
///
/// Wrap consecutive rows in [HomeRowGroup] to close the list with a bottom
/// rule.
class HomeRow extends StatelessWidget {
  const HomeRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitles = const [],
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final List<String> subtitles;

  /// Replaces the chevron (e.g. a "done" status).
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final trailingWidget =
        trailing ??
        (onTap == null
            ? null
            : Icon(
                Icons.chevron_right,
                size: 22,
                color: palette.textSecondary,
              ));

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.borderSoft, width: 1),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 22, color: palette.textPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: palette.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            for (final line in subtitles)
                              Text(
                                line,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: palette.textSecondary,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (trailingWidget != null) ...[
                        const SizedBox(width: 12),
                        trailingWidget,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacks [HomeRow]s and closes them with a bottom `rule` hairline.
class HomeRowGroup extends StatelessWidget {
  const HomeRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.exomPalette.borderSoft, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Quiet "done" status: text colour + check icon, never lime (plan §6).
class HomeDoneStatus extends StatelessWidget {
  const HomeDoneStatus({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, size: 20, color: palette.textPrimary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
