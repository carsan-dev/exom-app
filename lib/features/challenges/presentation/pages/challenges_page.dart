import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/presentation/bloc/challenges_bloc.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider(
      create: (_) =>
          GetIt.I<ChallengesBloc>()..add(const ChallengesLoadRequested()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l10n.challengesTitle),
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: BlocBuilder<ChallengesBloc, ChallengesState>(
          builder: (context, state) {
            if (state is ChallengesLoading) {
              return Center(
                child: CircularProgressIndicator(color: palette.primary),
              );
            }
            if (state is ChallengesError) {
              return ErrorWidget2(
                message: AppLocalizations.of(context)!.challengesLoadError,
                onRetry: () => context.read<ChallengesBloc>().add(
                  const ChallengesLoadRequested(),
                ),
              );
            }
            if (state is ChallengesLoaded) {
              return _ChallengesContent(state: state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ChallengesContent extends StatelessWidget {
  const _ChallengesContent({required this.state});

  final ChallengesLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasContent =
        state.mainGoals.isNotEmpty ||
        state.weeklyChallenges.isNotEmpty ||
        state.achievements.isNotEmpty;

    if (!hasContent) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      color: context.exomPalette.primary,
      backgroundColor: context.exomPalette.surface,
      onRefresh: () async {
        context.read<ChallengesBloc>().add(const ChallengesLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (state.mainGoals.isNotEmpty) ...[
            _SectionTitle(title: l10n.mainGoalSection),
            ...state.mainGoals.map((c) => _MainGoalCard(challenge: c)),
          ],
          if (state.weeklyChallenges.isNotEmpty) ...[
            _SectionTitle(title: l10n.weeklyChallengesSection),
            ...state.weeklyChallenges.map((c) => _ChallengeCard(challenge: c)),
          ],
          if (state.achievements.isNotEmpty) ...[
            _SectionTitle(title: l10n.unlockedAchievementsSection),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.achievements.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _AchievementCard(achievement: state.achievements[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: palette.textDisabled,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noActiveChallenges,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noActiveChallengesMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.challenges,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            2,
            (i) => _PlaceholderCard(
              icon: Icons.flag_outlined,
              label: l10n.pendingChallengeLabel,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.achievements,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => Container(
                width: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderMedium, width: 1.5),
                  color: palette.surfaceVariant,
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: palette.textDisabled,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMedium, width: 1.5),
        color: palette.surfaceVariant,
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.textDisabled, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.borderMedium,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: 80,
                  decoration: BoxDecoration(
                    color: palette.borderSoft,
                    borderRadius: BorderRadius.circular(6),
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

class _MainGoalCard extends StatelessWidget {
  const _MainGoalCard({required this.challenge});

  final ChallengeEntity challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: AppColors.primary, size: 20),
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
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: challenge.progress,
                  strokeWidth: 8,
                  backgroundColor: palette.divider,
                  valueColor: AlwaysStoppedAnimation(
                    challenge.isCompleted ? AppColors.success : palette.primary,
                  ),
                ),
              ),
              Text(
                '${(challenge.progress * 100).toInt()}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${challenge.currentValue.toStringAsFixed(0)} / ${challenge.targetValue.toStringAsFixed(0)} ${challenge.unit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (challenge.deadline != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${l10n.challengeDeadlineLabel}: ${DateFormat('dd MMM yyyy', Localizations.localeOf(context).languageCode).format(challenge.deadline!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textDisabled,
                  fontSize: 11,
                ),
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
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                challenge.isCompleted ? Icons.check_circle : Icons.emoji_events,
                color: challenge.isCompleted
                    ? AppColors.success
                    : AppColors.warning,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: challenge.progress,
              backgroundColor: palette.divider,
              valueColor: AlwaysStoppedAnimation(
                challenge.isCompleted ? AppColors.success : palette.primary,
              ),
              minHeight: 6,
            ),
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
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
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
