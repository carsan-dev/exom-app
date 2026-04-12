import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  Future<void> _refreshChallenges(BuildContext context) async {
    context.read<ChallengesBloc>().add(const ChallengesLoadRequested());
  }

  Widget _buildErrorState(BuildContext context, ChallengesError state) {
    void retry() =>
        context.read<ChallengesBloc>().add(const ChallengesLoadRequested());

    final apiException = state.apiException;
    if (apiException?.isNetworkError == true) {
      return NoConnectionWidget(onRetry: retry);
    }
    if (apiException?.isServerError == true) {
      return ServerErrorWidget(
        errorCode: apiException!.statusCode.toString(),
        onRetry: retry,
      );
    }
    return ErrorWidget2(
      message: apiException != null
          ? localizedApiError(context, apiException)
          : AppLocalizations.of(context).challengesLoadError,
      onRetry: retry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          GetIt.I<ChallengesBloc>()..add(const ChallengesLoadRequested()),
      child: BlocBuilder<ChallengesBloc, ChallengesState>(
        builder: (context, state) {
          if (state is ChallengesInitial || state is ChallengesLoading) {
            return const _ChallengesLoadingContent();
          }
          if (state is ChallengesError) {
            return _buildErrorState(context, state);
          }
          if (state is ChallengesLoaded) {
            return _ChallengesContent(
              state: state,
              onRefresh: () => _refreshChallenges(context),
            );
          }
          if (state is ChallengesEmpty) {
            return _ChallengesEmptyContent(
              state: state,
              onRefresh: () => _refreshChallenges(context),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ChallengesLoadingContent extends StatelessWidget {
  const _ChallengesLoadingContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: const [
        _ChallengesHeaderSkeleton(),
        _ChallengesSectionTitleSkeleton(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ShimmerCard(
            height: 188,
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
        _ChallengesSectionTitleSkeleton(width: 168),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ShimmerCard(
            height: 96,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ShimmerCard(
            height: 96,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        _ChallengesSectionTitleSkeleton(width: 190, showAction: true),
        _ChallengesAchievementsSkeleton(),
      ],
    );
  }
}

class _ChallengesHeaderSkeleton extends StatelessWidget {
  const _ChallengesHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerCard(
                  height: 34,
                  width: 176,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                SizedBox(height: 8),
                ShimmerCard(
                  height: 16,
                  width: 224,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          ShimmerCard(
            height: 104,
            width: 96,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ],
      ),
    );
  }
}

class _ChallengesSectionTitleSkeleton extends StatelessWidget {
  const _ChallengesSectionTitleSkeleton({
    this.width = 132,
    this.showAction = false,
  });

  final double width;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          ShimmerCard(
            height: 22,
            width: width,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          const Spacer(),
          if (showAction)
            const ShimmerCard(
              height: 28,
              width: 72,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
        ],
      ),
    );
  }
}

class _ChallengesAchievementsSkeleton extends StatelessWidget {
  const _ChallengesAchievementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (_, index) => const ShimmerCard(
          height: 120,
          width: 116,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    );
  }
}

class _ChallengesContent extends StatelessWidget {
  const _ChallengesContent({required this.state, required this.onRefresh});

  final ChallengesLoaded state;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showCatalogButton = state.achievementCatalog.isNotEmpty;
    final unlockedIds = state.achievements
        .map((achievement) => achievement.id)
        .toSet();

    return RefreshIndicator(
      color: context.exomPalette.primary,
      backgroundColor: context.exomPalette.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _ChallengesHeader(streakDays: state.streakDays),
          if (state.mainGoals.isNotEmpty) ...[
            _SectionTitle(title: l10n.mainGoalSection),
            ...state.mainGoals.map((c) => _MainGoalCard(challenge: c)),
          ],
          if (state.weeklyChallenges.isNotEmpty) ...[
            _SectionTitle(title: l10n.weeklyChallengesSection),
            ...state.weeklyChallenges.map((c) => _ChallengeCard(challenge: c)),
          ],
          if (state.achievements.isNotEmpty) ...[
            _SectionTitle(
              title: l10n.unlockedAchievementsSection,
              actionLabel: showCatalogButton ? l10n.viewAllButton : null,
              onActionTap: showCatalogButton
                  ? () => _showAchievementsBoard(
                      context,
                      catalog: state.achievementCatalog,
                      unlockedIds: unlockedIds,
                    )
                  : null,
            ),
            _AchievementsCarousel(achievements: state.achievements),
          ],
        ],
      ),
    );
  }
}

class _ChallengesEmptyContent extends StatelessWidget {
  const _ChallengesEmptyContent({required this.state, required this.onRefresh});

  final ChallengesEmpty state;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showCatalogButton = state.achievementCatalog.isNotEmpty;
    final unlockedIds = state.achievements
        .map((achievement) => achievement.id)
        .toSet();

    return RefreshIndicator(
      color: context.exomPalette.primary,
      backgroundColor: context.exomPalette.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _ChallengesHeader(streakDays: state.streakDays),
          const _EmptyChallengesCard(),
          _SectionTitle(
            title: l10n.unlockedAchievementsSection,
            actionLabel: showCatalogButton ? l10n.viewAllButton : null,
            onActionTap: showCatalogButton
                ? () => _showAchievementsBoard(
                    context,
                    catalog: state.achievementCatalog,
                    unlockedIds: unlockedIds,
                  )
                : null,
          ),
          if (state.achievements.isNotEmpty)
            _AchievementsCarousel(achievements: state.achievements)
          else
            const _EmptyAchievementsCard(),
        ],
      ),
    );
  }
}

