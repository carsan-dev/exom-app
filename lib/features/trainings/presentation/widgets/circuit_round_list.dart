import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
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
/// target for the following ones («12 reps»); null shows nothing.
typedef CircuitRoundRow = ({
  Key key,
  String name,
  CircuitRowState state,
  String? value,
});

/// «Esta ronda» of the active circuit (L3 unit 4): the round's exercises as a
/// quiet list of flat rows separated by the `rule` colour, at least 48 px
/// high and vertical so it survives large text. A logged row shows its
/// values and the device icon («Guardada en este móvil», never «synced»);
/// the current one says «Ahora» in weight 600 (not lime); the following ones
/// show the target muted. A value that changes crossfades in
/// [ExomMotion.chipCrossfade] (reduced variant with reduced motion), as the
/// set chips of the active exercise. Read-only.
class CircuitRoundList extends StatelessWidget {
  const CircuitRoundList({super.key, required this.title, required this.rows});

  final String title;
  final List<CircuitRoundRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final duration = ExomMotion.of(context).chipCrossfade;
    final titleStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: palette.textSecondary,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: Text(title, style: titleStyle)),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.borderSoft)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows) _row(context, l10n, row, duration),
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
    Duration duration,
  ) {
    final palette = context.exomPalette;
    final strong = row.state == CircuitRowState.now;
    final nameStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      height: 1.3,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      color: row.state == CircuitRowState.next
          ? palette.textSecondary
          : palette.textPrimary,
    );
    final valueStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      height: 1.3,
      fontWeight: row.state == CircuitRowState.next
          ? FontWeight.w400
          : FontWeight.w600,
      color: row.state == CircuitRowState.next ||
              row.state == CircuitRowState.notLogged
          ? palette.textSecondary
          : palette.textPrimary,
    );
    final value = switch (row.state) {
      CircuitRowState.now => l10n.activeExerciseSetNow,
      CircuitRowState.notLogged => l10n.circuitNotLogged,
      CircuitRowState.done || CircuitRowState.next => row.value,
    };
    final semantics = switch (row.state) {
      CircuitRowState.done => l10n.circuitRowDoneA11y(
        row.name,
        value ?? l10n.activeExerciseSetDone,
      ),
      CircuitRowState.notLogged => l10n.circuitRowNotLoggedA11y(row.name),
      CircuitRowState.now => l10n.circuitRowNowA11y(row.name),
      CircuitRowState.next =>
        value == null || value.isEmpty
            ? l10n.circuitRowLaterA11y(row.name)
            : l10n.circuitRowNextA11y(row.name, value),
    };

    final valueChild = Row(
      key: ValueKey('${row.state.name}-$value'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null && value.isNotEmpty)
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: valueStyle),
          ),
        if (row.state == CircuitRowState.done) ...[
          const SizedBox(width: 4),
          Icon(
            ExomIcons.phone,
            size: 16,
            color: palette.textSecondary,
          ),
        ],
      ],
    );

    return Semantics(
      key: row.key,
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.borderSoft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(row.name, style: nameStyle)),
            const SizedBox(width: 12),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.linear,
                  switchOutCurve: Curves.linear,
                  layoutBuilder: (currentChild, previous) => Stack(
                    alignment: Alignment.centerRight,
                    children: [...previous, ?currentChild],
                  ),
                  child: valueChild,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
