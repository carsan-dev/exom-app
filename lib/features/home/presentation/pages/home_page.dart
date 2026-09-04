import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/stats_row.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/features/home/presentation/widgets/week_day_selector.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeView();
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
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: _HomeDateHeaderSkeleton()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: _HomeWeekSelectorSkeleton()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            const SliverToBoxAdapter(child: _HomeFeatureCardSkeleton()),
            const SliverToBoxAdapter(
              child: _HomeFeatureCardSkeleton(showSecondaryChip: false),
            ),
            const SliverToBoxAdapter(child: _HomeStatsRowSkeleton()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
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

// ---------------------------------------------------------------------------
// iOS-style collapsing large title header (SliverPersistentHeader).
//
// Expanded: 28px relative-date label + subtitle + calendar icon.
// Collapsed: 20px label only + calendar icon, with light glass tint behind.
// ---------------------------------------------------------------------------

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

class _HomeSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeSliverHeaderDelegate({required this.selectedDate});

  final DateTime selectedDate;

  // Expanded: big title (28px * 1.07 ≈ 30) + gap 4 + subtitle (~20) + padding
  static const double _max = 100.0;
  // Collapsed: compact title (~22) + vertical padding
  static const double _min = 56.0;

  @override
  double get maxExtent => _max;

  @override
  double get minExtent => _min;

  @override
  bool shouldRebuild(covariant _HomeSliverHeaderDelegate old) =>
      old.selectedDate != selectedDate;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final currentExtent = (_max - shrinkOffset).clamp(_min, _max).toDouble();
    final t = (shrinkOffset / (_max - _min)).clamp(0.0, 1.0);
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

    // Interpolated font: 28 → 20 px, spacing –0.8 → –0.4
    final fontSize = lerpDouble(28, 20, t)!;
    final letterSpacing = lerpDouble(-0.8, -0.4, t)!;
    // Subtitle fades out faster than the overall collapse
    final subtitleOpacity = (1.0 - t * 2.5).clamp(0.0, 1.0);
    // Glass tint behind collapsed header
    final glassTint = t * 0.85;

    return SizedBox(
      height: currentExtent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
          child: Container(
            color: palette.background.withValues(alpha: glassTint * 0.72),
            padding: EdgeInsets.fromLTRB(
              ExomSpacing.lg,
              lerpDouble(ExomSpacing.sm, ExomSpacing.lg, t)!,
              ExomSpacing.lg,
              ExomSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: palette.textPrimary,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          height: 1.07,
                          letterSpacing: letterSpacing,
                        ),
                      ),
                      if (subtitleOpacity > 0)
                        Opacity(
                          opacity: subtitleOpacity,
                          child: Text(
                            '$capitalDay $dayMonth',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/calendar'),
                  tooltip: AppLocalizations.of(context).openCalendarButton,
                  iconSize: 18,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
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
          ),
        ),
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
        context.read<HomeBloc>().add(HomeLoadRequested(date: selectedDate));
      },
      child: Stack(
        children: [
          const _HomeHeroAccent(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeSliverHeaderDelegate(selectedDate: selectedDate),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: WeekDaySelector()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: TodayTrainingCard(
                  summary: summary,
                  selectedDate: selectedDate,
                ),
              ),
              SliverToBoxAdapter(
                child: TodayDietCard(
                  summary: summary,
                  selectedDate: selectedDate,
                ),
              ),
              SliverToBoxAdapter(
                child: StatsRow(summary: summary, selectedDate: selectedDate),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
        context.read<HomeBloc>().add(HomeLoadRequested(date: selectedDate));
      },
      child: Stack(
        children: [
          const _HomeHeroAccent(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeSliverHeaderDelegate(selectedDate: selectedDate),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: WeekDaySelector()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: GlassCard(
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
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: StatsRow(summary: summary, selectedDate: selectedDate),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    final palette = context.exomPalette;

    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(0, -48),
        child: SizedBox(
          height: isDark ? 440 : 400,
          width: double.infinity,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.66, 1],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Opacity(
              opacity: isDark ? 0.86 : 0.72,
              child: CustomPaint(
                painter: _HomeHeroAccentPainter(
                  palette: palette,
                  isDark: isDark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeroAccentPainter extends CustomPainter {
  const _HomeHeroAccentPainter({required this.palette, required this.isDark});

  final ExomThemePalette palette;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final warm = isDark ? const Color(0xFF7A3B19) : const Color(0xFFC4AD96);
    final primaryTint = Color.lerp(
      palette.primary,
      warm,
      isDark ? 0.26 : 0.42,
    )!;

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.9, -1),
        end: const Alignment(0.85, 1),
        colors: isDark
            ? [
                warm.withValues(alpha: 0.055),
                palette.primary.withValues(alpha: 0.045),
                palette.background.withValues(alpha: 0),
              ]
            : [
                Colors.white.withValues(alpha: 0.32),
                warm.withValues(alpha: 0.16),
                palette.primary.withValues(alpha: 0.05),
                palette.background.withValues(alpha: 0),
              ],
        stops: isDark ? const [0, 0.5, 1] : const [0, 0.32, 0.62, 1],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    if (isDark) {
      _paintRibbon(
        canvas,
        size,
        centerY: 0.02,
        amplitude: 0.032,
        thickness: size.height * 0.28,
        phase: 0.75,
        drift: 0.6,
        colors: [
          Colors.transparent,
          warm.withValues(alpha: 0.07),
          palette.primary.withValues(alpha: 0.032),
          Colors.transparent,
        ],
        stops: const [0, 0.24, 0.58, 1],
      );
      _paintRibbon(
        canvas,
        size,
        centerY: 0.28,
        amplitude: 0.046,
        thickness: size.height * 0.22,
        phase: 2.35,
        drift: 1.3,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.012),
          primaryTint.withValues(alpha: 0.06),
          warm.withValues(alpha: 0.045),
          Colors.transparent,
        ],
        stops: const [0, 0.18, 0.46, 0.76, 1],
        blendMode: BlendMode.plus,
      );
      _paintRibbon(
        canvas,
        size,
        centerY: 0.54,
        amplitude: 0.054,
        thickness: size.height * 0.2,
        phase: 4.1,
        drift: 2.1,
        colors: [
          Colors.transparent,
          warm.withValues(alpha: 0.038),
          palette.primary.withValues(alpha: 0.052),
          Colors.transparent,
        ],
        stops: const [0, 0.2, 0.62, 1],
        blendMode: BlendMode.plus,
      );
      return;
    }

    _paintRibbon(
      canvas,
      size,
      centerY: 0.0,
      amplitude: 0.028,
      thickness: size.height * 0.26,
      phase: 0.9,
      drift: 0.55,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.34),
        warm.withValues(alpha: 0.16),
        Colors.transparent,
      ],
      stops: const [0, 0.22, 0.58, 1],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.24,
      amplitude: 0.036,
      thickness: size.height * 0.2,
      phase: 2.2,
      drift: 1.2,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.2),
        primaryTint.withValues(alpha: 0.12),
        warm.withValues(alpha: 0.13),
        Colors.transparent,
      ],
      stops: const [0, 0.18, 0.48, 0.76, 1],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.5,
      amplitude: 0.04,
      thickness: size.height * 0.18,
      phase: 4.65,
      drift: 2.0,
      colors: [
        Colors.transparent,
        primaryTint.withValues(alpha: 0.1),
        Colors.white.withValues(alpha: 0.18),
        Colors.transparent,
      ],
      stops: const [0, 0.28, 0.62, 1],
    );
  }

  void _paintRibbon(
    Canvas canvas,
    Size size, {
    required double centerY,
    required double amplitude,
    required double thickness,
    required double phase,
    required double drift,
    required List<Color> colors,
    required List<double> stops,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final path = _waveRibbon(
      size,
      centerY: centerY,
      amplitude: amplitude,
      thickness: thickness,
      phase: phase,
      drift: drift,
    );
    final bounds = path.getBounds().inflate(36);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
        stops: stops,
      ).createShader(bounds)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34)
      ..blendMode = blendMode;

    canvas.drawPath(path, paint);
  }

  Path _waveRibbon(
    Size size, {
    required double centerY,
    required double amplitude,
    required double thickness,
    required double phase,
    required double drift,
  }) {
    const sampleCount = 22;
    final startX = -size.width * 0.25;
    final endX = size.width * 1.25;
    final upper = <Offset>[];
    final lower = <Offset>[];

    for (var i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      final x = startX + ((endX - startX) * t);
      final y = _waveY(
        size,
        x,
        centerY: centerY,
        amplitude: amplitude,
        phase: phase,
        drift: drift,
      );
      upper.add(Offset(x, y - (thickness / 2)));
      lower.add(Offset(x, y + (thickness / 2)));
    }

    final path = Path();
    _addSmoothSegment(path, upper, moveToFirst: true);
    _addSmoothSegment(path, lower.reversed.toList());
    path.close();
    return path;
  }

  void _addSmoothSegment(
    Path path,
    List<Offset> points, {
    bool moveToFirst = false,
  }) {
    if (moveToFirst) {
      path.moveTo(points.first.dx, points.first.dy);
    } else {
      path.lineTo(points.first.dx, points.first.dy);
    }

    for (var i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }

    path.lineTo(points.last.dx, points.last.dy);
  }

  double _waveY(
    Size size,
    double x, {
    required double centerY,
    required double amplitude,
    required double phase,
    required double drift,
  }) {
    final normalizedX = x / size.width;
    final baseY = size.height * centerY;
    final primary =
        math.sin((normalizedX * math.pi * 1.75) + phase) *
        size.height *
        amplitude;
    final secondary =
        math.cos((normalizedX * math.pi * 3.4) - (phase * 1.8) + drift) *
        size.height *
        (amplitude * 0.34);
    final tertiary =
        math.sin((normalizedX * math.pi * 6.8) + (phase * 2.4) + drift) *
        size.height *
        (amplitude * 0.08);

    return baseY + primary + secondary + tertiary;
  }

  @override
  bool shouldRepaint(covariant _HomeHeroAccentPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.palette.background != palette.background ||
        oldDelegate.palette.primary != palette.primary;
  }
}
