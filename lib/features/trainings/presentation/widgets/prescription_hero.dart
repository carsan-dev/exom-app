import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// Same rules as the private `_PrescriptionTarget` of
// `active_exercise_page.dart` (L3 unit 3), made public for the active circuit
// (L3 unit 4). Since L5-E3a the exercise page paints its hero with
// [PrescriptionHero] and [PrescriptionHeroSkin.l5]; it keeps its private
// target because that one also reads the saved total of a timed set
// (deviation DV-L3-U4-2, narrowed).

/// Target of a prescription for the hero numeral, the round list and the
/// sheet prefill: a fixed value or a range, in reps or in time.
class PrescriptionTarget {
  const PrescriptionTarget({
    required this.timeUnit,
    this.value,
    this.max,
    this.seconds,
  });

  /// Null for reps.
  final TimePerformanceUnit? timeUnit;

  /// Number shown (reps, seconds or minutes); null when the prescription is
  /// free text.
  final int? value;

  /// Upper end of a range («8–10»).
  final int? max;

  /// Timed prescriptions: total seconds (sheet prefill).
  final int? seconds;

  static final RegExp _leading = RegExp(r'^\s*(\d+)(?:\s*[-–]\s*(\d+))?');

  factory PrescriptionTarget.of(TrainingExerciseEntity exercise) {
    final timeUnit = timePerformanceUnitForExercise(exercise);
    final match = _leading.firstMatch(exercise.repsOrDuration);
    final textValue = int.tryParse(match?.group(1) ?? '');
    final textMax = int.tryParse(match?.group(2) ?? '');
    if (timeUnit == null) {
      if (exercise.targetValue != null) {
        return PrescriptionTarget(timeUnit: null, value: exercise.targetValue);
      }
      if (exercise.targetValueMin != null && exercise.targetValueMax != null) {
        return PrescriptionTarget(
          timeUnit: null,
          value: exercise.targetValueMin,
          max: exercise.targetValueMax,
        );
      }
      return PrescriptionTarget(timeUnit: null, value: textValue, max: textMax);
    }
    final minutesText =
        exercise.measureType == null && timeUnit == TimePerformanceUnit.minutes;
    final total =
        exercise.targetValue ??
        (textValue == null ? null : textValue * (minutesText ? 60 : 1));
    if (total == null) {
      if (exercise.targetValueMin != null && exercise.targetValueMax != null) {
        final inMinutes =
            timeUnit == TimePerformanceUnit.minutes &&
            exercise.targetValueMin! % 60 == 0 &&
            exercise.targetValueMax! % 60 == 0;
        return PrescriptionTarget(
          timeUnit: inMinutes
              ? TimePerformanceUnit.minutes
              : TimePerformanceUnit.seconds,
          value: inMinutes
              ? exercise.targetValueMin! ~/ 60
              : exercise.targetValueMin,
          max: inMinutes
              ? exercise.targetValueMax! ~/ 60
              : exercise.targetValueMax,
          seconds: exercise.targetValueMin,
        );
      }
      return PrescriptionTarget(timeUnit: timeUnit);
    }
    final inMinutes = timeUnit == TimePerformanceUnit.minutes && total % 60 == 0;
    return PrescriptionTarget(
      timeUnit: inMinutes
          ? TimePerformanceUnit.minutes
          : TimePerformanceUnit.seconds,
      value: inMinutes ? total ~/ 60 : total,
      seconds: total,
    );
  }

  /// Reps or seconds the sheet starts from when nothing else applies.
  int? get count => timeUnit == null ? value : seconds;

  /// «8», «8–10».
  String? get numeral {
    final v = value;
    if (v == null) return null;
    final m = max;
    return m == null ? '$v' : '$v–$m';
  }

  String unitLabel(AppLocalizations l10n) => switch (timeUnit) {
    null => l10n.activeExerciseUnitReps,
    TimePerformanceUnit.seconds => l10n.activeExerciseUnitSeconds,
    TimePerformanceUnit.minutes => l10n.activeExerciseUnitMinutes,
  };

