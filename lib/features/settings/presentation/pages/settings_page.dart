import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
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
    final isEnglish = context.isEnglish;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AppPreferencesCubit>().setThemeMode(themeMode);

    final themeLabel = switch (themeMode) {
      ThemeMode.system => isEnglish ? 'System' : 'Sistema',
      ThemeMode.light => isEnglish ? 'Light' : 'Claro',
      ThemeMode.dark => isEnglish ? 'Dark' : 'Oscuro',
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isEnglish ? '$themeLabel theme applied' : 'Tema $themeLabel aplicado',
        ),
      ),
    );
  }

  Future<void> _setUnitSystem(UnitSystem unitSystem) async {
    final isEnglish = context.isEnglish;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AppPreferencesCubit>().setUnitSystem(unitSystem);

    final unitLabel = switch (unitSystem) {
      UnitSystem.metric => isEnglish ? 'Metric' : 'Métrico',
      UnitSystem.imperial => 'Imperial',
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isEnglish
              ? '$unitLabel units applied'
              : 'Unidades $unitLabel aplicadas',
        ),
      ),
    );
  }

  Future<void> _setLocale(Locale locale) async {
    final previousLanguageWasEnglish = context.isEnglish;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AppPreferencesCubit>().setLocale(locale);

    final languageLabel = switch (locale.languageCode) {
      'en' => 'English',
      _ => 'Español',
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          previousLanguageWasEnglish
              ? '$languageLabel language applied'
              : 'Idioma $languageLabel aplicado',
        ),
      ),
    );
  }

  Future<void> _openExternalLink(Uri uri, String errorMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
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
        final tr = context;
        final theme = Theme.of(context);
        final palette = context.exomPalette;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(tr.copy('Ajustes', 'Settings')),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SettingsGroup(
                title: tr.copy('Apariencia', 'Appearance'),
                children: [
                  _ThemeModeTile(
                    icon: Icons.phone_android_outlined,
                    title: tr.copy('Sistema', 'System'),
                    subtitle: tr.copy(
                      'Sigue automáticamente el modo configurado en tu dispositivo',
                      'Follow the mode configured on your device',
                    ),
                    selected: preferences.themeMode == ThemeMode.system,
                    onTap: () => _setThemeMode(ThemeMode.system),
                  ),
                  _ThemeModeTile(
                    icon: Icons.light_mode_outlined,
                    title: tr.copy('Claro', 'Light'),
                    subtitle: tr.copy(
                      'Activa una versión luminosa y cálida alineada con la paleta del producto',
                      'Use the warm light palette aligned with the product look',
                    ),
                    selected: preferences.themeMode == ThemeMode.light,
                    onTap: () => _setThemeMode(ThemeMode.light),
                  ),
                  _ThemeModeTile(
                    icon: Icons.dark_mode_outlined,
                    title: tr.copy('Oscuro', 'Dark'),
                    subtitle: tr.copy(
                      'Mantiene la experiencia nocturna actual para reducir brillo y fatiga visual',
                      'Keep the current night experience to reduce glare and fatigue',
                    ),
                    selected: preferences.themeMode == ThemeMode.dark,
                    onTap: () => _setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: tr.copy('Cuenta', 'Account'),
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    title: tr.copy('Editar perfil', 'Edit profile'),
                    subtitle: tr.copy(
                      'Foto, objetivo y datos visibles en tu ficha',
                      'Photo, goal and visible personal details',
                    ),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                  _SettingsTile(
                    icon: Icons.straighten_outlined,
                    title: tr.copy('Mis métricas', 'My metrics'),
                    subtitle: tr.copy(
                      'Peso, masa muscular, sueño y medidas corporales',
                      'Weight, muscle mass, sleep and body measurements',
                    ),
                    onTap: () => context.push('/profile/metrics'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: tr.copy('Unidades', 'Units'),
                children: [
                  _ThemeModeTile(
                    icon: Icons.straighten,
                    title: tr.copy('Métrico', 'Metric'),
                    subtitle: tr.copy(
                      'Usa kilos y centímetros en toda la app',
                      'Use kilograms and centimeters across the app',
                    ),
                    selected: preferences.unitSystem == UnitSystem.metric,
                    onTap: () => _setUnitSystem(UnitSystem.metric),
                  ),
                  _ThemeModeTile(
                    icon: Icons.square_foot,
                    title: 'Imperial',
                    subtitle: tr.copy(
                      'Usa libras e pulgadas, guardando en métrico internamente',
                      'Use pounds and inches while keeping metric storage internally',
                    ),
                    selected: preferences.unitSystem == UnitSystem.imperial,
                    onTap: () => _setUnitSystem(UnitSystem.imperial),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: tr.copy('Idioma', 'Language'),
                children: [
                  _ThemeModeTile(
                    icon: Icons.language,
                    title: 'Español',
                    subtitle: tr.copy(
                      'Interfaz principal en español.',
                      'Main interface in Spanish.',
                    ),
                    selected: preferences.locale.languageCode == 'es',
                    onTap: () => _setLocale(const Locale('es', 'ES')),
                  ),
                  _ThemeModeTile(
                    icon: Icons.translate,
                    title: 'English',
                    subtitle: tr.copy(
                      'Interfaz principal en inglés.',
                      'Main interface in English.',
                    ),
                    selected: preferences.locale.languageCode == 'en',
                    onTap: () => _setLocale(const Locale('en')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: tr.copy('Privacidad', 'Privacy'),
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: tr.copy('Política de privacidad', 'Privacy policy'),
                    subtitle: tr.copy(
                      'Abre la política externa para revisar tratamiento de datos y privacidad.',
                      'Open the external privacy policy to review data handling',
                    ),
                    onTap: () => _openExternalLink(
                      ExternalLinks.privacyPolicy,
                      tr.copy(
                        'No se pudo abrir la política de privacidad.',
                        'Could not open the privacy policy.',
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_outlined,
                    title: tr.copy('Soporte y contacto', 'Support and contact'),
                    subtitle: tr.copy(
                      'Abre la página de soporte o escribe a soporte@exom.app.',
                      'Open the support page or email soporte@exom.app',
                    ),
                    onTap: () => _openExternalLink(
                      ExternalLinks.supportPage,
                      tr.copy(
                        'No se pudo abrir la página de soporte.',
                        'Could not open the support page.',
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.alternate_email,
                    title: tr.copy('Escribir a soporte', 'Email support'),
                    subtitle: tr.copy(
                      'Prepara un email externo para soporte técnico.',
                      'Prepare an external email for technical support.',
                    ),
                    onTap: () => _openExternalLink(
                      ExternalLinks.supportEmail,
                      tr.copy(
                        'No se pudo abrir la aplicación de correo.',
                        'Could not open the mail app.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: tr.copy('Notificaciones', 'Notifications'),
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: tr.copy('Notificaciones push', 'Push notifications'),
                    subtitle: tr.copy(
                      'Avisos de entrenador, seguimiento y recordatorios',
                      'Coach alerts, follow-up and reminders',
                    ),
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
                title: tr.copy('Datos y soporte', 'Data and support'),
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_off_outlined,
                    title: tr.copy('Modo offline', 'Offline mode'),
                    subtitle: tr.copy(
                      'La app conserva el ultimo Home, Perfil, Calendario, Dieta y Entreno cargados',
                      'The app keeps the latest Home, Profile, Calendar, Diet and Training data loaded',
                    ),
                    onTap: null,
                  ),
                  _SettingsTile(
                    icon: Icons.cleaning_services_outlined,
                    title: tr.copy('Borrar caché local', 'Clear local cache'),
                    subtitle: tr.copy(
                      'Elimina datos offline guardados en este dispositivo',
                      'Remove offline data stored on this device',
                    ),
                    onTap: _clearOfflineCache,
                  ),
                  _SettingsTile(
                    icon: Icons.feedback_outlined,
                    title: tr.copy('Enviar feedback', 'Send feedback'),
                    subtitle: tr.copy(
                      'Comparte dudas, incidencias o feedback técnico',
                      'Share doubts, issues or technical feedback',
                    ),
                    onTap: () => context.push(AppRoutes.feedback),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: tr.copy('Ayuda y FAQ', 'Help and FAQ'),
                    subtitle: tr.copy(
                      'Preguntas frecuentes, uso offline y soporte',
                      'Frequently asked questions, offline usage and support',
                    ),
                    onTap: () => context.push(AppRoutes.help),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: tr.copy('Aplicación', 'Application'),
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: tr.copy('Versión', 'Version'),
                    subtitle: tr.copy(
                      'Build actual del cliente móvil',
                      'Current mobile client build',
                    ),
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
                    title: tr.copy('Créditos', 'Credits'),
                    subtitle: tr.copy(
                      'Tecnología y stack del producto',
                      'Product technology and stack',
                    ),
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
                label: Text(tr.copy('Cerrar sesión', 'Log out')),
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

  Future<void> _openExternalLink(
    BuildContext context,
    Uri uri,
    String errorMessage,
  ) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

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
              'EXOM es un producto de valor añadido para clientes, desarrollado por Carlos Sánchez Román con app móvil en Flutter y backend en NestJS.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.code, color: palette.primary, size: 20),
              ),
              title: Text(
                'Carlos Sánchez Román',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'github.com/carsan-dev',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textDisabled,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new,
                color: palette.textDisabled,
                size: 18,
              ),
              onTap: () => _openExternalLink(
                context,
                ExternalLinks.developerGithub,
                'No se pudo abrir el perfil de GitHub.',
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
