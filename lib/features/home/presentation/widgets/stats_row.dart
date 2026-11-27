import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

/// Streak, latest weight and latest sleep as rich Inicio rows (L5-E1,
/// sketch `.x-row`): the streak with its days in the date box and «Retos y
/// logros», weight and sleep with their icon. Same data, unit handling and
/// destinations as before.
class StatsRow extends StatelessWidget {
  const StatsRow({
    super.key,
    required this.summary,
    required this.selectedDate,
  });

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final l10n = AppLocalizations.of(context);
    // Same rounding as before (1 decimal); only the decimal separator follows
    // the locale («62,5 kg» in Spanish), as in the training detail.
    final separator = decimalSeparatorFor(
      Localizations.localeOf(context).languageCode,
    );
    String localized(String value) => value.replaceFirst('.', separator);

    Future<void> openMetrics() async {
      await context.push('/profile/metrics');
      if (context.mounted) {
        context.read<HomeBloc>().add(HomeLoadRequested(date: selectedDate));
      }
    }

    final weight = summary.lastWeightKg != null
        ? localized(formatWeightValue(summary.lastWeightKg, unitSystem))
        : '--';
    final sleep = summary.lastSleepHours != null
        ? localized(summary.lastSleepHours!.toStringAsFixed(1))
        : '--';
    final sleepQuality = _sleepQuality(context, summary.lastSleepHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomRichRow(
          leading: ExomRowLeading.date(
            day: formatFigure(context, summary.streakDays),
            label: l10n.homeStreakDaysUnit(summary.streakDays),
          ),
          title: l10n.homeStreakRow(summary.streakDays),
          facts: l10n.homeStreakRowFoot,
          onTap: () => context.push('/challenges'),
        ),
        ExomRichRow(
          leading: const ExomRowLeading.icon(ExomIcons.weight),
          title: '${l10n.weight} · $weight ${weightUnitSymbol(unitSystem)}',
          facts: summary.lastWeightDate == null
              ? null
              : DateFormat('dd/MM/yyyy').format(summary.lastWeightDate!),
          onTap: openMetrics,
        ),
        ExomRichRow(
          leading: const ExomRowLeading.icon(ExomIcons.sleep),
          title: '${l10n.sleep} · $sleep ${l10n.hours}',
          facts: sleepQuality,
          onTap: openMetrics,
        ),
      ],
    );
  }

  String? _sleepQuality(BuildContext context, double? hours) {
    final l10n = AppLocalizations.of(context);
    if (hours == null) return null;
    if (hours >= 8) return l10n.sleepQualityGood;
    if (hours >= 6) return l10n.sleepQualityFair;
    return l10n.sleepQualityLow;
  }
}
