import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

class WeekDaySelector extends StatelessWidget {
  const WeekDaySelector({super.key});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // Monday = 0

    // Compute start of current week (Monday)
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
              final isSelected = selectedDate != null &&
                  dayDate.year == selectedDate.year &&
                  dayDate.month == selectedDate.month &&
                  dayDate.day == selectedDate.day;

              return GestureDetector(
                onTap: () {
                  context
                      .read<HomeBloc>()
                      .add(HomeDateSelected(dayDate));
                },
                child: _DayCircle(
                  label: _labels[i],
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
}

class _DayCircle extends StatelessWidget {
  final String label;
  final bool isToday;
  final bool isPast;
  final bool isSelected;

  const _DayCircle({
    required this.label,
    required this.isToday,
    required this.isPast,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;

    if (isToday) {
      bgColor = AppColors.primary;
      textColor = AppColors.textOnPrimary;
    } else if (isSelected) {
      bgColor = Colors.transparent;
      textColor = AppColors.primary;
      border = Border.all(color: AppColors.primary, width: 2);
    } else if (isPast) {
      bgColor = AppColors.surfaceVariant;
      textColor = AppColors.textPrimary;
    } else {
      bgColor = Colors.transparent;
      textColor = AppColors.textDisabled;
      border = Border.all(color: AppColors.borderSoft);
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
            fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
