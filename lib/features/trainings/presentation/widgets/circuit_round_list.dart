import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// State of one exercise inside the current round of a circuit.
enum CircuitRowState {
  /// Logged in this round; saved on this phone.
  done,

  /// Completed without logging («Completar sin registrar»).
  notLogged,

  /// The exercise to log now.
  now,

  /// Still to do in this round.
  next,
}

/// One exercise of the round: [value] is what was logged («12 × 20»), or the
/// target of the current and the following ones («12 reps»); null shows
/// nothing.
typedef CircuitRoundRow = ({
  Key key,
  String name,
  CircuitRowState state,
  String? value,
});

/// «Esta ronda» of the active circuit (L5-E5, sketch «Circuito activo»: `.x-sh-row`,
/// `.x-rows`, `.x-row`, `.e-now`). The section title in the section style with
/// an optional [summary] («1 de 4 registrados») at the end, then the round's
/// exercises as rows separated by the `rule` colour, at least 72 high and
/// vertical so they survive large text. Each row shows its POSITION in the
/// list as «01», «02»… ([ExomIndexNumber], index + 1, never the exercise's
/// `order`), the name and a line under it:
///  * done: a check in the data colour («hecha» is client data, D19) and the
///    logged values in the text colour; «Guardada en este móvil» stays on the
///    page's status line, never «synced»;
///  * not logged: «Sin registrar», muted;
///  * now: «Ahora» in weight 600 (not lime) and the target, with a 3 dp rule
///    in the text colour on the start edge;
///  * next: «Después» and the target, muted.
///
/// A line that changes crossfades in [ExomMotion.chipCrossfade] (reduced
/// variant with reduced motion), as the set chips of the active exercise.
/// Read-only; the row semantics are unchanged since L3.
class CircuitRoundList extends StatelessWidget {
  const CircuitRoundList({
    super.key,
    required this.title,
    required this.rows,
    this.summary,
  });

  final String title;
  final List<CircuitRoundRow> rows;

  /// Short count at the end of the section title («1 de 4 registrados»).
  final String? summary;

  /// Width of the rule that marks the current row (`.e-now`, inset 3 px).
  static const double nowRuleWidth = 3;

  /// Key of the rule that marks the current row, for tests.
  static const Key nowRuleKey = Key('circuit-row-now-rule');

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final duration = ExomMotion.of(context).chipCrossfade;
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );
    final summaryText = summary;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ExomSpacing.md,
              runSpacing: ExomSpacing.xs,
              children: [
                ExcludeSemantics(
                  child: Text(
                    title.toUpperCase(),
                    style: ExomType.section.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (summaryText != null)
                  Text(
                    summaryText,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      height: 1.4,
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: rule)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++)
                  _row(context, l10n, rows[i], i + 1, duration, rule),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    CircuitRoundRow row,
    int position,
    Duration duration,
    BorderSide rule,
  ) {
    final palette = context.exomPalette;
    final value = row.value;
    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.4,
      color: palette.textSecondary,
    );
    final strongStyle = mutedStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: palette.textPrimary,
    );
    final semantics = switch (row.state) {
      CircuitRowState.done => l10n.circuitRowDoneA11y(
        row.name,
        value ?? l10n.activeExerciseSetDone,
      ),
      CircuitRowState.notLogged => l10n.circuitRowNotLoggedA11y(row.name),
      // Reads the target it paints («Ahora · 12 reps»), like «Después».
      CircuitRowState.now =>
        value == null || value.isEmpty
            ? l10n.circuitRowNowA11y(row.name)
            : l10n.circuitRowNowWithTargetA11y(row.name, value),
      CircuitRowState.next =>
        value == null || value.isEmpty
            ? l10n.circuitRowLaterA11y(row.name)
            : l10n.circuitRowNextA11y(row.name, value),
    };

    final hasValue = value != null && value.isNotEmpty;
    final Widget line = switch (row.state) {
      CircuitRowState.done => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(ExomIcons.check, size: 16, color: palette.data),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value ?? l10n.activeExerciseSetDone,
              style: strongStyle,
            ),
          ),
        ],
      ),
      CircuitRowState.notLogged => Text(
        l10n.circuitNotLogged,
        style: mutedStyle,
      ),
      CircuitRowState.now => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: l10n.activeExerciseSetNow, style: strongStyle),
            if (hasValue) TextSpan(text: ' · $value'),
          ],
        ),
        style: mutedStyle,
      ),
      CircuitRowState.next => Text(
        hasValue ? '${l10n.circuitRowLater} · $value' : l10n.circuitRowLater,
        style: mutedStyle,
      ),
    };

    return Semantics(
      key: row.key,
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: rule)),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExomSpacing.xl,
                  ExomSpacing.md,
                  ExomSpacing.md,
                  ExomSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ExomIndexNumber(position),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            row.name,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: ExomSpacing.xs),
                          AnimatedSwitcher(
                            duration: duration,
                            switchInCurve: Curves.linear,
                            switchOutCurve: Curves.linear,
                            layoutBuilder: (currentChild, previous) => Stack(
                              alignment: AlignmentDirectional.centerStart,
                              children: [...previous, ?currentChild],
                            ),
                            child: KeyedSubtree(
                              key: ValueKey('${row.state.name}-$value'),
                              child: line,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (row.state == CircuitRowState.now)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: nowRuleWidth,
                child: ColoredBox(key: nowRuleKey, color: palette.textPrimary),
              ),
          ],
        ),
      ),
    );
  }
}
