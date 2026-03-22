import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(const ProfileLoadRequested()),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: AppColors.background,
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const ShimmerList(count: 5, itemHeight: 100);
          }
          if (state is ProfileError) {
            return ErrorWidget2(
              message: state.message,
              onRetry: () => context.read<ProfileBloc>().add(const ProfileLoadRequested()),
            );
          }
          if (state is ProfileLoaded) {
            return _ProfileContent(
              profile: state.profile,
              isUploadingAvatar: false,
              weightHistory: state.weightHistory,
            );
          }
          if (state is ProfileAvatarUploading) {
            return _ProfileContent(
              profile: state.profile,
              isUploadingAvatar: true,
              weightHistory: const [],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileEntity profile;
  final bool isUploadingAvatar;
  final List<BodyMetricEntity> weightHistory;

  const _ProfileContent({
    required this.profile,
    required this.isUploadingAvatar,
    required this.weightHistory,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        context.read<ProfileBloc>().add(const ProfileLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _ProfileHeader(profile: profile, isUploadingAvatar: isUploadingAvatar),
          _ActionButtons(profile: profile),
          _WeightChartCard(weightHistory: weightHistory),
          _IndicatorCards(weightHistory: weightHistory),
          _BodyDataSection(profile: profile, weightHistory: weightHistory),
        ],
      ),
    );
  }
}

