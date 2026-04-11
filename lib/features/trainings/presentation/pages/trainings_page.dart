import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/injection_container.dart';

class TrainingsPage extends StatelessWidget {
  const TrainingsPage({super.key, this.selectedDate});

  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<TrainingBloc>()..add(TrainingsLoadRequested(date: selectedDate)),
      child: _TrainingsView(selectedDate: selectedDate),
    );
  }
}

class _TrainingsView extends StatelessWidget {
  const _TrainingsView({this.selectedDate});

  final String? selectedDate;

  String _dateLabel(BuildContext context, String resolvedDate) {
    final l10n = AppLocalizations.of(context);
    if (selectedDate == null) return l10n.todayLabel.toLowerCase();
    final parsed = DateTime.tryParse(resolvedDate);
    if (parsed == null) return l10n.selectedDateLabel;
    final now = DateTime.now();
    final isToday =
        parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (isToday) return l10n.todayLabel.toLowerCase();
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingBloc, TrainingState>(
      builder: (context, state) {
        if (state is TrainingLoading || state is TrainingInitial) {
          return const _TrainingsLoadingView();
        }
        if (state is TrainingError) {
          return ErrorWidget2(
            message: state.message,
            onRetry: () => context.read<TrainingBloc>().add(
              TrainingsLoadRequested(
                date: state.selectedDate ?? selectedDate,
                historyDate:
                    state.historyDate ?? state.selectedDate ?? selectedDate,
              ),
            ),
          );
        }
        if (state is TrainingNoContent) {
          final l10n = AppLocalizations.of(context);
          return EmptyWidget(
            message: l10n.noTrainingsAssigned,
            subtitle: l10n.noTrainingsAssignedSubtitle,
            icon: Icons.fitness_center_outlined,
          );
        }
        if (state is TrainingsLoaded) {
          return _buildContent(
            context,
            state,
            _dateLabel(context, state.selectedDate),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    TrainingsLoaded state,
    String dateLabel,
  ) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<TrainingBloc>().add(
          TrainingsLoadRequested(
            date: state.selectedDate,
            historyDate: state.historyDate,
          ),
        );
      },
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (state.todayTraining != null) ...[
            _SectionHeader(
              title: selectedDate == null
                  ? l10n.todaysTrainingTitle
                  : '${l10n.training} $dateLabel',
            ),
            _TodayTrainingBanner(
              training: state.todayTraining!,
              selectedDate: state.selectedDate,
              historyDate: state.historyDate,
            ),
            const SizedBox(height: 8),
          ] else ...[
            _SectionHeader(
              title: selectedDate == null ? l10n.todayLabel : dateLabel,
            ),
            _NoTrainingToday(selectedDate: state.selectedDate),
          ],
          _SectionHeader(
            title: l10n.history,
            trailing: _HistoryMonthSelector(
              visibleMonth: DateTime.parse(state.historyDate),
              canGoNext: !_isCurrentMonth(DateTime.parse(state.historyDate)),
              onPrevious: () {
                final previous = _addMonths(
                  DateTime.parse(state.historyDate),
                  -1,
                );
                context.read<TrainingBloc>().add(
                  TrainingsLoadRequested(
                    date: state.selectedDate,
                    historyDate: _storageDate(_startOfMonth(previous)),
                  ),
                );
              },
              onNext: _isCurrentMonth(DateTime.parse(state.historyDate))
                  ? null
                  : () {
                      final next = _addMonths(
                        DateTime.parse(state.historyDate),
                        1,
                      );
                      context.read<TrainingBloc>().add(
                        TrainingsLoadRequested(
                          date: state.selectedDate,
                          historyDate: _storageDate(_startOfMonth(next)),
                        ),
                      );
                    },
            ),
          ),
          if (state.history.isEmpty)
            EmptyWidget(
              message: l10n.noActivitiesThisMonth,
              subtitle: l10n.noActivitiesThisMonthSubtitle,
              icon: Icons.history_toggle_off_rounded,
            )
          else
            ...state.history.map(
              (entry) => _TrainingHistoryListItem(
                entry: entry,
                selectedDate: state.selectedDate,
                historyDate: state.historyDate,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainingsLoadingView extends StatelessWidget {
  const _TrainingsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      children: const [
        _TrainingsSectionHeaderSkeleton(),
        _TodayTrainingBannerSkeleton(),
        SizedBox(height: 8),
        _TrainingsSectionHeaderSkeleton(showSelector: true, width: 84),
        _TrainingHistorySkeletonCard(),
        _TrainingHistorySkeletonCard(),
        _TrainingHistorySkeletonCard(),
      ],
    );
  }
}

class _TrainingsSectionHeaderSkeleton extends StatelessWidget {
  const _TrainingsSectionHeaderSkeleton({
    this.width = 132,
    this.showSelector = false,
  });

  final double width;
  final bool showSelector;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          ShimmerCard(
            height: 16,
            width: width,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          const Spacer(),
          if (showSelector)
            const ShimmerCard(
              height: 32,
              width: 118,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
        ],
      ),
    );
  }
}

class _TodayTrainingBannerSkeleton extends StatelessWidget {
  const _TodayTrainingBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Row(
        children: [
          const ShimmerCard(
            height: 56,
            width: 56,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerCard(
                      height: 18,
                      width: 68,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    SizedBox(width: 8),
                    ShimmerCard(
                      height: 14,
                      width: 54,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ShimmerCard(
                  height: 20,
                  width: 180,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerCard(
                      height: 14,
                      width: 72,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(width: 12),
                    ShimmerCard(
                      height: 14,
                      width: 92,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerCard(
            height: 18,
            width: 18,
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
        ],
      ),
    );
  }
}

class _TrainingHistorySkeletonCard extends StatelessWidget {
  const _TrainingHistorySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerCard(
                height: 14,
                width: 92,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              Spacer(),
              ShimmerCard(
                height: 24,
                width: 84,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
          SizedBox(height: 12),
          ShimmerCard(
            height: 18,
            width: 172,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              ShimmerCard(
                height: 16,
                width: 72,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(width: 8),
              ShimmerCard(
                height: 14,
                width: 54,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _trainingTypeColor(BuildContext context, String type) {
  final palette = context.exomPalette;
  final semantic = context.exomSemantic;

  switch (type.toUpperCase()) {
    case 'FUERZA':
      return palette.primary;
    case 'CARDIO':
      return semantic.info;
    case 'HIIT':
      return semantic.accent;
    case 'FLEXIBILIDAD':
      return semantic.warning;
    default:
      return palette.textDisabled;
  }
}

String _historyDateLabel(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat('EEE d MMM', locale).format(date);
}

String _storageDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime _addMonths(DateTime date, int monthDelta) {
  return DateTime(date.year, date.month + monthDelta, 1);
}

bool _isCurrentMonth(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month;
}

String _historyMonthLabel(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat('MMM yyyy', locale).format(date);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _HistoryMonthSelector extends StatelessWidget {
  const _HistoryMonthSelector({
    required this.visibleMonth,
    required this.canGoNext,
    required this.onPrevious,
    this.onNext,
  });

  final DateTime visibleMonth;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.glassBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.glassBorder.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              _historyMonthLabel(context, visibleMonth),
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _MonthArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return IconButton(
      onPressed: onTap,
      iconSize: 18,
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        icon,
        color: onTap == null ? palette.textDisabled : palette.primary,
      ),
    );
  }
}

class _TodayTrainingBanner extends StatelessWidget {
  const _TodayTrainingBanner({
    required this.training,
    this.selectedDate,
    required this.historyDate,
  });

  final TrainingEntity training;
  final String? selectedDate;
  final String historyDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final color = _trainingTypeColor(context, training.type);

    return TappableScale(
      onTap: () async {
        final dateQuery = selectedDate != null ? '?date=$selectedDate' : '';
        await context.push('/trainings/${training.id}$dateQuery');
        if (context.mounted) {
          context.read<TrainingBloc>().add(
            TrainingsLoadRequested(
              date: selectedDate,
              historyDate: historyDate,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: GlassDecoration.accentCard(color),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          training.type,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        training.level,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    training.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: palette.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${training.estimatedDurationMin ?? '--'} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.list_outlined,
                        color: palette.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${training.exercises.length} ${l10n.exercises}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _NoTrainingToday extends StatelessWidget {
  const _NoTrainingToday({this.selectedDate});

  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: GlassDecoration.card(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.glassBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: palette.glassBorder.withValues(alpha: 0.15),
              ),
            ),
            child: const Text('😴', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDate == null
                      ? l10n.noTrainingAssignedToday
                      : l10n.noTrainingAssignedForDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.enjoyRestDay,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 12,
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

class _TrainingHistoryListItem extends StatelessWidget {
  const _TrainingHistoryListItem({
    required this.entry,
    required this.selectedDate,
    required this.historyDate,
  });

  final TrainingHistoryEntity entry;
  final String selectedDate;
  final String historyDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final color = _trainingTypeColor(context, entry.type);
    final statusColor = entry.isCompleted ? semantic.success : semantic.warning;
    final entryDate = _storageDate(entry.date);

    return TappableScale(
      onTap: () async {
        await context.push('/trainings/${entry.id}?date=$entryDate');
        if (context.mounted) {
          context.read<TrainingBloc>().add(
            TrainingsLoadRequested(
              date: selectedDate,
              historyDate: historyDate,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: GlassDecoration.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: palette.textSecondary,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  _historyDateLabel(context, entry.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.20),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    entry.isCompleted ? l10n.completed : l10n.pending,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.fitness_center, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.type,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.timer_outlined,
                            color: palette.textDisabled,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${entry.estimatedDurationMin ?? '--'} min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.stairs_outlined,
                            color: palette.textDisabled,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              entry.level,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textDisabled,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: palette.textDisabled,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
