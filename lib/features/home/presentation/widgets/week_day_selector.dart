import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
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
/// completion data).
///
/// L4b-D4: when HomeBloc has the calendar marks of this week, every day shows
/// them under its number instead: a 6 dp dot for a pending session, a 12 dp
/// check for a done one (a different shape, not only a colour) and nothing
/// for a day without session; the day label adds «sesión pendiente» or
/// «sesión hecha». L4b-I7: a pending session on a day before
/// today is a hollow ring of the same size, labelled «sesión no hecha». Without marks the strip is exactly the pre-L4b one. Each
/// slot is at least 48x48 when the strip has room for
/// it (7 x 48 plus the page margins); on narrower screens the margins shrink
/// first and the slots share the full width. Tapping a slot dispatches
/// [HomeDateSelected], as before.
class WeekDaySelector extends StatelessWidget {
  const WeekDaySelector({super.key});

  static const double _pageMargin = 20;

  /// Local midnight of the Monday of [today]'s week. Calendar arithmetic, not
  /// a `Duration` subtracted from a local `DateTime`: around a clock change
  /// that can shift the result by an hour.
  static DateTime weekStartOf(DateTime today) =>
      HomeWeekMarks.weekStartOf(today);

  @override
  Widget build(BuildContext context) {
    final today = HomeClock.todayOf(context);
    final weekStart = weekStartOf(today);
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        DateTime? selectedDate;
        var selectedDone = false;
        HomeWeekMarks? marks;
        if (state is HomeLoaded) {
          selectedDate = state.selectedDate;
          selectedDone =
              state.summary.trainingCompleted &&
              HomeSessionPlan.of(state.summary).hasTraining;
          marks = state.weekMarks;
        }
        if (state is HomeRestDay) {
          selectedDate = state.selectedDate;
          marks = state.weekMarks;
        }
        // Marks of another week (the clock moved on) are not shown.
        if (marks != null &&
            HomeWeekMarks.dayKey(marks.weekStart) !=
                HomeWeekMarks.dayKey(weekStart)) {
          marks = null;
        }

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
                  final mark = marks?.markFor(dayDate);
                  final isDone = mark == null
                      ? isSelected && selectedDone
                      : mark == HomeDayMark.done;

                  var label = homeLongDate(context, dayDate);
                  if (isToday) label = l10n.homeWeekDayToday(label);
                  if (isDone) label = l10n.homeWeekDayDone(label);
                  // L4b-I7: a session not done on a day before today.
                  final isMissed =
                      mark == HomeDayMark.pending && dayDate.isBefore(today);
                  if (isMissed) {
                    label = l10n.homeWeekDayMissed(label);
                  } else if (mark == HomeDayMark.pending) {
                    label = l10n.homeWeekDayPending(label);
                  }

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
                        mark: mark,
                        isMissed: isMissed,
                        markKey: mark == null || mark == HomeDayMark.none
                            ? null
                            : ValueKey(
                                'home-week-mark-${isMissed ? 'missed' : mark.name}-${dayDate.day}',
                              ),
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
    required this.mark,
    required this.isMissed,
    required this.markKey,
    required this.onTap,
  });

  final String letter;
  final String number;
  final bool isToday;
  final bool isSelected;
  final bool isDone;

  /// L4b calendar mark; `null` keeps the pre-L4b check on [isDone].
  final HomeDayMark? mark;

  /// L4b-I7: pending mark of a day before today, drawn as a hollow ring.
  final bool isMissed;
  final Key? markKey;
  final VoidCallback onTap;

  /// L4b-D4 sizes: pending dot and done check.
  static const double _dotSize = 6;
  static const double _checkSize = 12;

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
                      child: switch (mark) {
                        null =>
                          isDone
                              ? Icon(Icons.check, size: 14, color: foreground)
                              : null,
                        HomeDayMark.none => null,
                        HomeDayMark.pending => Center(
                          child: SizedBox.square(
                            key: markKey,
                            dimension: _dotSize,
                            child: DecoratedBox(
                              // Missed: same footprint, outline only, in the
                              // day-number colour (no alarm colour).
                              decoration: isMissed
                                  ? BoxDecoration(
                                      border: Border.all(
                                        color: foreground,
                                        width: 1.5,
                                      ),
                                      shape: BoxShape.circle,
                                    )
                                  : BoxDecoration(
                                      color: secondary,
                                      shape: BoxShape.circle,
                                    ),
                            ),
                          ),
                        ),
                        HomeDayMark.done => Center(
                          child: Icon(
                            key: markKey,
                            Icons.check,
                            size: _checkSize,
                            color: foreground,
                          ),
                        ),
                      },
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
