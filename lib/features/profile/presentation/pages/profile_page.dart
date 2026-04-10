import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:exom_app/core/services/feature_gate_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/widgets/premium_locked_overlay.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context).profilePageTitle,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocProvider(
        create: (_) => sl<ProfileBloc>()..add(const ProfileLoadRequested()),
        child: const _ProfileView(),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading || state is ProfileInitial) {
          return const ShimmerList(count: 5, itemHeight: 100);
        }
        if (state is ProfileError) {
          return ErrorWidget2(
            message: state.message,
            onRetry: () =>
                context.read<ProfileBloc>().add(const ProfileLoadRequested()),
          );
        }
        if (state is ProfileLoaded) {
          return _ProfileContent(
            profile: state.profile,
            isUploadingAvatar: false,
            weightHistory: state.weightHistory,
            latestMetric: state.latestMetric,
          );
        }
        if (state is ProfileAvatarUploading) {
          return _ProfileContent(
            profile: state.profile,
            isUploadingAvatar: true,
            weightHistory: state.weightHistory,
            latestMetric: state.latestMetric,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileEntity profile;
  final bool isUploadingAvatar;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;

  const _ProfileContent({
    required this.profile,
    required this.isUploadingAvatar,
    required this.weightHistory,
    required this.latestMetric,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<ProfileBloc>().add(const ProfileLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _ProfileHeader(
            profile: profile,
            isUploadingAvatar: isUploadingAvatar,
          ),
          _ActionButtons(profile: profile),
          _WeightChartCard(weightHistory: weightHistory),
          _IndicatorCards(profile: profile, latestMetric: latestMetric),
          _BodyDataSection(
            profile: profile,
            weightHistory: weightHistory,
            latestMetric: latestMetric,
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ProfileEntity profile;
  final bool isUploadingAvatar;

  const _ProfileHeader({
    required this.profile,
    required this.isUploadingAvatar,
  });

  Future<void> _pickAndUpload(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked == null) return;
    if (!context.mounted) return;
    context.read<ProfileBloc>().add(
      ProfileAvatarUploadRequested(File(picked.path)),
    );
  }

  String _levelLabel(BuildContext context, String? level) {
    switch (level?.toUpperCase()) {
      case 'BEGINNER':
      case 'PRINCIPIANTE':
        return AppLocalizations.of(context).beginnerLevel;
      case 'INTERMEDIATE':
      case 'INTERMEDIO':
        return AppLocalizations.of(context).intermediateLevel;
      case 'ADVANCED':
      case 'AVANZADO':
        return AppLocalizations.of(context).advancedLevel;
      default:
        return level ?? '';
    }
  }

  String _goalLabel(BuildContext context, String? goal) {
    switch (goal?.toUpperCase()) {
      case 'LOSE_WEIGHT':
        return AppLocalizations.of(context).loseWeightGoal;
      case 'GAIN_MUSCLE':
        return AppLocalizations.of(context).gainMuscleGoal;
      case 'MAINTAIN':
        return AppLocalizations.of(context).maintainGoal;
      case 'IMPROVE_FITNESS':
        return AppLocalizations.of(context).improveFitnessGoal;
      default:
        return goal ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: name, tags, stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isNotEmpty
                      ? profile.fullName.toUpperCase()
                      : 'USUARIO EXOM',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_levelLabel(context, profile.level).isNotEmpty)
                      _Tag(label: _levelLabel(context, profile.level)),
                    if (_goalLabel(context, profile.goal).isNotEmpty)
                      _Tag(label: _goalLabel(context, profile.goal)),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (profile.currentWeightKg != null)
                      _InlineStat(
                        icon: Icons.monitor_weight_outlined,
                        text: formatWeight(
                          profile.currentWeightKg,
                          unitSystem,
                          decimals: 0,
                        ),
                      ),
                    if (profile.heightCm != null)
                      _InlineStat(
                        icon: Icons.height,
                        text: formatLength(
                          profile.heightCm,
                          unitSystem,
                          decimals: 0,
                        ),
                      ),
                    _InlineStat(
                      icon: Icons.local_fire_department_outlined,
                      text:
                          '${AppLocalizations.of(context).streak} ${profile.streakDays} ${AppLocalizations.of(context).days}',
                      iconColor: AppColors.calorieAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: avatar
          GestureDetector(
            onTap: isUploadingAvatar ? null : () => _pickAndUpload(context),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: isUploadingAvatar
                      ? const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        )
                      : profile.avatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profile.avatarUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 40,
                        ),
                ),
                if (!isUploadingAvatar)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.textOnPrimary,
                      size: 12,
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

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor ?? palette.textSecondary, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ── Action Buttons ──────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final ProfileEntity profile;

  const _ActionButtons({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionChip(
              icon: Icons.monitor_weight_outlined,
              label: AppLocalizations.of(context).updateWeightButton,
              onTap: () async {
                await context.push('/profile/metrics');
                if (context.mounted) {
                  context.read<ProfileBloc>().add(const ProfileLoadRequested());
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionChip(
              icon: Icons.straighten_outlined,
              label: AppLocalizations.of(context).updateMeasurementsButton,
              onTap: () async {
                await context.push('/profile/metrics');
                if (context.mounted) {
                  context.read<ProfileBloc>().add(const ProfileLoadRequested());
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionChip(
              icon: Icons.bar_chart_outlined,
              label: AppLocalizations.of(context).weeklyRecapButton,
              onTap: () => context.push(AppRoutes.recap),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weight Chart ────────────────────────────────────────────────────────────

class _WeightChartCard extends StatelessWidget {
  final List<BodyMetricEntity> weightHistory;

  const _WeightChartCard({required this.weightHistory});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final latestByDay = <String, BodyMetricEntity>{};
    for (final entry in weightHistory.where((item) => item.weightKg != null)) {
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.date);
      latestByDay[dayKey] = entry;
    }

    final entries = latestByDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).weightProgressTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _EmptyChart(
              onRegister: () async {
                await context.push('/profile/metrics');
                if (context.mounted) {
                  context.read<ProfileBloc>().add(const ProfileLoadRequested());
                }
              },
            )
          else
            _FilledChart(entries: entries),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final VoidCallback onRegister;

  const _EmptyChart({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.show_chart,
          color: AppColors.primary.withValues(alpha: 0.3),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context).noDataYetMessage,
          style: theme.textTheme.titleMedium?.copyWith(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).logMetricsPrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRegister,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(AppLocalizations.of(context).logMetricsButton),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FilledChart extends StatelessWidget {
  final List<BodyMetricEntity> entries;

  const _FilledChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final weights = entries.map((e) => e.weightKg!).toList();
    final minW = weights.reduce(math.min) - 1;
    final maxW = weights.reduce(math.max) + 1;

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg!);
    }).toList();

    final dateFormat = DateFormat(
      'd MMM',
      Localizations.localeOf(context).languageCode,
    );

    return Column(
      children: [
        // Latest value badge
        if (entries.length >= 2)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${dateFormat.format(entries.last.date)}  ${formatWeight(entries.last.weightKg, unitSystem)}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: palette.divider, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: entries.length > 6
                        ? (entries.length / 5).ceilToDouble()
                        : 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dateFormat.format(entries[idx].date),
                          style: TextStyle(
                            color: palette.textDisabled,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) => Text(
                      formatWeight(value, unitSystem, decimals: 0, empty: '--'),
                      style: TextStyle(
                        color: palette.textDisabled,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: minW,
              maxY: maxW,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: palette.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.3),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Indicator Cards (Masa Muscular + Sueño) ─────────────────────────────────

class _IndicatorCards extends StatelessWidget {
  final ProfileEntity profile;
  final BodyMetricEntity? latestMetric;

  const _IndicatorCards({required this.profile, required this.latestMetric});

  Future<void> _editMuscleGoal(BuildContext context) async {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final controller = TextEditingController(
      text: profile.muscleMassGoalKg != null
          ? formatWeightValue(profile.muscleMassGoalKg, unitSystem)
          : '',
    );

    final newGoal = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.exomPalette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            AppLocalizations.of(context).muscleMassGoalTitle,
            style: TextStyle(color: palette.textPrimary),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: unitSystem == UnitSystem.imperial
                  ? 'Eg: 75.0'
                  : 'Eg: 34.0',
              suffixText: weightUnitSymbol(unitSystem),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                if (parsed != null && parsed > 0) {
                  Navigator.of(
                    dialogContext,
                  ).pop(UnitConverters.weightFromDisplay(parsed, unitSystem));
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        );
      },
    );

    if (newGoal != null && context.mounted) {
      context.read<ProfileBloc>().add(ProfileMuscleGoalUpdated(newGoal));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final latestMuscleMass = latestMetric?.muscleMassKg;
    final muscleGoal = profile.muscleMassGoalKg;
    final muscleProgress =
        latestMuscleMass != null && muscleGoal != null && muscleGoal > 0
        ? (latestMuscleMass / muscleGoal).clamp(0.0, 1.0)
        : null;

    final sleepEntries = latestMetric?.sleepHours != null
        ? [latestMetric!]
        : <BodyMetricEntity>[];
    final avgSleep = sleepEntries.isNotEmpty
        ? sleepEntries.map((e) => e.sleepHours!).reduce((a, b) => a + b) /
              sleepEntries.length
        : null;
    final sleepGoal = 8.0;
    final sleepPercent = avgSleep != null
        ? (avgSleep / sleepGoal).clamp(0.0, 1.0)
        : null;
    final daysInGoal = sleepEntries.where((e) => e.sleepHours! >= 7.0).length;

    final gate = GetIt.instance<FeatureGateService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: PremiumLockedSection(
              isLocked: !gate.canSeeMuscleMassChart,
              label: AppLocalizations.of(context).muscleMassLabel,
              onTap: () => showPremiumFeatureMessage(context),
              child: latestMuscleMass != null
                  ? _CircularIndicatorCard(
                      title: AppLocalizations.of(context).muscleMassLabel,
                      value: formatWeight(latestMuscleMass, unitSystem),
                      subtitle: muscleGoal != null
                          ? '${AppLocalizations.of(context).goalLabel} ${formatWeight(muscleGoal, unitSystem)}'
                          : AppLocalizations.of(context).setYourGoal,
                      bottomLabel: latestMetric != null
                          ? '${AppLocalizations.of(context).latestMeasurementLabel} ${DateFormat('dd MMM', Localizations.localeOf(context).languageCode).format(latestMetric!.date)}'
                          : AppLocalizations.of(context).updateYourMetrics,
                      progress: muscleProgress,
                      color: AppColors.calorieAccent,
                      progressCaption: AppLocalizations.of(
                        context,
                      ).currentCaption,
                      headerAction: IconButton(
                        onPressed: () => _editMuscleGoal(context),
                        icon: Icon(
                          Icons.tune,
                          color: palette.textDisabled,
                          size: 16,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : _EmptyIndicatorCard(
                      title: AppLocalizations.of(context).muscleMassLabel,
                      message: AppLocalizations.of(
                        context,
                      ).muscleGoalEmptyState,
                      actionLabel: AppLocalizations.of(
                        context,
                      ).logOrCalculateButton,
                      onAction: () async {
                        await context.push('/profile/metrics');
                        if (context.mounted) {
                          context.read<ProfileBloc>().add(
                            const ProfileLoadRequested(),
                          );
                        }
                      },
                      headerAction: IconButton(
                        onPressed: () => _editMuscleGoal(context),
                        icon: Icon(
                          Icons.tune,
                          color: palette.textDisabled,
                          size: 16,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PremiumLockedSection(
              isLocked: !gate.canSeeSleepChart,
              label: AppLocalizations.of(context).sleep,
              onTap: () => showPremiumFeatureMessage(context),
              child: avgSleep != null
                  ? _CircularIndicatorCard(
                      title: AppLocalizations.of(context).sleep,
                      value: '${avgSleep.toStringAsFixed(1)} h',
                      subtitle:
                          '${(sleepPercent! * 100).toInt()}% ${AppLocalizations.of(context).ofGoalPercentage}',
                      bottomLabel:
                          '$daysInGoal/${sleepEntries.length} ${AppLocalizations.of(context).daysWithinGoal}',
                      progress: sleepPercent,
                      color: AppColors.sleepAccent,
                      progressCaption: AppLocalizations.of(
                        context,
                      ).todayCaption,
                    )
                  : _EmptyIndicatorCard(
                      title: AppLocalizations.of(context).sleep,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularIndicatorCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String bottomLabel;
  final double? progress;
  final Color color;
  final Widget? headerAction;
  final String progressCaption;

  const _CircularIndicatorCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.bottomLabel,
    this.progress,
    required this.color,
    this.headerAction,
    this.progressCaption = 'media',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (headerAction != null) ...[headerAction!],
            ],
          ),
          const SizedBox(height: 14),
          // Circular indicator
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  CustomPaint(
                    size: const Size(90, 90),
                    painter: _CircularProgressPainter(
                      progress: progress!,
                      color: color,
                      trackColor: palette.surfaceVariant,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            color: color,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (progress != null)
                      Text(
                        progressCaption,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bottomLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textDisabled,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 6.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter old) =>
      old.progress != progress || old.color != color;
}

class _EmptyIndicatorCard extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? headerAction;

  const _EmptyIndicatorCard({
    required this.title,
    this.message = 'Sin datos',
    this.actionLabel,
    this.onAction,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (headerAction != null) ...[headerAction!],
            ],
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textDisabled,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.borderMedium),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ),
          ] else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Datos Corporales Section ────────────────────────────────────────────────

class _BodyDataSection extends StatelessWidget {
  final ProfileEntity profile;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;

  const _BodyDataSection({
    required this.profile,
    required this.weightHistory,
    required this.latestMetric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final latestWeight =
        weightHistory.where((e) => e.weightKg != null).isNotEmpty
        ? weightHistory.where((e) => e.weightKg != null).last
        : null;
    final hasMeasurements =
        latestMetric != null &&
        (latestMetric!.neckCm != null ||
            latestMetric!.chestCm != null ||
            latestMetric!.waistCm != null ||
            latestMetric!.hipsCm != null);
    final currentHeightCm = latestMetric?.heightCm ?? profile.heightCm;

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).bodyDataTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (latestMetric != null)
                Text(
                  '${AppLocalizations.of(context).lastUpdatedLabel} ${dateFormat.format(latestMetric!.date)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textDisabled,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Weight row
          _DataRow(
            icon: Icons.monitor_weight_outlined,
            label: latestWeight != null
                ? '${AppLocalizations.of(context).weight}: ${formatWeight(latestWeight.weightKg, unitSystem)}'
                : '${AppLocalizations.of(context).weight}: --',
            detail: latestWeight != null
                ? '${AppLocalizations.of(context).lastUpdatedLabel} ${dateFormat.format(latestWeight.date)}'
                : null,
          ),
          const SizedBox(height: 10),
          _DataRow(
            icon: Icons.fitness_center,
            label: latestMetric?.muscleMassKg != null
                ? '${AppLocalizations.of(context).muscleMassLabel}: ${formatWeight(latestMetric!.muscleMassKg, unitSystem)}'
                : '${AppLocalizations.of(context).muscleMassLabel}: --',
            detail: profile.muscleMassGoalKg != null
                ? '${AppLocalizations.of(context).goalLabel} ${formatWeight(profile.muscleMassGoalKg, unitSystem)}'
                : AppLocalizations.of(context).setYourGoal,
          ),
          const SizedBox(height: 10),
          _DataRow(
            icon: Icons.height,
            label: currentHeightCm != null
                ? '${AppLocalizations.of(context).height}: ${formatLength(currentHeightCm, unitSystem, decimals: 0)}'
                : '${AppLocalizations.of(context).height}: --',
            detail: currentHeightCm != null
                ? AppLocalizations.of(context).syncedWithProfileAndMetrics
                : AppLocalizations.of(context).addHeightInMetrics,
          ),
          const SizedBox(height: 10),
          // Measurements row
          _DataRow(
            icon: Icons.straighten_outlined,
            label: AppLocalizations.of(context).measurementsLabel,
            detail: hasMeasurements
                ? '${AppLocalizations.of(context).lastUpdatedLabel} ${dateFormat.format(latestMetric!.date)}'
                : AppLocalizations.of(context).noDataLabel,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await context.push('/profile/metrics');
                if (context.mounted) {
                  context.read<ProfileBloc>().add(const ProfileLoadRequested());
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textSecondary,
                side: const BorderSide(color: AppColors.borderMedium),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppLocalizations.of(context).updateMetricsButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;

  const _DataRow({required this.icon, required this.label, this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Row(
      children: [
        Icon(icon, color: palette.textSecondary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textDisabled,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
