import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ExomStaticBackground extends StatelessWidget {
  const ExomStaticBackground({
    super.key,
    required this.child,
    this.intensity = 1,
  });

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedIntensity = intensity.clamp(0.25, 1.25).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: _exomBaseGradient(isDark)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: _exomVeilGradient(
              palette,
              isDark,
              intensity: resolvedIntensity,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class ExomAnimatedBackground extends StatefulWidget {
  const ExomAnimatedBackground({
    super.key,
    required this.child,
    this.intensity = 1,
    this.showBase = true,
    this.showVeil = true,
  });

  final Widget child;
  final double intensity;
  final bool showBase;
  final bool showVeil;

  @override
  State<ExomAnimatedBackground> createState() => _ExomAnimatedBackgroundState();
}

class _ExomAnimatedBackgroundState extends State<ExomAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final intensity = widget.intensity.clamp(0.25, 1.25).toDouble();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.showBase)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _exomBaseGradient(isDark),
                  ),
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _ExomBackgroundPainter(
                    progress: _controller.value,
                    palette: palette,
                    isDark: isDark,
                    intensity: intensity,
                    showVeil: widget.showVeil,
                  ),
                ),
              ),
              child ?? const SizedBox.shrink(),
            ],
          );
        },
      ),
    );
  }
}

class _ExomBackgroundPainter extends CustomPainter {
  const _ExomBackgroundPainter({
    required this.progress,
    required this.palette,
    required this.isDark,
    required this.intensity,
    required this.showVeil,
  });

  final double progress;
  final ExomThemePalette palette;
  final bool isDark;
  final double intensity;
  final bool showVeil;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final phase = progress * math.pi * 2;

    if (showVeil) {
      _paintVeil(canvas, size);
    }

    if (isDark) {
      _paintDarkWaves(canvas, size, phase);
      return;
    }

