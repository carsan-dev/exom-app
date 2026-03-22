import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/injection_container.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const _steps = [
    _OnboardingStep(
      icon: Icons.person_outline,
      title: 'Completa tu perfil',
      subtitle: 'Añade tus datos para que el entrenador pueda personalizarte el plan.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Logo
              SvgPicture.asset('assets/images/logo.svg', height: 32),
              const SizedBox(height: 40),
              // Greeting
              const Text(
                '¡Bienvenido\na EXOM!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sigue estos pasos para comenzar tu experiencia.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              // Steps
              ...List.generate(_steps.length, (i) {
                return _StepTile(index: i + 1, step: _steps[i]);
              }),
              const Spacer(),
              // CTA
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
                  child: const Text(
                    'Hacerlo más tarde',
                    style: TextStyle(color: AppColors.textMuted),
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
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _StepTile extends StatelessWidget {
  final int index;
  final _OnboardingStep step;

  const _StepTile({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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
