import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Kilograms painted in the user's unit (decision D5): «62,5 kg», «137,79 lb».
/// Stored and sent values stay in kilograms; this is presentation only.
class WeightText {
  const WeightText(this.unitSystem, this.decimalSeparator);

  final UnitSystem unitSystem;
  final String decimalSeparator;

  /// Reads the unit preference when an [AppPreferencesCubit] is provided (it
  /// always is in the app, `lib/main.dart`); widget tests that pump a page
  /// alone fall back to kilograms, the only unit before D5. Same rule as the
  /// training detail.
  factory WeightText.of(BuildContext context) {
    UnitSystem unitSystem;
    try {
      unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
        (cubit) => cubit.state.unitSystem,
      );
    } on ProviderNotFoundException {
      unitSystem = UnitSystem.metric;
    }
    return WeightText(
      unitSystem,
      decimalSeparatorFor(Localizations.localeOf(context).languageCode),
    );
  }

  String get symbol => weightUnitSymbol(unitSystem);

  /// «62,5» (no unit).
  String number(double kg) =>
      formatWeightDisplay(kg, unitSystem, decimalSeparator: decimalSeparator);

  /// «62,5 kg» with a no-break space.
  String call(double kg) => '${number(kg)} $symbol';
}

/// One logged set as text: «8 × 60 kg», «45 s · 20 kg», «8 reps.», «60 kg».
/// [withUnit] false drops the weight unit («8 × 62,5», set chips);
/// [withRir] appends « · RIR 2». Returns null when the set carries nothing
/// to show (a set saved without values, or only a RIR when [withRir] is off).
String? setValueLabel(
  AppLocalizations l10n,
  SetPerformance set,
  WeightText weightText, {
  bool withUnit = true,
  bool withRir = false,
}) {
  final kg = set.weightKg;
  final weight = kg == null
      ? null
      : withUnit
      ? weightText(kg)
      : weightText.number(kg);
  final String? main;
  if (set.reps != null && weight != null) {
    main = '${set.reps} × $weight';
  } else {
    final parts = [
      if (set.reps != null) l10n.trainingDetailReps(set.reps!),
      if (set.seconds != null) '${set.seconds} s',
      ?weight,
    ];
    main = parts.isEmpty ? null : parts.join(' · ');
  }
  final rir = withRir && set.rir != null ? l10n.activeExerciseRir(set.rir!) : null;
  if (main == null) return rir;
  return rir == null ? main : '$main · $rir';
}
