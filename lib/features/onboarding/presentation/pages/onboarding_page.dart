import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/injection_container.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const _steps = [
    _OnboardingStep(
      icon: Icons.person_outline,
      title: 'Completa tu perfil',
      subtitle:
          'Añade tus datos para que el entrenador pueda personalizarte el plan.',
    ),
    _OnboardingStep(
      icon: Icons.sports_gymnastics,
      title: 'Espera a tu entrenador',
      subtitle: 'Te asignaremos un entrenador personal que diseñará tu rutina.',
    ),
    _OnboardingStep(
      icon: Icons.rocket_launch_outlined,
      title: 'Empieza tu transformación',
      subtitle: 'Sigue tu plan, registra tu progreso y alcanza tus objetivos.',
    ),
  ];

  String _logoAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? 'assets/images/logo_dark.svg'
        : 'assets/images/logo.svg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              SvgPicture.asset(_logoAsset(context), height: 32),
              const SizedBox(height: 40),
              Text(
                '¡Bienvenido\na EXOM!',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sigue estos pasos para comenzar tu experiencia.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              ...List.generate(_steps.length, (i) {
                return _StepTile(index: i + 1, step: _steps[i]);
              }),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await sl<LocalStorage>().setOnboardingComplete();
                    if (context.mounted) context.go('/profile');
                  },
                  child: const Text('Completar perfil'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await sl<LocalStorage>().setOnboardingComplete();
                    if (context.mounted) context.go('/');
                  },
                  child: Text(
                    'Hacerlo más tarde',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  step.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.4,
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
