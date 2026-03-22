import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Cuenta'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Editar perfil',
            onTap: () => context.push(AppRoutes.profile),
          ),
          _SettingsTile(
            icon: Icons.fitness_center_outlined,
            title: 'Mis métricas',
            onTap: () => context.push('/profile/metrics'),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Soporte'),
          _SettingsTile(
            icon: Icons.feedback_outlined,
            title: 'Enviar feedback',
            onTap: () => context.push(AppRoutes.feedback),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Ayuda y FAQ',
            onTap: () => context.push(AppRoutes.help),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Aplicación'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Versión',
            trailing: const Text(
              '1.0.0',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
            ),
            onTap: null,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 18)
              : null),
      onTap: onTap,
      tileColor: Colors.transparent,
    );
  }
}
