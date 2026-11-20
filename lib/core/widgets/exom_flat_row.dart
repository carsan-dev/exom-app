import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shared surface of the flat L5 rows (sketch `.r`): a 1 px `rule` hairline on
/// top, a minimum height ([minHeight], 56 by default so the full-width tap
/// target is always >= 48x48) and padded content.
///
/// When [onTap] is set the row reacts to the press with the `raised` fill and
/// back on release, without ripple. The sketch eases the fill over
/// [pressFade] (90 ms, `base.css` `.r`); with reduced motion it switches at
/// once, as motion M6 asks («filas a elevado al instante»). Without [onTap] it
/// is inert: no press fill and no tap action.
///
/// Semantics are left to the caller (button, toggle, merged label...).
class ExomRowSurface extends StatefulWidget {
  const ExomRowSurface({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight = 56,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  /// Duration of the press fill in standard motion (zero when reduced).
  static const Duration pressFade = Duration(milliseconds: 90);

  @override
  State<ExomRowSurface> createState() => _ExomRowSurfaceState();
}

class _ExomRowSurfaceState extends State<ExomRowSurface> {
  bool _pressed = false;

  @override
  void didUpdateWidget(ExomRowSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
  }

  void _onHighlightChanged(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final interactive = widget.onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: interactive ? _onHighlightChanged : null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        // A tween over the fill only: an AnimatedContainer would also pad the
        // content by the border width and move every row by 1 px.
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: interactive && _pressed
                ? palette.surfaceElevated
                : palette.surfaceElevated.withValues(alpha: 0),
          ),
          duration: PerformanceProfile.animationDuration(
            context,
            ExomRowSurface.pressFade,
          ),
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
          builder: (context, fill, child) {
            // Unpressed is the same colour fully transparent: paint no fill.
            final visible = fill != null && fill.a > 0;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: visible ? fill : null,
                border: Border(
                  top: BorderSide(
                    color: palette.borderSoft,
                    width: ExomRule.hairline,
                  ),
                ),
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Flat row (`.r`): optional [leading] (an icon in the text colour), [title],
/// optional secondary [subtitles] and a [trailing] widget that replaces the
/// default chevron. Generalises the Inicio `HomeRow`.
///
/// States: normal; pressed (raised fill at once, see [ExomRowSurface]);
/// disabled when [onTap] is null (no chevron, no press fill, not a button).
/// The whole row is one merged semantics node, a button when tappable. Text
/// wraps, never ellipsised.
///
/// Wrap consecutive rows in [ExomFlatRowGroup] to close the list with a bottom
/// rule.
class ExomFlatRow extends StatelessWidget {
  const ExomFlatRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitles = const [],
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final String title;
  final List<String> subtitles;

  /// Replaces the chevron (e.g. a "done" status).
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final leadingWidget = leading;
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
        child: ExomRowSurface(
          onTap: onTap,
          child: Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: 12),
              ],
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
    );
  }
}

/// Stacks flat rows ([ExomFlatRow], [ExomValueRow], [ExomSwitchRow]) and closes
/// them with a bottom `rule` hairline (`.rows`).
///
/// Set [bottomRule] to false when the group sits in an `ExomFeatureBlock`
/// (`.x-feat .rows{border-bottom:0}`: the block closes the list itself).
class ExomFlatRowGroup extends StatelessWidget {
  const ExomFlatRowGroup({
    super.key,
    required this.children,
    this.bottomRule = true,
  });

  final List<Widget> children;

  /// Whether the group closes with the bottom hairline.
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: bottomRule
              ? BorderSide(
                  color: context.exomPalette.borderSoft,
                  width: ExomRule.hairline,
                )
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Value row (`.r` + `.rv`): [label] at the start in the text colour, [value]
/// at the end in the secondary colour, taking at most half of the row and
/// wrapping inside it. Not interactive; read as one node.
class ExomValueRow extends StatelessWidget {
  const ExomValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.3);
    final palette = context.exomPalette;
    return MergeSemantics(
      child: ExomRowSurface(
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: style?.copyWith(color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: style?.copyWith(color: palette.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch row (`.r` + `.switch`): [label] and the square switch of the L5
/// sketch. The whole row toggles [value] through [onChanged].
///
/// States:
/// * on: switch filled in the text colour with a background-coloured knob at
///   the end; off: secondary outline with a secondary knob at the start. Never
///   lime, in either theme.
/// * busy: [onChanged] null. A small progress indicator sits before the switch
///   (read as «En curso»), the row cannot be toggled and is announced as
///   disabled while keeping its toggled state.
/// * error: [errorText] under the row in the error colour, in its own live
///   region so it is announced once (the row itself is not a live region).
///   Painted with its own [Text]: unify with `ExomInlineMessage` (T0.3b)
///   when that component exists.
///
/// Semantics: one merged node with the toggled and enabled states and the
/// label. Tap target: the full-width row, at least 56 tall.
class ExomSwitchRow extends StatelessWidget {
  const ExomSwitchRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.errorText,
  });

  final String label;
  final bool value;

  /// Null while busy (the switch shows an indicator and ignores taps).
  final ValueChanged<bool>? onChanged;

  /// Inline error shown under the row.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final change = onChanged;
    final error = errorText;
    final row = MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: change != null,
        child: ExomRowSurface(
          onTap: change == null ? null : () => change(!value),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: palette.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (change == null) ...[
                Semantics(
                  label: AppLocalizations.of(context).buttonBusyA11y,
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ExcludeSemantics(child: ExomSquareSwitch(value: value)),
            ],
          ),
        ),
      ),
    );
    if (error == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.error,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The square switch of the L5 sketch (`.switch`): 52x32, 1.5 px outline,
/// radius [ExomRadius.control]; a 21x21 knob (radius 2) 4 px inside the
/// outline. Visual only: [ExomSwitchRow] owns the gesture and semantics.
class ExomSquareSwitch extends StatelessWidget {
  const ExomSquareSwitch({super.key, required this.value});

  final bool value;

  /// Knob travel of the sketch (`transition: transform 90ms ease-out`).
  static const Duration travel = Duration(milliseconds: 90);

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final outline = value ? palette.textPrimary : palette.textSecondary;
    return Container(
      key: const Key('exom-switch-track'),
      width: 52,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? palette.textPrimary : null,
        border: Border.all(color: outline, width: ExomRule.outline),
        borderRadius: BorderRadius.circular(ExomRadius.control),
      ),
      child: AnimatedAlign(
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        duration: PerformanceProfile.animationDuration(context, travel),
        curve: Curves.easeOut,
        child: Container(
          key: const Key('exom-switch-knob'),
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: value ? palette.background : palette.textSecondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
