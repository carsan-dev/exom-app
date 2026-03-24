import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

class WeekDaySelector extends StatelessWidget {
  const WeekDaySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final weekStart = now.subtract(Duration(days: todayIndex));

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        DateTime? selectedDate;
        if (state is HomeLoaded) selectedDate = state.selectedDate;
        if (state is HomeRestDay) selectedDate = state.selectedDate;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final dayDate = weekStart.add(Duration(days: i));
              final isToday = i == todayIndex;
              final isPast = i < todayIndex;
              final isSelected =
                  selectedDate != null &&
                  dayDate.year == selectedDate.year &&
                  dayDate.month == selectedDate.month &&
                  dayDate.day == selectedDate.day;

              return GestureDetector(
                onTap: () {
                  context.read<HomeBloc>().add(HomeDateSelected(dayDate));
                },
                child: _DayCircle(
                  label: _labelForDay(context, dayDate),
                  isToday: isToday,
                  isPast: isPast,
                  isSelected: isSelected,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  String _labelForDay(BuildContext context, DateTime dayDate) {
    if (context.isEnglish) {
      return DateFormat(
        'E',
        'en',
      ).format(dayDate).substring(0, 1).toUpperCase();
    }

    return switch (dayDate.weekday) {
      DateTime.monday => 'L',
      DateTime.tuesday => 'M',
      DateTime.wednesday => 'X',
      DateTime.thursday => 'J',
      DateTime.friday => 'V',
      DateTime.saturday => 'S',
      _ => 'D',
    };
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.label,
    required this.isToday,
    required this.isPast,
    required this.isSelected,
  });

  final String label;
  final bool isToday;
  final bool isPast;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    Color bgColor;
    Color textColor;
    Border? border;

    if (isToday) {
      bgColor = palette.primary;
      textColor = palette.onPrimary;
    } else if (isSelected) {
      bgColor = Colors.transparent;
      textColor = palette.primary;
      border = Border.all(color: palette.primary, width: 2);
    } else if (isPast) {
      bgColor = palette.surfaceVariant;
      textColor = palette.textPrimary;
    } else {
      bgColor = Colors.transparent;
      textColor = palette.textDisabled;
      border = Border.all(color: palette.borderSoft);
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: (isToday || isSelected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
