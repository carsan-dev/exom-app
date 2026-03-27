import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/config/external_links.dart';
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _notificationsEnabled = enabled;
      _busy = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? l10n.notificationsEnabledMessage
              : l10n.notificationsDisabledMessage,
        ),
      ),
    );
  }

  Future<void> _clearOfflineCache() async {
    await sl<LocalStorage>().clearCache();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.cacheDeletedMessage)),
    );
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AppPreferencesCubit>().setThemeMode(themeMode);

    final themeLabel = switch (themeMode) {
      ThemeMode.system => l10n.systemThemeOption,
      ThemeMode.light => l10n.lightThemeOption,
      ThemeMode.dark => l10n.darkThemeOption,
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.themeAppliedNotification(themeLabel)),
      ),
    );
  }

  Future<void> _setUnitSystem(UnitSystem unitSystem) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AppPreferencesCubit>().setUnitSystem(unitSystem);

    final unitLabel = switch (unitSystem) {
      UnitSystem.metric => l10n.metricOption,
      UnitSystem.imperial => 'Imperial',
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.unitsAppliedNotification(unitLabel)),
      ),
    );
  }

  Future<void> _setLocale(Locale? locale) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AppPreferencesCubit>().setLocale(locale);

    final languageLabel = switch (locale?.languageCode) {
      'en' => 'English',
      'es' => 'Español',
      _ => l10n.systemLanguageOption,
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.languageAppliedNotification(languageLabel)),
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
        final theme = Theme.of(context);
        final palette = context.exomPalette;
        final l10n = AppLocalizations.of(context)!;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(l10n.settingsPageTitle),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SettingsGroup(
                title: l10n.appearanceSettingsTitle,
                children: [
                  _ThemeModeTile(
                    icon: Icons.phone_android_outlined,
                    title: l10n.systemThemeOption,
                    subtitle: l10n.systemThemeDescription,
                    selected: preferences.themeMode == ThemeMode.system,
                    onTap: () => _setThemeMode(ThemeMode.system),
                  ),
                  _ThemeModeTile(
                    icon: Icons.light_mode_outlined,
                    title: l10n.lightThemeOption,
                    subtitle: l10n.lightThemeDescription,
                    selected: preferences.themeMode == ThemeMode.light,
                    onTap: () => _setThemeMode(ThemeMode.light),
                  ),
                  _ThemeModeTile(
                    icon: Icons.dark_mode_outlined,
                    title: l10n.darkThemeOption,
                    subtitle: l10n.darkThemeDescription,
                    selected: preferences.themeMode == ThemeMode.dark,
                    onTap: () => _setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: l10n.accountSettingsTitle,
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    title: l10n.editProfileOption,
                    subtitle: l10n.editProfileDescription,
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                  _SettingsTile(
                    icon: Icons.straighten_outlined,
                    title: l10n.myMetricsOption,
                    subtitle: l10n.myMetricsDescription,
                    onTap: () => context.push('/profile/metrics'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: l10n.unitsSettingsTitle,
                children: [
                  _ThemeModeTile(
                    icon: Icons.straighten,
                    title: l10n.metricOption,
                    subtitle: l10n.metricDescription,
                    selected: preferences.unitSystem == UnitSystem.metric,
                    onTap: () => _setUnitSystem(UnitSystem.metric),
                  ),
                  _ThemeModeTile(
                    icon: Icons.square_foot,
                    title: 'Imperial',
                    subtitle: l10n.imperialDescription,
                    selected: preferences.unitSystem == UnitSystem.imperial,
                    onTap: () => _setUnitSystem(UnitSystem.imperial),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: l10n.languageSettingsTitle,
                children: [
                  _ThemeModeTile(
                    icon: Icons.phone_android_outlined,
                    title: l10n.systemLanguageOption,
                    subtitle: l10n.systemLanguageDescription,
                    selected: preferences.isSystemLocale,
                    onTap: () => _setLocale(null),
                  ),
                  _ThemeModeTile(
                    icon: Icons.language,
                    title: 'Español',
                    subtitle: l10n.spanishLanguageDescription,
                    selected: !preferences.isSystemLocale &&
                        preferences.locale?.languageCode == 'es',
                    onTap: () => _setLocale(const Locale('es', 'ES')),
                  ),
                  _ThemeModeTile(
                    icon: Icons.translate,
                    title: 'English',
                    subtitle: l10n.englishLanguageDescription,
                    selected: !preferences.isSystemLocale &&
                        preferences.locale?.languageCode == 'en',
                    onTap: () => _setLocale(const Locale('en')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: l10n.privacySettingsTitle,
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.privacyPolicyOption,
                    subtitle: l10n.privacyPolicyDescription,
                    onTap: () => _openExternalLink(
                      ExternalLinks.privacyPolicy,
                      l10n.privacyPolicyNotOpenedError,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_outlined,
                    title: l10n.supportContactOption,
                    subtitle: l10n.supportContactDescription,
                    onTap: () => _openExternalLink(
                      ExternalLinks.supportPage,
                      l10n.supportPageNotOpenedError,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.alternate_email,
                    title: l10n.emailSupportOption,
                    subtitle: l10n.emailSupportOptionDescription,
                    onTap: () => _openExternalLink(
                      ExternalLinks.supportEmail,
                      l10n.mailAppNotOpenedError,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: l10n.notificationsSettingsTitle,
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: l10n.pushNotificationsOption,
                    subtitle: l10n.pushNotificationsDescription,
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
                title: l10n.dataAndSupportTitle,
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_off_outlined,
                    title: l10n.offlineModeOption,
                    subtitle: l10n.offlineModeDescription,
                    onTap: null,
                  ),
                  _SettingsTile(
                    icon: Icons.cleaning_services_outlined,
                    title: l10n.clearCacheOption,
                    subtitle: l10n.clearCacheDescription,
                    onTap: _clearOfflineCache,
                  ),
                  _SettingsTile(
                    icon: Icons.feedback_outlined,
                    title: l10n.sendFeedbackOption,
                    subtitle: l10n.sendFeedbackDescription,
                    onTap: () => context.push(AppRoutes.feedback),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: l10n.helpAndFaqOption,
                    subtitle: l10n.helpAndFaqDescription,
                    onTap: () => context.push(AppRoutes.help),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: l10n.applicationSettingsTitle,
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: l10n.versionOption,
                    subtitle: l10n.versionDescription,
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
                    title: l10n.creditsOption,
                    subtitle: l10n.creditsOptionDescription,
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
                label: Text(l10n.logOutButton),
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
