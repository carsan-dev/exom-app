import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/presentation/bloc/challenges_bloc.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<ChallengesBloc>()..add(const ChallengesLoadRequested()),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Retos y Logros'),
          backgroundColor: AppColors.background,
        ),
        body: BlocBuilder<ChallengesBloc, ChallengesState>(
          builder: (context, state) {
            if (state is ChallengesLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state is ChallengesError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error al cargar los retos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        context.read<ChallengesBloc>().add(const ChallengesLoadRequested());
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
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
  final ChallengesLoaded state;

  const _ChallengesContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final hasContent = state.mainGoals.isNotEmpty ||
        state.weeklyChallenges.isNotEmpty ||
        state.achievements.isNotEmpty;

    if (!hasContent) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        context.read<ChallengesBloc>().add(const ChallengesLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (state.mainGoals.isNotEmpty) ...[
            _sectionTitle('Objetivo principal'),
            ...state.mainGoals.map((c) => _MainGoalCard(challenge: c)),
          ],
          if (state.weeklyChallenges.isNotEmpty) ...[
            _sectionTitle('Retos semanales'),
            ...state.weeklyChallenges.map((c) => _ChallengeCard(challenge: c)),
          ],
          if (state.achievements.isNotEmpty) ...[
            _sectionTitle('Logros desbloqueados'),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.achievements.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _AchievementCard(achievement: state.achievements[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          const Center(
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, color: AppColors.textDisabled, size: 56),
                SizedBox(height: 12),
                Text(
                  'Sin retos activos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tu entrenador te asignará retos próximamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Placeholder retos
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Retos',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ...List.generate(2, (i) => _PlaceholderCard(
            icon: Icons.flag_outlined,
            label: 'Reto pendiente',
          )),
          const SizedBox(height: 20),
          // Placeholder logros
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Logros',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
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
                  color: AppColors.surfaceVariant,
                ),
                child: const Center(
                  child: Icon(Icons.lock_outline, color: AppColors.textDisabled, size: 28),
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
  final IconData icon;
  final String label;

  const _PlaceholderCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMedium, width: 1.5),
        color: AppColors.surfaceVariant,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDisabled, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 120, decoration: BoxDecoration(color: AppColors.borderMedium, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(height: 8, width: 80, decoration: BoxDecoration(color: AppColors.borderSoft, borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainGoalCard extends StatelessWidget {
  final ChallengeEntity challenge;

  const _MainGoalCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(
                    challenge.isCompleted ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${(challenge.progress * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          if (challenge.deadline != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Fecha límite: ${DateFormat('dd MMM yyyy', 'es').format(challenge.deadline!)}',
                style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeEntity challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                challenge.isCompleted ? Icons.check_circle : Icons.emoji_events,
                color: challenge.isCompleted ? AppColors.success : AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${challenge.currentValue.toStringAsFixed(0)}/${challenge.targetValue.toStringAsFixed(0)} ${challenge.unit}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: challenge.progress,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(
                challenge.isCompleted ? AppColors.success : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          if (challenge.deadline != null) ...[
            const SizedBox(height: 6),
            Text(
              'Hasta ${DateFormat('dd MMM', 'es').format(challenge.deadline!)}',
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementEntity achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium, color: AppColors.warning, size: 32),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