class _ChallengesHeader extends StatelessWidget {
  const _ChallengesHeader({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.challengesTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.challengesSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StreakSummaryCard(days: streakDays),
        ],
      ),
    );
  }
}

class _StreakSummaryCard extends StatelessWidget {
  const _StreakSummaryCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;

    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: GlassDecoration.accentCard(
        AppColors.warning,
        borderRadius: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '$days ${l10n.days}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.streak,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

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
              style: theme.textTheme.titleLarge?.copyWith(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: palette.primary,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showAchievementsBoard(
  BuildContext context, {
  required List<AchievementEntity> catalog,
  required Set<String> unlockedIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: context.exomPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _AchievementsBoardSheet(catalog: catalog, unlockedIds: unlockedIds),
  );
}

class _AchievementsBoardSheet extends StatelessWidget {
  const _AchievementsBoardSheet({
    required this.catalog,
    required this.unlockedIds,
  });

  final List<AchievementEntity> catalog;
  final Set<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final crossAxisCount = MediaQuery.sizeOf(context).width >= 720 ? 3 : 2;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: palette.surface,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.achievementBoardTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${unlockedIds.length}/${catalog.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: catalog.length,
                    itemBuilder: (_, index) {
                      final achievement = catalog[index];
                      return _AchievementBoardCard(
                        achievement: achievement,
                        isUnlocked: unlockedIds.contains(achievement.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AchievementBoardCard extends StatelessWidget {
  const _AchievementBoardCard({
    required this.achievement,
    required this.isUnlocked,
  });

  final AchievementEntity achievement;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final iconColor = isUnlocked ? AppColors.warning : palette.textDisabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isUnlocked
          ? GlassDecoration.accentCard(AppColors.warning, borderRadius: 20)
          : GlassDecoration.card(
              borderRadius: 20,
              borderColor: palette.glassBorder.withValues(alpha: 0.14),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isUnlocked ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isUnlocked
                      ? Icons.workspace_premium_rounded
                      : Icons.workspace_premium_outlined,
                  color: iconColor,
                  size: 26,
                ),
              ),
              const Spacer(),
              Icon(
                isUnlocked
                    ? Icons.check_circle_rounded
                    : Icons.lock_outline_rounded,
                color: iconColor,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            achievement.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isUnlocked ? palette.textPrimary : palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              achievement.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isUnlocked
                    ? palette.textSecondary
                    : palette.textDisabled,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChallengesCard extends StatelessWidget {
  const _EmptyChallengesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.glassBorder.withValues(alpha: 0.18),
              ),
              color: palette.glassBackground,
            ),
            child: Icon(
              Icons.star_border_rounded,
              color: palette.textDisabled,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noActiveChallenges,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: palette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noActiveChallengesMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAchievementsCard extends StatelessWidget {
  const _EmptyAchievementsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (_) => const _AchievementPlaceholderCard(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.lockedAchievementsHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsCarousel extends StatelessWidget {
  const _AchievementsCarousel({required this.achievements});

  final List<AchievementEntity> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: achievements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) =>
            _AchievementCard(achievement: achievements[index]),
      ),
    );
  }
}

class _AchievementPlaceholderCard extends StatelessWidget {
  const _AchievementPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      width: 56,
      height: 56,
      decoration: GlassDecoration.card(
        borderRadius: 14,
        borderColor: palette.glassBorder.withValues(alpha: 0.18),
      ),
      child: Icon(
        Icons.lock_outline_rounded,
        color: palette.textDisabled,
        size: 28,
      ),
    );
  }
}

class _MainGoalCard extends StatelessWidget {
  const _MainGoalCard({required this.challenge});

  final ChallengeEntity challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: GlassDecoration.accentCard(
        AppColors.warning,
        borderRadius: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.progress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(challenge.progress * 100).toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GlowingProgressBar(
            value: challenge.progress,
            color: challenge.isCompleted
                ? AppColors.success
                : AppColors.warning,
            backgroundColor: AppColors.warning.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 12),
          Text(
            '${challenge.currentValue.toStringAsFixed(0)} / ${challenge.targetValue.toStringAsFixed(0)} ${challenge.unit}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontSize: 13,
            ),
          ),
          if (challenge.deadline != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.challengeDeadlineLabel}: ${DateFormat('dd MMM yyyy', Localizations.localeOf(context).languageCode).format(challenge.deadline!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});

  final ChallengeEntity challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final progressColor = challenge.isCompleted
        ? AppColors.warning
        : palette.primary;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      accentColor: challenge.isCompleted ? AppColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                challenge.isCompleted ? Icons.check_circle : Icons.emoji_events,
                color: challenge.isCompleted
                    ? AppColors.success
                    : progressColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${challenge.currentValue.toStringAsFixed(0)}/${challenge.targetValue.toStringAsFixed(0)} ${challenge.unit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GlowingProgressBar(
            value: challenge.progress,
            color: challenge.isCompleted ? AppColors.success : progressColor,
            backgroundColor: palette.glassBackground,
          ),
          if (challenge.deadline != null) ...[
            const SizedBox(height: 6),
            Text(
              '${l10n.challengeUntilLabel} ${DateFormat('dd MMM', Localizations.localeOf(context).languageCode).format(challenge.deadline!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final AchievementEntity achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: GlassDecoration.accentCard(
        AppColors.warning,
        borderRadius: 16,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.workspace_premium,
            color: AppColors.warning,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingProgressBar extends StatelessWidget {
  const _GlowingProgressBar({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: backgroundColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 0),
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
