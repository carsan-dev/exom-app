import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/core/theme/app_theme.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class AccountLockedPage extends StatelessWidget {
  const AccountLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  color: palette.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 40, color: palette.error),
              ),
              const SizedBox(height: 24),
              Text(
                context.copy('Cuenta bloqueada', 'Account locked'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.copy(
                  'Tu cuenta ha sido bloqueada temporalmente.\nContacta a tu entrenador para más información.',
                  'Your account has been temporarily locked.\nContact your coach for more information.',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: palette.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                child: Text(
                  context.copy('Volver al inicio de sesión', 'Back to login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
