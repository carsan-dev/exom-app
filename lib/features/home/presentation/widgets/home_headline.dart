import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Screen title of Inicio (sketch `.t1`): Barlow Condensed 800, uppercase,
/// 44 logical px, line height .95, scaled with the platform text size. It
/// wraps up to 3 lines at the default text size and up to 4 lines with larger
/// text; only a name longer than that is ellipsised, so the session block can
/// never push the rest of Inicio out of reach. Only the painted text is
/// uppercase: screen readers get [text] in its original case (an all-caps
/// label can be read as an acronym).
class HomeTitle extends StatelessWidget {
  const HomeTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final scaled = MediaQuery.textScalerOf(context).scale(1) > 1;
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Text(
        text.toUpperCase(),
        maxLines: scaled ? 4 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTheme.displayFontFamily,
          fontSize: 44,
          fontWeight: FontWeight.w800,
          height: 0.95,
          letterSpacing: -0.88,
          color: palette.textPrimary,
        ),
      ),
    );
  }
}

/// Muted date line under the title: localized weekday, day and month. For a
/// day other than today it starts with the relative label («Mañana · …»).
class HomeDateLine extends StatelessWidget {
  const HomeDateLine({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final dateText = homeLongDate(context, date);
    final today = HomeClock.todayOf(context);
    final text = isSameDay(today, date)
        ? dateText
        : '${homeRelativeLabel(context, date, today: today)} · $dateText';
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: palette.textSecondary,
        fontSize: 14,
        height: 1.35,
      ),
    );
  }
}

/// «Miércoles 18 de noviembre» / «Wednesday November 18».
String homeLongDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).languageCode;
  final dayName = DateFormat('EEEE', locale).format(date);
  final dayMonth = locale == 'en'
      ? DateFormat('MMMM d', locale).format(date)
      : DateFormat('d \'de\' MMMM', locale).format(date);
  final capitalDay = dayName[0].toUpperCase() + dayName.substring(1);
  return '$capitalDay $dayMonth';
}

/// Relative label of [date] against [today] («Hoy», «Mañana», «Hace 3 días»…).
String homeRelativeLabel(
  BuildContext context,
  DateTime date, {
  required DateTime today,
}) {
  final todayNorm = DateTime(today.year, today.month, today.day);
  final dateNorm = DateTime(date.year, date.month, date.day);
  final diff = dateNorm.difference(todayNorm).inDays;
  final l10n = AppLocalizations.of(context);

  switch (diff) {
    case 0:
      return l10n.todayLabel;
    case 1:
      return l10n.tomorrowLabel;
    case 2:
      return l10n.dayAfterTomorrowLabel;
    case -1:
      return l10n.yesterdayLabel;
    case -2:
      return l10n.twoDaysAgoLabel;
    default:
      if (diff > 0) {
        return l10n.inDaysLabel(diff);
      }
      return l10n.daysAgoLabel(diff.abs());
  }
}
