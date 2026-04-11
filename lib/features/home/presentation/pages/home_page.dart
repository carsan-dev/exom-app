import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/theme/spacing.dart';
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
      return const _HomeLoadingBody();
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

class _HomeLoadingBody extends StatelessWidget {
  const _HomeLoadingBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _HomeHeroAccent(),
        ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 32),
          children: const [
            _HomeDateHeaderSkeleton(),
            SizedBox(height: 12),
            _HomeWeekSelectorSkeleton(),
            SizedBox(height: 20),
            _HomeFeatureCardSkeleton(),
            _HomeFeatureCardSkeleton(showSecondaryChip: false),
            _HomeStatsRowSkeleton(),
          ],
        ),
      ],
    );
  }
}

class _HomeDateHeaderSkeleton extends StatelessWidget {
  const _HomeDateHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExomSpacing.lg,
        ExomSpacing.sm,
        ExomSpacing.lg,
        ExomSpacing.xs,
      ),
      child: Row(
        children: const [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerCard(
                  height: 34,
                  width: 148,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                SizedBox(height: 8),
                ShimmerCard(
                  height: 16,
                  width: 188,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          ShimmerCard(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
      ),
    );
  }
}

class _HomeWeekSelectorSkeleton extends StatelessWidget {
  const _HomeWeekSelectorSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          7,
          (index) => const ShimmerCard(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    );
  }
}

class _HomeFeatureCardSkeleton extends StatelessWidget {
  const _HomeFeatureCardSkeleton({this.showSecondaryChip = true});

  final bool showSecondaryChip;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerCard(
                      height: 20,
                      width: 72,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    if (showSecondaryChip) ...[
                      const SizedBox(width: 8),
                      const ShimmerCard(
                        height: 14,
                        width: 60,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                const ShimmerCard(
                  height: 20,
                  width: 176,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                const SizedBox(height: 8),
                const ShimmerCard(
                  height: 14,
                  width: 148,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
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

class _HomeStatsRowSkeleton extends StatelessWidget {
  const _HomeStatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExomSpacing.lg,
        vertical: ExomSpacing.sm,
      ),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : ExomSpacing.md),
              child: GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: ExomSpacing.md,
                  vertical: ExomSpacing.md + 2,
                ),
                borderRadius: 16,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShimmerCard(
                      height: 24,
                      width: 48,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    SizedBox(height: ExomSpacing.xxs),
                    ShimmerCard(
                      height: 12,
                      width: 32,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    SizedBox(height: ExomSpacing.xs + 2),
                    ShimmerCard(
                      height: 14,
                      width: 58,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(
        ExomSpacing.lg,
        ExomSpacing.sm,
        ExomSpacing.lg,
        ExomSpacing.xs,
      ),
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
                    height: 1.07,
                    letterSpacing: -0.8,
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
            tooltip: AppLocalizations.of(context).openCalendarButton,
            iconSize: 18,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: Container(
              padding: const EdgeInsets.all(ExomSpacing.sm),
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
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
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
    final l10n = AppLocalizations.of(context);

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
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
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
