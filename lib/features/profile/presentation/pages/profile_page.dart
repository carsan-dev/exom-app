import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
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
            return _ProfileContent(profile: state.profile, isUploadingAvatar: false, weightHistory: state.weightHistory);
          }
          if (state is ProfileAvatarUploading) {
            return _ProfileContent(profile: state.profile, isUploadingAvatar: true, weightHistory: const []);
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

  const _ProfileContent({required this.profile, required this.isUploadingAvatar, required this.weightHistory});

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
          _StatsRow(profile: profile),
          if (profile.currentWeightKg != null || profile.currentBmi != null)
            _BodyMetricsCard(profile: profile),
          _WeightChartCard(weightHistory: weightHistory),
          _MetricsButton(),
        ],
      ),
    );
  }
}

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
        return level ?? 'Sin nivel';
    }
  }

  Color _levelColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'BEGINNER':
        return AppColors.secondary;
      case 'INTERMEDIATE':
        return AppColors.warning;
      case 'ADVANCED':
        return AppColors.error;
      default:
        return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(profile.level);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          GestureDetector(
            onTap: isUploadingAvatar ? null : () => _pickAndUpload(context),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: isUploadingAvatar
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : profile.avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: profile.avatarUrl!,
                                width: 104,
                                height: 104,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 52,
                                ),
                              ),
                            )
                          : const Icon(Icons.person, color: AppColors.primary, size: 52),
                ),
                if (!isUploadingAvatar)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.fullName.isNotEmpty ? profile.fullName : 'Usuario EXOM',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (profile.email != null) ...[
            const SizedBox(height: 4),
            Text(
              profile.email!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: levelColor.withOpacity(0.4)),
            ),
            child: Text(
              _levelLabel(profile.level),
              style: TextStyle(
                color: levelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (profile.goal != null) ...[
            const SizedBox(height: 8),
            Text(
              'Objetivo: ${profile.goal!}',
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ProfileEntity profile;

  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '${profile.streakDays}',
            label: 'Racha',
            icon: '🔥',
            color: const Color(0xFFFF6B35),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          _StatItem(
            value: '${profile.totalTrainings}',
            label: 'Entrenamientos',
            icon: '💪',
            color: AppColors.primary,
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          _StatItem(
            value: profile.currentWeightKg != null
                ? '${profile.currentWeightKg!.toStringAsFixed(1)} kg'
                : '--',
            label: 'Peso actual',
            icon: '⚖️',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _BodyMetricsCard extends StatelessWidget {
  final ProfileEntity profile;

  const _BodyMetricsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
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
            'Métricas corporales',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (profile.currentWeightKg != null)
                Expanded(
                  child: _MetricTile(
                    label: 'Peso',
                    value: '${profile.currentWeightKg!.toStringAsFixed(1)}',
                    unit: 'kg',
                    icon: Icons.monitor_weight_outlined,
                    color: AppColors.primary,
                  ),
                ),
              if (profile.currentBmi != null)
                Expanded(
                  child: _MetricTile(
                    label: 'IMC',
                    value: '${profile.currentBmi!.toStringAsFixed(1)}',
                    unit: '',
                    icon: Icons.bar_chart_outlined,
                    color: _bmiColor(profile.currentBmi!),
                  ),
                ),
              if (profile.heightCm != null)
                Expanded(
                  child: _MetricTile(
                    label: 'Talla',
                    value: '${profile.heightCm!.toInt()}',
                    unit: 'cm',
                    icon: Icons.height,
                    color: AppColors.secondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.secondary;
    if (bmi < 25) return AppColors.success;
    if (bmi < 30) return AppColors.warning;
    return AppColors.error;
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WeightChartCard extends StatelessWidget {
  final List<BodyMetricEntity> weightHistory;

  const _WeightChartCard({required this.weightHistory});

  @override
  Widget build(BuildContext context) {
    final entries = weightHistory.where((e) => e.weightKg != null).toList();

    if (entries.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de peso',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 32),
            Center(
              child: Text(
                'Aún no hay métricas registradas',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    final weights = entries.map((e) => e.weightKg!).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxWeight = weights.reduce((a, b) => a > b ? a : b) + 1;

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg!);
    }).toList();

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
                'Historial de peso',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Últimas ${entries.length} mediciones',
                style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                minY: minWeight,
                maxY: maxWeight,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
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
                          AppColors.primary.withOpacity(0.3),
                          AppColors.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () => context.push('/profile/metrics'),
        icon: const Icon(Icons.add_chart, size: 18),
        label: const Text('Actualizar métricas'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
