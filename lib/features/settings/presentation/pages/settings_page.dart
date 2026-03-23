import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/services/fcm_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/injection_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled =
        sl<LocalStorage>().getSetting<bool>(
          'push_notifications_enabled',
          defaultValue: true,
        ) ??
        true;
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _busy = true);

    await sl<LocalStorage>().saveSetting('push_notifications_enabled', enabled);
    await FirebaseMessaging.instance.setAutoInitEnabled(enabled);

    if (enabled) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await sl<FcmService>().init();
    } else {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        // Best effort only.
      }
    }

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _busy = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Notificaciones activadas para este dispositivo'
              : 'Notificaciones desactivadas en este dispositivo',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearOfflineCache() async {
    await sl<LocalStorage>().clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caché offline borrada correctamente'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCredits() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Créditos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'EXOM combina app móvil en Flutter, backend en NestJS y servicios de Firebase, Supabase y Cloudflare para acompañar el seguimiento diario de entrenamiento y nutrición.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SettingsGroup(
            title: 'Cuenta',
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Editar perfil',
                subtitle: 'Foto, objetivo y datos visibles en tu ficha',
                onTap: () => context.push(AppRoutes.profile),
              ),
              _SettingsTile(
                icon: Icons.straighten_outlined,
                title: 'Mis métricas',
                subtitle: 'Peso, masa muscular, sueño y medidas corporales',
                onTap: () => context.push('/profile/metrics'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            title: 'Notificaciones',
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notificaciones push',
                subtitle: 'Avisos de entrenador, seguimiento y recordatorios',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: _busy ? null : _toggleNotifications,
                ),
                onTap: _busy
                    ? null
                    : () => _toggleNotifications(!_notificationsEnabled),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            title: 'Datos y soporte',
            children: [
              _SettingsTile(
                icon: Icons.cloud_off_outlined,
                title: 'Modo offline',
                subtitle:
                    'La app conserva el ultimo Home, Perfil, Calendario, Dieta y Entreno cargados',
                onTap: null,
              ),
              _SettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Borrar caché local',
                subtitle: 'Elimina datos offline guardados en este dispositivo',
                onTap: _clearOfflineCache,
              ),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                title: 'Enviar feedback',
                subtitle: 'Comparte dudas, incidencias o feedback técnico',
                onTap: () => context.push(AppRoutes.feedback),
              ),
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Ayuda y FAQ',
                subtitle: 'Preguntas frecuentes, uso offline y soporte',
                onTap: () => context.push(AppRoutes.help),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            title: 'Aplicación',
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Versión',
                subtitle: 'Build actual del cliente móvil',
                trailing: const Text(
                  '1.0.0',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
                ),
                onTap: null,
              ),
              _SettingsTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Créditos',
                subtitle: 'Tecnología y stack del producto',
                onTap: _showCredits,
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
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
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? const Icon(
                  Icons.chevron_right,
                  color: AppColors.textDisabled,
                  size: 18,
                )
              : null),
      onTap: onTap,
    );
  }
}
