import 'package:flutter/material.dart';

class TrialBanner extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback? onSubscribe;

  const TrialBanner({
    super.key,
    required this.daysRemaining,
    this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = daysRemaining <= 3;
    final color = isUrgent ? Colors.red.shade700 : const Color(0xFFFFB300);
    final bgColor = isUrgent
        ? Colors.red.shade700.withValues(alpha: 0.1)
        : const Color(0xFFFFB300).withValues(alpha: 0.1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Periodo de prueba: $daysRemaining ${daysRemaining == 1 ? 'día restante' : 'días restantes'}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (onSubscribe != null)
              TextButton(
                onPressed: onSubscribe,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Suscribirse'),
              ),
          ],
        ),
      ),
    );
  }
}