// ── Profile Header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ProfileEntity profile;
  final bool isUploadingAvatar;

  const _ProfileHeader({required this.profile, required this.isUploadingAvatar});

  Future<void> _pickAndUpload(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked == null) return;
    if (!context.mounted) return;
    context.read<ProfileBloc>().add(ProfileAvatarUploadRequested(File(picked.path)));
  }

  String _levelLabel(String? level) {
    switch (level?.toUpperCase()) {
      case 'BEGINNER':
        return 'Principiante';
      case 'INTERMEDIATE':
        return 'Intermedio';
      case 'ADVANCED':
        return 'Avanzado';
      default:
        return level ?? '';
    }
  }

  String _goalLabel(String? goal) {
    switch (goal?.toUpperCase()) {
      case 'LOSE_WEIGHT':
        return 'Perder peso';
      case 'GAIN_MUSCLE':
        return 'Ganar músculo';
      case 'MAINTAIN':
        return 'Mantener';
      case 'IMPROVE_FITNESS':
        return 'Mejorar fitness';
      default:
        return goal ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
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
                  profile.fullName.isNotEmpty ? profile.fullName.toUpperCase() : 'USUARIO EXOM',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
                    if (_levelLabel(profile.level).isNotEmpty)
                      _Tag(label: _levelLabel(profile.level)),
                    if (_goalLabel(profile.goal).isNotEmpty)
                      _Tag(label: _goalLabel(profile.goal)),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    if (profile.currentWeightKg != null) ...[
                      const Icon(Icons.monitor_weight_outlined, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.currentWeightKg!.toStringAsFixed(0)} kg',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.local_fire_department_outlined, color: AppColors.calorieAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Racha ${profile.streakDays} días',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                      ? const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)
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
                          : const Icon(Icons.person, color: AppColors.primary, size: 40),
                ),
                if (!isUploadingAvatar)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: AppColors.textOnPrimary, size: 12),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
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
              label: 'Actualizar peso',
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
              label: 'Actualizar medidas',
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
              label: 'ReCap semanal',
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

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
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
    final entries = weightHistory.where((e) => e.weightKg != null).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progreso del peso',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _EmptyChart(onRegister: () async {
              await context.push('/profile/metrics');
              if (context.mounted) {
                context.read<ProfileBloc>().add(const ProfileLoadRequested());
              }
            })
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
    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.show_chart,
          color: AppColors.primary.withValues(alpha: 0.3),
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'Sin datos todavía',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Registra tu peso y medidas para empezar\na ver tu evolución.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRegister,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Registrar métricas'),
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
    final weights = entries.map((e) => e.weightKg!).toList();
    final minW = weights.reduce(math.min) - 1;
    final maxW = weights.reduce(math.max) + 1;

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg!);
    }).toList();

    final dateFormat = DateFormat('d MMM', 'es');

    return Column(
      children: [
        // Latest value badge
        if (entries.length >= 2)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${dateFormat.format(entries.last.date)}  ${entries.last.weightKg!.toStringAsFixed(1)} kg',
                style: const TextStyle(
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
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.divider,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: entries.length > 6 ? (entries.length / 5).ceilToDouble() : 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dateFormat.format(entries[idx].date),
                          style: const TextStyle(color: AppColors.textDisabled, fontSize: 9),
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
                      '${value.toStringAsFixed(0)} kg',
                      style: const TextStyle(color: AppColors.textDisabled, fontSize: 9),
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
                      strokeColor: AppColors.card,
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
  final List<BodyMetricEntity> weightHistory;

  const _IndicatorCards({required this.weightHistory});

  @override
  Widget build(BuildContext context) {
    // Compute sleep stats from metrics
    final sleepEntries = weightHistory.where((e) => e.sleepHours != null).toList();
    final avgSleep = sleepEntries.isNotEmpty
        ? sleepEntries.map((e) => e.sleepHours!).reduce((a, b) => a + b) / sleepEntries.length
        : null;
    final sleepGoal = 8.0;
    final sleepPercent = avgSleep != null ? (avgSleep / sleepGoal).clamp(0.0, 1.0) : null;
    final daysInGoal = sleepEntries.where((e) => e.sleepHours! >= 7.0).length;

    // Weight change this month
    final now = DateTime.now();
    final thisMonthEntries = weightHistory
        .where((e) => e.weightKg != null && e.date.month == now.month && e.date.year == now.year)
        .toList();
    double? weightChange;
    if (thisMonthEntries.length >= 2) {
      weightChange = thisMonthEntries.last.weightKg! - thisMonthEntries.first.weightKg!;
    }
    final latestWeight = weightHistory.where((e) => e.weightKg != null).isNotEmpty
        ? weightHistory.where((e) => e.weightKg != null).last
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Masa muscular / Peso card
          Expanded(
            child: latestWeight != null
                ? _CircularIndicatorCard(
                    title: 'Peso',
                    value: '${latestWeight.weightKg!.toStringAsFixed(1)} kg',
                    subtitle: weightChange != null
                        ? '${weightChange >= 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg este mes'
                        : null,
                    bottomLabel: 'Última medición ${DateFormat('dd MMM', 'es').format(latestWeight.date)}',
                    progress: null,
                    color: AppColors.primary,
                  )
                : const _EmptyIndicatorCard(title: 'Peso'),
          ),
          const SizedBox(width: 12),
          // Sueño card
          Expanded(
            child: avgSleep != null
                ? _CircularIndicatorCard(
                    title: 'Sueño',
                    value: '${avgSleep.toStringAsFixed(1)} h',
                    subtitle: '${(sleepPercent! * 100).toInt()}% del objetivo',
                    bottomLabel: '$daysInGoal/${sleepEntries.length} días dentro del objetivo',
                    progress: sleepPercent,
                    color: AppColors.sleepAccent,
                  )
                : const _EmptyIndicatorCard(title: 'Sueño'),
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

  const _CircularIndicatorCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.bottomLabel,
    this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
                ),
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
                      trackColor: AppColors.surfaceVariant,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (progress != null)
                      Text(
                        'media',
                        style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10),
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
            style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
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

  const _EmptyIndicatorCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin datos',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
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

  const _BodyDataSection({required this.profile, required this.weightHistory});

  @override
  Widget build(BuildContext context) {
    final latestMetric = weightHistory.isNotEmpty ? weightHistory.last : null;
    final latestWeight = weightHistory.where((e) => e.weightKg != null).isNotEmpty
        ? weightHistory.where((e) => e.weightKg != null).last
        : null;
    final hasMeasurements = latestMetric != null &&
        (latestMetric.neckCm != null ||
            latestMetric.chestCm != null ||
            latestMetric.waistCm != null ||
            latestMetric.hipsCm != null);

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Datos corporales',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (latestMetric != null)
                Text(
                  'Última actualización ${dateFormat.format(latestMetric.date)}',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Weight row
          _DataRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Peso: ${latestWeight != null ? '${latestWeight.weightKg!.toStringAsFixed(1)} kg' : '--'}',
            detail: latestWeight != null
                ? 'Última actualización ${dateFormat.format(latestWeight.date)}'
                : null,
          ),
          const SizedBox(height: 10),
          // Measurements row
          _DataRow(
            icon: Icons.straighten_outlined,
            label: 'Medidas',
            detail: hasMeasurements
                ? 'Última actualización ${dateFormat.format(latestMetric.date)}'
                : 'Sin datos',
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
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.borderMedium),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Actualizar métricas'),
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
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
