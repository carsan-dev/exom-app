import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';

/// Quiet Inicio row (sketch `.r`): icon, title, optional secondary lines and a
/// chevron, separated from its neighbours by a 1 px `rule` hairline on top.
/// Minimum height 56 and full width, so the tap target is always >= 48x48.
///
/// Thin wrapper over the core [ExomFlatRow] (L5 T0.3a), with the icon in the
/// text colour as its leading widget.
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
    return ExomFlatRow(
      leading: Icon(icon, size: 22, color: context.exomPalette.textPrimary),
      title: title,
      subtitles: subtitles,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Stacks [HomeRow]s and closes them with a bottom `rule` hairline (thin
/// wrapper over [ExomFlatRowGroup]).
class HomeRowGroup extends StatelessWidget {
  const HomeRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ExomFlatRowGroup(children: children);
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
