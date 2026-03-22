import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class WeekDaySelector extends StatelessWidget {
  const WeekDaySelector({super.key});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // Monday = 0

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final isToday = i == todayIndex;
          final isPast = i < todayIndex;

          return GestureDetector(
            onTap: isToday
                ? null
                : () => context.go('/calendar'),
            child: _DayCircle(
              label: _labels[i],
              isToday: isToday,
              isPast: isPast,
            ),
          );
        }),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  final String label;
  final bool isToday;
  final bool isPast;

  const _DayCircle({
    required this.label,
    required this.isToday,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    if (isToday) {
      bgColor = AppColors.primary;
      textColor = AppColors.textOnPrimary;
    } else if (isPast) {
      bgColor = AppColors.surfaceVariant;
      textColor = AppColors.textPrimary;
    } else {
      bgColor = Colors.transparent;
      textColor = AppColors.textDisabled;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: !isToday && !isPast
            ? Border.all(color: AppColors.borderSoft)
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