    _paintLightWaves(canvas, size, phase);
  }

  void _paintVeil(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = _exomVeilGradient(
        palette,
        isDark,
        intensity: intensity,
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  void _paintDarkWaves(Canvas canvas, Size size, double phase) {
    final warm = const Color(0xFF7A3B19);

    _paintRibbon(
      canvas,
      size,
      centerY: -0.1,
      amplitude: 0.03,
      thickness: size.height * 0.32,
      phase: phase + 0.35,
      drift: 0.6,
      blurSigma: 62,
      colors: [
        Colors.transparent,
        warm.withValues(alpha: 0.035),
        palette.primary.withValues(alpha: 0.012 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.2, 0.58, 1.0],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.14,
      amplitude: 0.042,
      thickness: size.height * 0.24,
      phase: -phase + 1.1,
      drift: 1.25,
      blurSigma: 52,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.008 * intensity),
        palette.primary.withValues(alpha: 0.025 * intensity),
        warm.withValues(alpha: 0.028),
        Colors.transparent,
      ],
      stops: const [0.0, 0.14, 0.44, 0.76, 1.0],
      blendMode: BlendMode.plus,
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.34,
      amplitude: 0.052,
      thickness: size.height * 0.18,
      phase: (phase * 2) + 0.4,
      drift: 2,
      blurSigma: 42,
      colors: [
        Colors.transparent,
        palette.primary.withValues(alpha: 0.022 * intensity),
        Colors.white.withValues(alpha: 0.01 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.24, 0.6, 1.0],
      blendMode: BlendMode.plus,
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.56,
      amplitude: 0.06,
      thickness: size.height * 0.24,
      phase: (-phase * 2) + 1.6,
      drift: 0.85,
      blurSigma: 56,
      colors: [
        Colors.transparent,
        warm.withValues(alpha: 0.032),
        palette.primary.withValues(alpha: 0.042 * intensity),
        warm.withValues(alpha: 0.035),
        Colors.transparent,
      ],
      stops: const [0.0, 0.12, 0.42, 0.78, 1.0],
      blendMode: BlendMode.plus,
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.78,
      amplitude: 0.05,
      thickness: size.height * 0.2,
      phase: (phase * 3) + 0.9,
      drift: 2.4,
      blurSigma: 44,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.007 * intensity),
        palette.primary.withValues(alpha: 0.028 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.28, 0.66, 1.0],
      blendMode: BlendMode.plus,
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 1.02,
      amplitude: 0.036,
      thickness: size.height * 0.3,
      phase: -phase + 2.2,
      drift: 1.8,
      blurSigma: 60,
      colors: [
        Colors.transparent,
        warm.withValues(alpha: 0.03),
        palette.primary.withValues(alpha: 0.015 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.18, 0.58, 1.0],
    );
  }

  void _paintLightWaves(Canvas canvas, Size size, double phase) {
    const warm = Color(0xFFE6D6BE);

    _paintRibbon(
      canvas,
      size,
      centerY: -0.08,
      amplitude: 0.028,
      thickness: size.height * 0.28,
      phase: phase + 0.5,
      drift: 0.55,
      blurSigma: 54,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.07),
        warm.withValues(alpha: 0.028),
        Colors.transparent,
      ],
      stops: const [0.0, 0.22, 0.58, 1.0],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.16,
      amplitude: 0.034,
      thickness: size.height * 0.2,
      phase: -phase + 1.15,
      drift: 1.3,
      blurSigma: 42,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.055),
        _mix(
          palette.primary,
          Colors.white,
          0.66,
        ).withValues(alpha: 0.017 * intensity),
        warm.withValues(alpha: 0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.18, 0.48, 0.76, 1.0],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.4,
      amplitude: 0.04,
      thickness: size.height * 0.18,
      phase: (phase * 2) + 0.25,
      drift: 2,
      blurSigma: 34,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.04),
        _mix(
          palette.primary,
          Colors.white,
          0.58,
        ).withValues(alpha: 0.024 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.26, 0.6, 1.0],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.66,
      amplitude: 0.044,
      thickness: size.height * 0.16,
      phase: (-phase * 2) + 1.45,
      drift: 0.9,
      blurSigma: 36,
      colors: [
        Colors.transparent,
        warm.withValues(alpha: 0.035),
        _mix(
          palette.primary,
          Colors.white,
          0.68,
        ).withValues(alpha: 0.018 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.22, 0.62, 1.0],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 0.88,
      amplitude: 0.032,
      thickness: size.height * 0.22,
      phase: (phase * 3) + 2.1,
      drift: 2.35,
      blurSigma: 46,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.05),
        warm.withValues(alpha: 0.028),
        Colors.transparent,
      ],
      stops: const [0.0, 0.28, 0.64, 1.0],
    );
    _paintRibbon(
      canvas,
      size,
      centerY: 1.08,
      amplitude: 0.026,
      thickness: size.height * 0.28,
      phase: -phase + 0.85,
      drift: 1.65,
      blurSigma: 56,
      colors: [
        Colors.transparent,
        warm.withValues(alpha: 0.03),
        Colors.white.withValues(alpha: 0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.18, 0.58, 1.0],
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
    required double blurSigma,
    required List<Color> colors,
    required List<double> stops,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final path = _waveRibbon(
      size,
      centerY: centerY,
      amplitude: amplitude,
      thickness: thickness + blurSigma * 0.8,
      phase: phase,
      drift: drift,
    );
    final bounds = path.getBounds().inflate(32);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
        stops: stops,
      ).createShader(bounds)
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
    const sampleCount = 24;
    final startX = -size.width * 0.28;
    final endX = size.width * 1.28;
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
    final primaryWave =
        math.sin((normalizedX * math.pi * 1.8) + phase) *
        size.height *
        amplitude;
    final secondaryWave =
        math.cos((normalizedX * math.pi * 3.6) - (phase * 2) + drift) *
        size.height *
        (amplitude * 0.38);
    final tertiaryWave =
        math.sin((normalizedX * math.pi * 7.2) + (phase * 3) + (drift * 0.7)) *
        size.height *
        (amplitude * 0.1);

    return baseY + primaryWave + secondaryWave + tertiaryWave;
  }

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  @override
  bool shouldRepaint(covariant _ExomBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.intensity != intensity ||
        oldDelegate.showVeil != showVeil ||
        oldDelegate.palette.gradientStart != palette.gradientStart ||
        oldDelegate.palette.gradientEnd != palette.gradientEnd ||
        oldDelegate.palette.primary != palette.primary;
  }
}

LinearGradient _exomBaseGradient(bool isDark) {
  if (isDark) {
    return const LinearGradient(
      begin: Alignment(-0.85, -1),
      end: Alignment(0.95, 1),
      colors: [
        Color(0xFF140904),
        Color(0xFF1A0D05),
        Color(0xFF261209),
        Color(0xFF3A1D0E),
      ],
      stops: [0.0, 0.24, 0.68, 1.0],
    );
  }

  return const LinearGradient(
    begin: Alignment(-0.8, -1),
    end: Alignment(0.9, 1),
    colors: [
      Color(0xFFFFFEFB),
      Color(0xFFF7F1E6),
      Color(0xFFF0E6D8),
      Color(0xFFE5D8C3),
    ],
    stops: [0.0, 0.22, 0.72, 1.0],
  );
}

LinearGradient _exomVeilGradient(
  ExomThemePalette palette,
  bool isDark, {
  required double intensity,
}) {
  return LinearGradient(
    begin: const Alignment(-1, -0.75),
    end: const Alignment(1, 1),
    colors: isDark
        ? [
            const Color(0x47140704),
            const Color(0x147A3A18),
            palette.primary.withValues(alpha: 0.03 * intensity),
          ]
        : [
            Colors.white.withValues(alpha: 0.62),
            const Color(0x14F0E6D7),
            Color.lerp(
              palette.primary,
              Colors.white,
              0.7,
            )!.withValues(alpha: 0.03 * intensity),
          ],
    stops: const [0.0, 0.44, 1.0],
  );
}
