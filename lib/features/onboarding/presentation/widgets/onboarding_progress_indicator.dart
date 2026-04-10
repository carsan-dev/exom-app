import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isPast = index < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: isActive
              ? GlassDecoration.accentCard(palette.primary, borderRadius: 999)
              : BoxDecoration(
                  color: isPast
                      ? palette.primary.withValues(alpha: 0.7)
                      : palette.glassBackground,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isPast
                        ? palette.primary.withValues(alpha: 0.24)
                        : palette.glassBorder.withValues(alpha: 0.14),
                    width: 0.5,
                  ),
                ),
        );
      }),
    );
  }
}
