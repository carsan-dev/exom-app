import 'dart:ui';
import 'package:flutter/material.dart';

/// Wraps [child] with a blur + lock overlay when [isLocked] is true.
class PremiumLockedOverlay extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final String? customMessage;

  const PremiumLockedOverlay({
    super.key,
    required this.child,
    required this.isLocked,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ClipRect(
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outlined,
                        color: Color(0xFFFFB300),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        customMessage ?? 'Función premium',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Disponible en el plan completo',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen premium locked page (e.g., Feedback for LOW_TICKET).
class PremiumLockedPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onContactTrainer;

  const PremiumLockedPage({
    super.key,
    this.title = 'Esta función está disponible en el plan premium',
    this.subtitle = 'Contacta con tu entrenador para acceder al plan completo.',
    this.onContactTrainer,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outlined,
                color: Color(0xFFFFB300),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (onContactTrainer != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onContactTrainer,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Contactar con mi entrenador'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline blur for small elements (e.g., a macro chip).
class PremiumLockedInline extends StatelessWidget {
  final Widget child;
  final bool isLocked;

  const PremiumLockedInline({
    super.key,
    required this.child,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ClipRect(
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: Icon(
                    Icons.lock_outlined,
                    color: Color(0xFFFFB300),
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section-level blur with a label (e.g., "Ingredientes — Premium").
class PremiumLockedSection extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final String label;

  const PremiumLockedSection({
    super.key,
    required this.child,
    required this.isLocked,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ClipRect(
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outlined,
                        color: Color(0xFFFFB300),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$label — Premium',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
