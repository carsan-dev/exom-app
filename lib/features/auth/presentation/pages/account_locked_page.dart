import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class AccountLockedPage extends StatelessWidget {
  const AccountLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cuenta bloqueada',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tu cuenta ha sido bloqueada temporalmente.\nContacta a tu entrenador para más información.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                child: const Text('Volver al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
