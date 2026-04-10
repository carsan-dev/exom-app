import 'dart:ui';

import 'package:flutter/material.dart';

void showPremiumFeatureMessage(
  BuildContext context, {
  String message = 'Funcion disponible en el plan premium',
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class PremiumLockedOverlay extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final String? customMessage;
  final String subtitle;
  final VoidCallback? onTap;
  final double blurSigma;
  final double borderRadius;

  const PremiumLockedOverlay({
    super.key,
    required this.child,
    required this.isLocked,
    this.customMessage,
    this.subtitle = 'Disponible en el plan completo',
    this.onTap,
    this.blurSigma = 6,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: child,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    const Color(0xFF120E0A).withValues(alpha: 0.54),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _PremiumInfoCard(
                title: customMessage ?? 'Función premium',
                subtitle: subtitle,
                compact: false,
              ),
            ),
          ),
          if (onTap != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
        ],
      ),
    );
  }
}

class PremiumLockedPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? preview;
  final VoidCallback? onContactTrainer;
  final String ctaLabel;

  const PremiumLockedPage({
    super.key,
    this.title = 'Esta función está disponible en el plan premium',
    this.subtitle = 'Contacta con tu entrenador para acceder al plan completo.',
    this.preview,
    this.onContactTrainer,
    this.ctaLabel = 'Contactar con mi entrenador',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (preview != null) ...[
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: preview,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.32),
                    const Color(0xFF120E0A).withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
        ] else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF25160F), const Color(0xFF120E0A)],
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.14),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD86B).withValues(alpha: 0.28),
                          const Color(0xFFFFB300).withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outlined,
                      color: Color(0xFFFFB300),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Premium',
                      style: TextStyle(
                        color: Color(0xFFFFB300),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                      height: 1.45,
                    ),
                  ),
                  if (onContactTrainer != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onContactTrainer,
                        icon: const Icon(Icons.chat_outlined),
                        label: Text(ctaLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PremiumLockedInline extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final VoidCallback? onTap;

  const PremiumLockedInline({
    super.key,
    required this.child,
    required this.isLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: child,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.26),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 8, right: 8, child: _PremiumBadge(compact: true)),
          if (onTap != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
        ],
      ),
    );
  }
}

class PremiumLockedSection extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final String label;
  final VoidCallback? onTap;

  const PremiumLockedSection({
    super.key,
    required this.child,
    required this.isLocked,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: child,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    const Color(0xFF120E0A).withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _PremiumInfoCard(
                title: '$label — Premium',
                subtitle: 'Disponible en el plan completo',
                compact: true,
              ),
            ),
          ),
          if (onTap != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;

  const _PremiumInfoCard({
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A140F).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PremiumBadge(compact: compact),
          SizedBox(width: compact ? 10 : 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: compact ? 11 : 12,
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

class _PremiumBadge extends StatelessWidget {
  final bool compact;

  const _PremiumBadge({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 14.0 : 18.0;

    return Container(
      width: compact ? 28 : 34,
      height: compact ? 28 : 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFFFD86B), const Color(0xFFFFB300)],
        ),
      ),
      child: Icon(
        Icons.lock_outlined,
        color: const Color(0xFF1D1409),
        size: size,
      ),
    );
  }
}