  /// «8 reps», «45 s», «10 min»; null for free-text prescriptions.
  String? shortLabel(AppLocalizations l10n) {
    final n = numeral;
    return n == null ? null : '$n ${unitLabel(l10n)}';
  }
}

/// Look of a [PrescriptionHero].
enum PrescriptionHeroSkin {
  /// L3: the target in the text colour up to 96 px, the unit in capitals and
  /// the RIR in body text beside it (the active circuit until it is
  /// repainted).
  l3,

  /// L5 (`e-migradas.html`, «Ejercicio activo»; `.x-hero-140`): the target
  /// at 140 in the data colour with its unit small beside the figure
  /// (`.x-u`), and at its side the RIR in the display face (`.x-hero-d`)
  /// over «objetivo de la serie» (`.x-hero-f`).
  l5,
}

/// Hero of an executing state (sketch «A · Ejercicio activo»): the target in
/// the display face, its unit and the target RIR beside it ([skin]). Free
/// text prescriptions are shown as they are.
class PrescriptionHero extends StatelessWidget {
  const PrescriptionHero({
    super.key,
    required this.target,
    required this.targetRir,
    required this.prescription,
    this.numeralKey,
    this.skin = PrescriptionHeroSkin.l3,
  });

  final PrescriptionTarget target;
  final int? targetRir;
  final String prescription;

  /// Key of the numeral text (tests).
  final Key? numeralKey;

  /// Look of the hero; the L3 one by default.
  final PrescriptionHeroSkin skin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final numeral = target.numeral;
    if (skin == PrescriptionHeroSkin.l5 && numeral != null) {
      return _l5(context, l10n, numeral);
    }
    final display = TextStyle(
      fontFamily: AppTheme.displayFontFamily,
      fontWeight: FontWeight.w800,
      color: palette.textPrimary,
      letterSpacing: -0.44,
      height: 1.0,
    );
    if (numeral == null) {
      return Text(
        prescription,
        style: display.copyWith(fontSize: 44, height: 0.95),
      );
    }
    final spoken = [
      ?target.shortLabel(l10n),
      if (targetRir != null) l10n.activeExerciseRir(targetRir!),
    ].join(' · ');
    return Semantics(
      container: true,
      label: l10n.activeExerciseTargetA11y(spoken),
      excludeSemantics: true,
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Text(
              numeral,
              key: numeralKey,
              maxLines: 1,
              style: display.copyWith(
                fontSize: 96,
                height: 0.9,
                letterSpacing: -1.92,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.unitLabel(l10n).toUpperCase(),
                  style: display.copyWith(fontSize: 22),
                ),
                if (targetRir != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.activeExerciseRir(targetRir!),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _l5(BuildContext context, AppLocalizations l10n, String numeral) {
    final palette = context.exomPalette;
    final fontSize = ExomType.hero140.fontSize!;
    final spoken = [
      ?target.shortLabel(l10n),
      if (targetRir != null) l10n.activeExerciseRir(targetRir!),
    ].join(' · ');
    return Semantics(
      container: true,
      label: l10n.activeExerciseTargetA11y(spoken),
      excludeSemantics: true,
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.bottomStart,
            child: Padding(
              // Room for the ink of round digits below the tight line box
              // (same allowance as ExomNumeral).
              padding: EdgeInsets.only(bottom: fontSize * 0.025),
              child: Text.rich(
                TextSpan(
                  children: exomFigureSpans(
                    value: numeral,
                    unit: target.unitLabel(l10n),
                    fontSize: fontSize,
                  ),
                ),
                key: numeralKey,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: ExomType.hero140.copyWith(color: palette.data),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: ExomSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (targetRir != null) ...[
                  Text(
                    l10n.activeExerciseRir(targetRir!).toUpperCase(),
                    style: ExomType.headline2Section.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  l10n.activeExerciseTargetCaption,
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
        ],
      ),
    );
  }
}
