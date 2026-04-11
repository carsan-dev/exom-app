import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/stats_row.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/features/home/presentation/widgets/week_day_selector.dart';
import 'package:exom_app/injection_container.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>()..add(const HomeLoadRequested()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) => _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state) {
    if (state is HomeLoading || state is HomeInitial) {
      return const ShimmerList(count: 4, itemHeight: 160);
    }

    if (state is HomeError) {
      return ErrorWidget2(
        message: state.message,
        onRetry: () => context.read<HomeBloc>().add(const HomeLoadRequested()),
      );
    }

    if (state is HomeRestDay) {
      return _RestDayBody(
        summary: state.summary,
        selectedDate: state.selectedDate,
      );
    }

    if (state is HomeLoaded) {
      return _LoadedBody(
        summary: state.summary,
        selectedDate: state.selectedDate,
      );
    }

    return const SizedBox.shrink();
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.selectedDate});

  final DateTime selectedDate;

  String _relativeLabel(BuildContext context, DateTime date) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final dateNorm = DateTime(date.year, date.month, date.day);
    final diff = dateNorm.difference(todayNorm).inDays;
    final l10n = AppLocalizations.of(context)!;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final locale = Localizations.localeOf(context).languageCode;
    final dayName = DateFormat('EEEE', locale).format(selectedDate);
    final isEnglish = locale == 'en';
    final dayMonth = isEnglish
        ? DateFormat('MMMM d', locale).format(selectedDate)
        : DateFormat('d \'de\' MMMM', locale).format(selectedDate);
    final capitalDay = dayName[0].toUpperCase() + dayName.substring(1);
    final label = _relativeLabel(context, selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$capitalDay $dayMonth',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.go('/calendar'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.glassBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.glassBorder.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                color: palette.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.summary, required this.selectedDate});

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeLoadRequested());
      },
      child: Stack(
        children: [
          const _HomeHeroAccent(),
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _DateHeader(selectedDate: selectedDate),
              const SizedBox(height: 12),
              const WeekDaySelector(),
              const SizedBox(height: 20),
              TodayTrainingCard(summary: summary),
              TodayDietCard(summary: summary),
              StatsRow(summary: summary),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestDayBody extends StatelessWidget {
  const _RestDayBody({required this.summary, required this.selectedDate});

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeLoadRequested());
      },
      child: Stack(
        children: [
          const _HomeHeroAccent(),
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _DateHeader(selectedDate: selectedDate),
              const SizedBox(height: 12),
              const WeekDaySelector(),
              const SizedBox(height: 20),
              GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(32),
                borderRadius: 24,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: palette.glassBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.glassBorder.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.fitness_center,
                          color: palette.textDisabled,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.restDayTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: palette.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.restDayMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => context.go('/calendar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.openCalendarButton),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StatsRow(summary: summary),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeHeroAccent extends StatelessWidget {
  const _HomeHeroAccent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(0, -48),
        child: SizedBox(
          height: isDark ? 420 : 380,
          width: double.infinity,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.72, 1],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Opacity(
              opacity: isDark ? 0.82 : 0.68,
              child: ExomAnimatedBackground(
                intensity: isDark ? 0.5 : 0.42,
                showBase: false,
                showVeil: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
