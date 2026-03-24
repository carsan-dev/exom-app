import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
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
      ),
    );
  }

  Future<void> _clearOfflineCache() async {
    await sl<LocalStorage>().clearCache();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caché offline borrada correctamente')),
    );
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    await context.read<AppPreferencesCubit>().setThemeMode(themeMode);
    if (!mounted) return;

    final themeLabel = switch (themeMode) {
      ThemeMode.system => 'Sistema',
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Tema $themeLabel aplicado')));
  }

  void _showCredits() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _CreditsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppPreferencesCubit, AppPreferencesState>(
      builder: (context, preferences) {
        final theme = Theme.of(context);
        final palette = context.exomPalette;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Ajustes'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SettingsGroup(
                title: 'Apariencia',
                children: [
                  _ThemeModeTile(
                    icon: Icons.phone_android_outlined,
                    title: 'Sistema',
                    subtitle:
                        'Sigue automáticamente el modo configurado en tu dispositivo',
                    selected: preferences.themeMode == ThemeMode.system,
                    onTap: () => _setThemeMode(ThemeMode.system),
                  ),
                  _ThemeModeTile(
                    icon: Icons.light_mode_outlined,
                    title: 'Claro',
                    subtitle:
                        'Activa una versión luminosa y cálida alineada con la paleta del producto',
                    selected: preferences.themeMode == ThemeMode.light,
                    onTap: () => _setThemeMode(ThemeMode.light),
                  ),
                  _ThemeModeTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Oscuro',
                    subtitle:
                        'Mantiene la experiencia nocturna actual para reducir brillo y fatiga visual',
                    selected: preferences.themeMode == ThemeMode.dark,
                    onTap: () => _setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    subtitle:
                        'Avisos de entrenador, seguimiento y recordatorios',
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
                    subtitle:
                        'Elimina datos offline guardados en este dispositivo',
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
                    trailing: Text(
                      '1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textDisabled,
                        fontSize: 13,
                      ),
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
                  foregroundColor: palette.error,
                  side: BorderSide(color: palette.error),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreditsSheet extends StatelessWidget {
  const _CreditsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créditos',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'EXOM combina app móvil en Flutter, backend en NestJS y servicios de Firebase, Supabase y Cloudflare para acompañar el seguimiento diario de entrenamiento y nutrición.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSoft),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textDisabled,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: palette.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: palette.textPrimary,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textDisabled,
          fontSize: 12,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: palette.textDisabled, size: 18)
              : null),
      onTap: onTap,
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return ListTile(
      onTap: onTap,
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? palette.primarySoft : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: selected ? palette.primary : palette.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textDisabled,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? palette.primary : palette.textDisabled,
      ),
    );
  }
}
