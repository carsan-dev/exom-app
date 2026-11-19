import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_value_text.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Set chips of the active exercise (sketch «A · Ejercicio activo»): one chip
/// per set; logged sets show their values and the device icon («saved on this
/// phone», never «synced»), the set in progress is outlined and the following
/// ones are muted with the target. A chip that changes crossfades in
/// [ExomMotion.chipCrossfade] (principle 8; the reduced variant with reduced
/// motion). Read-only: logged sets are not edited from here.
class ActiveExerciseSetChips extends StatelessWidget {
  const ActiveExerciseSetChips({
    super.key,
    required this.totalSets,
    required this.completedSets,
    required this.currentSet,
    required this.performances,
    required this.targetLabel,
    required this.weightText,
  });

  final int totalSets;
  final int completedSets;

  /// Set in progress, or null while resting or done.
  final int? currentSet;
  final List<SetPerformance> performances;

  /// «8 reps» for the sets still to do; null hides it.
  final String? targetLabel;
  final WeightText weightText;

  /// Minimum chip width at text scale 1 (sketch: 7.5em).
  static const double minChipWidth = 120;
  static const double gap = 8;

  SetPerformance? _performanceOf(int setNumber) {
    for (final set in performances.reversed) {
      if (set.setNumber == setNumber) return set;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final duration = ExomMotion.of(context).chipCrossfade;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.activeExerciseSetsA11y,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final minWidth = scaler.scale(minChipWidth);
          final columns = math
              .max(1, ((width + gap) / (minWidth + gap)).floor())
              .clamp(1, math.max(1, totalSets));
          final chipWidth = (width - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var set = 1; set <= totalSets; set++)
                SizedBox(
                  width: chipWidth,
                  child: _chip(context, l10n, set, duration),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    AppLocalizations l10n,
    int set,
    Duration duration,
  ) {
    final palette = context.exomPalette;
    final done = set <= completedSets;
    final current = !done && set == currentSet;
    final String value;
    final String semantics;
    if (done) {
      final performance = _performanceOf(set);
      value = performance == null
          ? l10n.activeExerciseSetDone
          : setValueLabel(l10n, performance, weightText, withUnit: false) ??
                setValueLabel(
                  l10n,
                  performance,
                  weightText,
                  withUnit: false,
                  withRir: true,
                ) ??
                l10n.activeExerciseSetDone;
      final spoken = performance == null
          ? null
          : setValueLabel(l10n, performance, weightText, withRir: true);
      semantics = l10n.activeExerciseSetChipDoneA11y(
        set,
        spoken ?? l10n.activeExerciseSetDone,
      );
    } else if (current) {
      value = l10n.activeExerciseSetNow;
      semantics = l10n.activeExerciseSetChipNowA11y(set);
    } else {
      value = targetLabel ?? '';
      semantics = targetLabel == null
          ? l10n.setPerformanceTitle(set)
          : l10n.activeExerciseSetChipNextA11y(set, targetLabel!);
    }

    final keyStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 13,
      height: 1.3,
      color: palette.textSecondary,
    );
    final valueStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      height: 1.3,
      fontWeight: done || current ? FontWeight.w600 : FontWeight.w400,
      color: done || current ? palette.textPrimary : palette.textSecondary,
    );

    final content = Column(
      key: ValueKey('chip-$set-${done ? 'done' : current ? 'now' : 'next'}-$value'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.setPerformanceTitle(set), style: keyStyle),
        if (value.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(value, style: valueStyle)),
              if (done) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.smartphone_outlined,
                  size: 16,
                  color: palette.textSecondary,
                ),
              ],
            ],
          ),
      ],
    );

    return Semantics(
      key: ValueKey('set-chip-$set'),
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: current ? palette.textPrimary : palette.borderSoft,
            width: current ? 1.5 : 1,
          ),
        ),
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          layoutBuilder: (currentChild, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?currentChild],
          ),
          child: content,
        ),
      ),
    );
  }
}
