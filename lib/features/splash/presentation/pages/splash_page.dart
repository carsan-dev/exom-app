import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/injection_container.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _entryDuration = Duration(milliseconds: 2100);
  static const _holdDuration = Duration(milliseconds: 250);
  static const _exitDuration = Duration(milliseconds: 650);

  late final AnimationController _entry;
  late final AnimationController _pulse;
  late final AnimationController _exit;
  late final Future<AppUpdateDecision> _updateDecisionFuture;

  late final Animation<double> _bgFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _ringSweep;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();
    _updateDecisionFuture = sl<AppUpdateService>().checkForUpdates();

    _entry = AnimationController(vsync: this, duration: _entryDuration);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _exit = AnimationController(
      vsync: this,
      duration: _exitDuration,
      value: 1.0,
    );

    _bgFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );

    _glowOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.25, 0.85, curve: Curves.easeInOut),
    );

    _ringSweep = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.30, 1.0, curve: Curves.easeInOutCubic),
    );

    _taglineFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.60, 0.95, curve: Curves.easeOut),
    );

    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entry,
            curve: const Interval(0.60, 0.95, curve: Curves.easeOutCubic),
          ),
        );

    _entry.forward().whenComplete(_holdThenExit);
  }

  Future<void> _holdThenExit() async {
    await Future<void>.delayed(_holdDuration);
    if (!mounted) return;

    final shouldContinue = await _handlePendingUpdate();
    if (!mounted || !shouldContinue) return;

    await _exit.reverse(from: 1.0);
    if (!mounted) return;
    _navigate();
  }

  Future<bool> _handlePendingUpdate() async {
    final AppUpdateDecision decision;
    try {
      decision = await _updateDecisionFuture.timeout(
        const Duration(seconds: 6),
      );
    } catch (error) {
      debugPrint('[SPLASH] Skipping update gate: $error');
      return mounted;
    }

    if (!mounted || !decision.shouldPrompt) {
      return mounted;
    }

    final l10n = AppLocalizations.of(context);
    final title = decision.title.isNotEmpty
        ? decision.title
        : decision.isBlocking
        ? l10n.requiredUpdateTitle
        : l10n.recommendedUpdateTitle;
    final message = decision.message.isNotEmpty
        ? decision.message
        : decision.isBlocking
        ? l10n.requiredUpdateMessage
        : l10n.recommendedUpdateMessage;

    if (decision.isBlocking) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => _openStore(decision),
                child: Text(l10n.update),
              ),
            ],
          ),
        ),
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.continueButton),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(true);
              await _openStore(decision);
            },
            child: Text(l10n.update),
          ),
        ],
      ),
    );

    return result ?? true;
  }

  Future<void> _openStore(AppUpdateDecision decision) async {
    final launched = await sl<AppUpdateService>().openStore(decision);
    if (!mounted || launched) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.updateStoreNotOpenedError)));
  }

  void _navigate() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }
    final onboardingDone = sl<LocalStorage>().isOnboardingCompleteFor(
      uid: user.uid,
      email: user.email,
    );
    context.go(onboardingDone ? AppRoutes.home : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final logoAsset = isLight
        ? 'assets/images/logo_dark.svg'
        : 'assets/images/logo.svg';

    return Scaffold(
      backgroundColor: palette.gradientStart,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _exit, curve: Curves.easeInOut),
        child: AnimatedBuilder(
          animation: Listenable.merge([_entry, _pulse]),
          builder: (context, _) {
            return ExomAnimatedBackground(
              intensity: 0.45,
              child: Stack(
                children: [
                  _RadialGlow(
                    color: palette.primary,
                    opacity: _bgFade.value * 0.2,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Spacer(flex: 3),
                        _LogoMark(
                          asset: logoAsset,
                          scale: _logoScale.value,
                          fade: _logoFade.value,
                          glow: _glowOpacity.value,
                          pulse: _pulse.value,
                          ringSweep: _ringSweep.value,
                          accent: palette.primary,
                          discFill: palette.glassBackground,
                        ),
                        const SizedBox(height: 36),
                        FadeTransition(
                          opacity: _taglineFade,
                          child: SlideTransition(
                            position: _taglineSlide,
                            child: _Tagline(
                              palette: palette,
                              tagline: l10n.splashTagline,
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        Opacity(
                          opacity: _taglineFade.value,
                          child: _LoadingDots(
                            color: palette.primary,
                            t: _pulse.value,
                          ),
                        ),
                        SizedBox(height: 48 + bottomInset + 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RadialGlow extends StatelessWidget {
  const _RadialGlow({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.9,
            colors: [
              color.withValues(alpha: 0.06 * opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.asset,
    required this.scale,
    required this.fade,
    required this.glow,
    required this.pulse,
    required this.ringSweep,
    required this.accent,
    required this.discFill,
  });

  final String asset;
  final double scale;
  final double fade;
  final double glow;
  final double pulse;
  final double ringSweep;
  final Color accent;
  final Color discFill;

  @override
  Widget build(BuildContext context) {
    final pulseFactor = 0.85 + (pulse * 0.15);
    const outerRingSize = 320.0;
    const glowHaloSize = 280.0;
    const glassDiscSize = 272.0;

    return SizedBox(
      width: outerRingSize,
      height: outerRingSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          Transform.rotate(
            angle: ringSweep * math.pi * 2,
            child: CustomPaint(
              size: const Size(320, 320),
              painter: _RingPainter(
                progress: ringSweep,
                color: accent,
                opacity: glow,
              ),
            ),
          ),
          // Glow halo
          Container(
            width: glowHaloSize,
            height: glowHaloSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.11 * glow * pulseFactor),
                  blurRadius: 54,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.04 * glow),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Glass disc behind logo
          Container(
            width: glassDiscSize,
            height: glassDiscSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: discFill,
              border: Border.all(
                color: accent.withValues(alpha: 0.12 * glow),
                width: 1.2,
              ),
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.04 * glow),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Logo
          Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: fade,
              child: SvgPicture.asset(asset, height: 84, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.opacity,
  });

  final double progress;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.05 * opacity);
    canvas.drawCircle(center, radius, trackPaint);

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.45 * opacity),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = (0.25 + progress * 0.75) * 2 * math.pi;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.palette, required this.tagline});

  final ExomThemePalette palette;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'EXOM',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            height: 1,
            shadows: const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 48,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, palette.primary, Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tagline,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.5,
            shadows: const [
              Shadow(
                color: Color(0x55000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final phase = (t + i * 0.33) % 1.0;
        final scale = 0.6 + (math.sin(phase * math.pi * 2) * 0.5 + 0.5) * 0.5;
        final alpha = 0.3 + (math.sin(phase * math.pi * 2) * 0.5 + 0.5) * 0.7;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: alpha),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: alpha * 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
