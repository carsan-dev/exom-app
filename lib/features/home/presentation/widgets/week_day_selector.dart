import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Current week (Monday to Sunday of the clock's today) as seven equal slots.
///
/// Today is outlined; the selected day is filled with the `text` colour (no
/// lime); the selected day shows a check when its summary reports every
/// training done (HomeBloc only loads the selected day, so other days carry no
/// completion data). Each slot is at least 48x48 when the strip has room for
/// it (7 x 48 plus the page margins); on narrower screens the margins shrink
/// first and the slots share the full width. Tapping a slot dispatches
/// [HomeDateSelected], as before.
class WeekDaySelector extends StatelessWidget {
  const WeekDaySelector({super.key});

  static const double _pageMargin = 20;

  @override
  Widget build(BuildContext context) {
    final today = HomeClock.todayOf(context);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        DateTime? selectedDate;
        var selectedDone = false;
        if (state is HomeLoaded) {
          selectedDate = state.selectedDate;
          selectedDone =
              state.summary.trainingCompleted &&
              HomeSessionPlan.of(state.summary).hasTraining;
        }
        if (state is HomeRestDay) selectedDate = state.selectedDate;

        return LayoutBuilder(
          builder: (context, constraints) {
            const needed = 7 * kExomMinTapTarget + 2 * _pageMargin;
            final margin = constraints.maxWidth >= needed
                ? _pageMargin
                : ((constraints.maxWidth - 7 * kExomMinTapTarget) / 2).clamp(
                    0.0,
                    _pageMargin,
                  );
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Row(
                children: List.generate(7, (i) {
                  final dayDate = DateTime(
                    weekStart.year,
                    weekStart.month,
                    weekStart.day + i,
                  );
                  final isToday = isSameDay(dayDate, today);
                  final isSelected =
                      selectedDate != null && isSameDay(dayDate, selectedDate);
                  final isDone = isSelected && selectedDone;

                  var label = homeLongDate(context, dayDate);
                  if (isToday) label = l10n.homeWeekDayToday(label);
                  if (isDone) label = l10n.homeWeekDayDone(label);

                  void select() {
                    context.read<HomeBloc>().add(HomeDateSelected(dayDate));
                  }

                  // One node per day: the visible letter and number are
                  // replaced by the full date label, and the tap action is
                  // declared here because excludeSemantics drops the
                  // InkWell's own action.
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: label,
                      onTap: select,
                      excludeSemantics: true,
                      child: _DaySlot(
                        letter: DateFormat(
                          'EEEEE',
                          languageCode,
                        ).format(dayDate).toUpperCase(),
                        number: '${dayDate.day}',
                        isToday: isToday,
                        isSelected: isSelected,
                        isDone: isDone,
                        onTap: select,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }
}

class _DaySlot extends StatelessWidget {
  const _DaySlot({
    required this.letter,
    required this.number,
    required this.isToday,
    required this.isSelected,
    required this.isDone,
    required this.onTap,
  });

  final String letter;
  final String number;
  final bool isToday;
  final bool isSelected;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final foreground = isSelected ? palette.background : palette.textPrimary;
    final secondary = isSelected ? palette.background : palette.textSecondary;

    // The whole slot is tappable (L3 review F2): the 1 px visual inset sits
    // inside this detector, so the hit area equals the slot and its
    // semantics node instead of being 2 px narrower. Taps on the painted
    // area still reach the InkWell (ripple); only one of the two fires.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: isSelected ? palette.textPrimary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isToday
                ? BorderSide(color: palette.textPrimary, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      letter,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      number,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(
                      height: 16,
                      child: isDone
                          ? Icon(Icons.check, size: 14, color: foreground)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
