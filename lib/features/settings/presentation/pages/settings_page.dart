import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/services/fcm_service.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/logout_confirmation.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where an inline message of the page belongs: next to the control that
/// produced it (D14-3).
enum _NoticeTarget {
  theme,
  units,
  language,
  push,
  restSound,
  lastSetReminder,
  clearCache,
  links,
  deleteAccount,
}

/// One inline message. The text is built with the current localizations, so
/// a language change re-renders it in the new language.
class _Notice {
  const _Notice(this.target, this.kind, this.text, {this.onRetry});

  final _NoticeTarget target;
  final ExomMessageKind kind;
  final String Function(AppLocalizations l10n) text;
  final VoidCallback? onRetry;
}

enum _LanguageChoice { system, spanish, english }

/// Settings (sketch `b-cuenta.html` «B2 · Ajustes», contract L5-B3).
///
/// * Confirmations and errors are inline, next to the control (D14-3): one
///   message at a time, replaced by the next action. Only the successful
///   account deletion keeps its SnackBar, because the page leaves at once
///   (the ephemeral notice stays for what happens off the screen, L5-D14).
/// * Switches answer at once and go back with the error under their row if
///   the change cannot be saved (M8).
/// * «Borrar caché» always asks first in a straight sheet, with an amber
///   notice when an unfinished circuit would be lost (L5-D29); «Eliminar
///   cuenta» asks in a sheet that cannot be dismissed and needs the typed
///   word (R14). Both close without acting when the router location changes
///   (CC 11).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _restTimerSoundEnabled = true;
  bool _lastSetReminderEnabled = true;
  bool _busy = false;
  _Notice? _notice;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled =
        sl<LocalStorage>().getSetting<bool>(
          'push_notifications_enabled',
          defaultValue: true,
        ) ??
        true;
    _restTimerSoundEnabled = sl<LocalStorage>().getRestTimerSoundEnabled();
    _lastSetReminderEnabled =
        sl<LocalStorage>().getSetting<bool>(
          'last_set_video_reminder_enabled',
          defaultValue: true,
        ) ??
        true;
  }

  void _show(_Notice notice) => setState(() => _notice = notice);

  /// Drops the message of [target] (call inside `setState`).
  void _clearNoticeOf(_NoticeTarget target) {
    if (_notice?.target == target) _notice = null;
  }

  /// A switch whose change could not be saved goes back (unless a later tap
  /// already moved it) and says so under its row (M8).
  void _switchFailed(
    _NoticeTarget target,
    bool attempted,
    bool Function() read,
    void Function(bool value) write,
  ) {
    if (!mounted) return;
    setState(() {
      if (read() == attempted) write(!attempted);
      _notice = _Notice(
        target,
        ExomMessageKind.error,
        (l10n) => attempted
            ? l10n.settingsSwitchEnableFailed
            : l10n.settingsSwitchDisableFailed,
      );
    });
  }

  Future<void> _toggleRestTimerSound(bool enabled) async {
    setState(() {
      _restTimerSoundEnabled = enabled;
      _clearNoticeOf(_NoticeTarget.restSound);
    });
    try {
      await sl<LocalStorage>().saveRestTimerSoundEnabled(enabled);
    } catch (_) {
      _switchFailed(
        _NoticeTarget.restSound,
        enabled,
        () => _restTimerSoundEnabled,
        (value) => _restTimerSoundEnabled = value,
      );
      return;
    }
    final restTimerCoordinator = sl<RestTimerCoordinator>();
    final activeSession = restTimerCoordinator.activeSession;
    if (activeSession != null) {
      await restTimerCoordinator.start(activeSession);
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final storage = sl<LocalStorage>();
    final previous = _notificationsEnabled;
    setState(() {
      _notificationsEnabled = enabled;
      _busy = true;
      _clearNoticeOf(_NoticeTarget.push);
    });

    try {
      await storage.saveSetting('push_notifications_enabled', enabled);
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
    } catch (_) {
      // Go back (M8): the stored preference returns to what the switch shows.
      try {
        await storage.saveSetting('push_notifications_enabled', previous);
      } catch (_) {
        // Best effort only.
      }
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = previous;
        _busy = false;
        _notice = _Notice(
          _NoticeTarget.push,
          ExomMessageKind.error,
          (l10n) => enabled
              ? l10n.settingsPushEnableFailed
              : l10n.settingsPushDisableFailed,
        );
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = _Notice(
        _NoticeTarget.push,
        ExomMessageKind.ok,
        (l10n) => enabled
            ? l10n.notificationsEnabledMessage
            : l10n.notificationsDisabledMessage,
      );
    });
  }

  Future<void> _toggleLastSetReminder(bool enabled) async {
    setState(() {
      _lastSetReminderEnabled = enabled;
      _clearNoticeOf(_NoticeTarget.lastSetReminder);
    });
    try {
      await sl<LocalStorage>().saveSetting(
        'last_set_video_reminder_enabled',
        enabled,
      );
    } catch (_) {
      _switchFailed(
        _NoticeTarget.lastSetReminder,
        enabled,
        () => _lastSetReminderEnabled,
        (value) => _lastSetReminderEnabled = value,
      );
    }
  }

  Future<void> _clearOfflineCache() async {
    final storage = sl<LocalStorage>();
    final l10n = AppLocalizations.of(context);
    // Ownership when the sheet opens: the cache is only cleared for it.
    final sessionStamp = storage.sessionStamp;
    // An unfinished circuit lives only in this cache: warn before losing it.
    final activeCircuit = storage.hasActiveCircuitState;
    setState(() => _clearNoticeOf(_NoticeTarget.clearCache));

    final confirmed = await showExomSheet<bool>(
      context: context,
      title: l10n.clearCacheActiveWorkTitle,
      body: l10n.clearCacheSheetBody,
      builder: activeCircuit
          ? (_) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExomSpacing.xl,
                0,
                ExomSpacing.xl,
                ExomSpacing.lg,
              ),
              child: ExomInlineMessage(
                key: const Key('settings-clear-cache-circuit-warning'),
                kind: ExomMessageKind.pendiente,
                title: l10n.clearCacheActiveWorkMessage,
              ),
            )
          : null,
      actions: [
        Builder(
          builder: (sheetContext) => ExomSecondaryButton(
            key: const Key('settings-clear-cache-confirm'),
            label: l10n.clearCacheConfirmButton,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
        Builder(
          builder: (sheetContext) => ExomQuietButton(
            key: const Key('settings-clear-cache-cancel'),
            label: l10n.cancel,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ),
      ],
    );
    // The session may have ended (or the page gone) while the sheet was
    // open; never clear the cache of whoever owns the storage now.
    if (confirmed != true || !mounted) return;
    if (storage.sessionStamp != sessionStamp) return;
    await storage.clearCache();
    if (!mounted) return;
    _show(
      _Notice(
        _NoticeTarget.clearCache,
        ExomMessageKind.ok,
        (l10n) => l10n.cacheDeletedMessage,
      ),
    );
  }

  /// «Cerrar sesión»: asks first when the account has an unfinished workout
  /// on this device (L5-D67).
  Future<void> _logOut() async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await confirmLogoutIfUnfinishedWorkout(context);
    if (!confirmed || !mounted) return;
    authBloc.add(const AuthLogoutRequested());
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    await context.read<AppPreferencesCubit>().setThemeMode(themeMode);
    if (!mounted) return;
    _show(
      _Notice(
        _NoticeTarget.theme,
        ExomMessageKind.ok,
        (l10n) => l10n.themeAppliedNotification(_themeLabel(l10n, themeMode)),
      ),
    );
  }

  Future<void> _setUnitSystem(UnitSystem unitSystem) async {
    await context.read<AppPreferencesCubit>().setUnitSystem(unitSystem);
    if (!mounted) return;
    _show(
      _Notice(
        _NoticeTarget.units,
        ExomMessageKind.ok,
        (l10n) => l10n.unitsAppliedNotification(_unitLabel(l10n, unitSystem)),
      ),
    );
  }

  Future<void> _setLanguage(_LanguageChoice choice) async {
    final Locale? locale = switch (choice) {
      _LanguageChoice.system => null,
      _LanguageChoice.spanish => const Locale('es', 'ES'),
      _LanguageChoice.english => const Locale('en'),
    };
    await context.read<AppPreferencesCubit>().setLocale(locale);
    if (!mounted) return;
    _show(
      _Notice(
        _NoticeTarget.language,
        ExomMessageKind.ok,
        (l10n) =>
            l10n.languageAppliedNotification(_languageLabel(l10n, choice)),
      ),
    );
  }

  static String _themeLabel(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.systemThemeOption,
        ThemeMode.light => l10n.lightThemeOption,
        ThemeMode.dark => l10n.darkThemeOption,
      };

  static String _unitLabel(AppLocalizations l10n, UnitSystem unitSystem) =>
      switch (unitSystem) {
        UnitSystem.metric => l10n.metricOption,
        UnitSystem.imperial => 'Imperial',
      };

  static String _languageLabel(
    AppLocalizations l10n,
    _LanguageChoice choice,
  ) => switch (choice) {
    _LanguageChoice.system => l10n.systemLanguageOption,
    _LanguageChoice.spanish => 'Español',
    _LanguageChoice.english => 'English',
  };

  static _LanguageChoice _languageOf(AppPreferencesState preferences) {
    if (preferences.isSystemLocale) return _LanguageChoice.system;
    return preferences.locale?.languageCode == 'en'
        ? _LanguageChoice.english
        : _LanguageChoice.spanish;
  }

  Future<void> _openExternalLink(
    Uri uri,
    String Function(AppLocalizations l10n) errorMessage,
  ) async {
    setState(() => _clearNoticeOf(_NoticeTarget.links));
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // No app can handle it: the same outcome as a refused launch.
      launched = false;
    }
    if (launched || !mounted) return;
    _show(
      _Notice(
        _NoticeTarget.links,
        ExomMessageKind.error,
        errorMessage,
        onRetry: () => _openExternalLink(uri, errorMessage),
      ),
    );
  }

  /// Uploads that still need something: queue entries not dismissed and not
  /// `completed` (the only terminal status the queue writes). Queued,
  /// uploading, processing, failed and discarding all still count (read only;
  /// the queue is never written here).
  int _pendingUploadCount() => sl<LocalStorage>()
      .getFeedbackUploadQueue()
      .where(
        (item) => item['dismissed'] != true && item['status'] != 'completed',
      )
      .length;

  Future<void> _openPendingUploads() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PendingUploadsPage()),
    );
    // The queue may have changed there: refresh the counter.
    if (mounted) setState(() {});
  }

  void _showCredits() {
    final l10n = AppLocalizations.of(context);
    showExomSheet<void>(
      context: context,
      title: l10n.creditsOption,
      body: l10n.creditsDescription,
      builder: (_) => const _CreditsLinks(),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final confirmWord = l10n.deleteAccountConfirmWord;
    final controller = TextEditingController();
    setState(() => _clearNoticeOf(_NoticeTarget.deleteAccount));

    final bool? confirmed;
    try {
      confirmed = await showExomSheet<bool>(
        context: context,
        // R14: neither a tap outside, a drag nor back closes it.
        isDismissible: false,
        enableDrag: false,
        title: l10n.deleteAccountDialogTitle,
        body: l10n.deleteAccountDialogBody,
        builder: (_) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExomSpacing.xl,
            ExomSpacing.xs,
            ExomSpacing.xl,
            ExomSpacing.lg,
          ),
          child: TextField(
            key: const Key('settings-delete-account-field'),
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.deleteAccountConfirmHint,
              hintText: confirmWord,
              helperText: l10n.deleteAccountConfirmHelper(confirmWord),
              helperMaxLines: 4,
            ),
          ),
        ),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (sheetContext, value, _) {
              final canConfirm = value.text.trim().toUpperCase() == confirmWord;
              return ExomSecondaryButton(
                key: const Key('settings-delete-account-confirm'),
                label: l10n.deleteAccountConfirmButton,
                onPressed: canConfirm
                    ? () => Navigator.of(sheetContext).pop(true)
                    : null,
              );
            },
          ),
          Builder(
            builder: (sheetContext) => ExomQuietButton(
              key: const Key('settings-delete-account-cancel'),
              label: l10n.deleteAccountCancelButton,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
        ],
      );
    } finally {
      // The sheet future completes once its subtree is disposed.
      controller.dispose();
    }

    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const AuthAccountDeletionRequested());
    }
  }

  /// The inline message of [target], or nothing. [padding] places it under
  /// a full-width row (`.b-rmsg`) or inside a padded block.
  Widget _noticeFor(
    _NoticeTarget target, {
    EdgeInsetsGeometry padding = const EdgeInsetsDirectional.fromSTEB(
      ExomSpacing.xl,
      0,
      ExomSpacing.xl,
      14,
    ),
  }) {
    final notice = _notice;
    if (notice == null || notice.target != target) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final retry = notice.onRetry;
    return Padding(
      padding: padding,
      child: ExomInlineMessage(
        key: ValueKey('settings-notice-${target.name}'),
        kind: notice.kind,
        title: notice.text(l10n),
        actionLabel: retry == null ? null : l10n.retry,
        onAction: retry,
      ),
    );
  }

  Widget _sectionHeader(int n, String title, {double top = ExomSpacing.xxl}) =>
      Padding(
        padding: EdgeInsets.only(top: top),
        child: ExomNumberedSectionHeader(n: n, title: title),
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppPreferencesCubit, AppPreferencesState>(
      builder: (context, preferences) {
        final palette = context.exomPalette;
        final l10n = AppLocalizations.of(context);
        final appVersionLabel = sl<AppUpdateService>().currentVersionLabel;
        final pendingUploads = _pendingUploadCount();
        const inBlock = EdgeInsets.only(top: ExomSpacing.sm);

        return ExomStaticBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // Sketch B2: the bar only carries «Volver»; the title is the body.
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            body: BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) =>
                  current is AuthAccountDeleted ||
                  (current is AuthError && previous is AuthLoading),
              listener: (context, state) {
                if (state is AuthAccountDeleted) {
                  // The page leaves with the session: the notice is shown
                  // outside it, so it stays a SnackBar.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.deleteAccountSuccessMessage),
                      backgroundColor: palette.error,
                    ),
                  );
                } else if (state is AuthError) {
                  _show(
                    _Notice(
                      _NoticeTarget.deleteAccount,
                      ExomMessageKind.error,
                      (l10n) => l10n.deleteAccountErrorMessage,
                    ),
                  );
                }
              },
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: ExomSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _SettingsHeader(
                    title: l10n.settingsPageTitle,
                    subtitle: l10n.settingsSubtitle,
                  ),
                  _sectionHeader(1, l10n.appearanceSettingsTitle, top: 32),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExomSpacing.xl,
                      ExomSpacing.sm,
                      ExomSpacing.xl,
                      ExomSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ControlBlock(
                          label: l10n.settingsThemeLabel,
                          control: ExomSegmentedControl<ThemeMode>(
                            key: const Key('settings-theme-control'),
                            options: const [
                              ThemeMode.system,
                              ThemeMode.light,
                              ThemeMode.dark,
                            ],
                            selected: preferences.themeMode,
                            labelOf: (mode) => _themeLabel(l10n, mode),
                            onChanged: _setThemeMode,
                          ),
                          notice: _noticeFor(
                            _NoticeTarget.theme,
                            padding: inBlock,
                          ),
                        ),
                        const SizedBox(height: ExomSpacing.lg),
                        _ControlBlock(
                          label: l10n.unitsSettingsTitle,
                          control: ExomSegmentedControl<UnitSystem>(
                            key: const Key('settings-units-control'),
                            options: const [
                              UnitSystem.metric,
                              UnitSystem.imperial,
                            ],
                            selected: preferences.unitSystem,
                            labelOf: (unit) => _unitLabel(l10n, unit),
                            onChanged: _setUnitSystem,
                          ),
                          hint: l10n.settingsUnitsHint,
                          notice: _noticeFor(
                            _NoticeTarget.units,
                            padding: inBlock,
                          ),
                        ),
                        const SizedBox(height: ExomSpacing.lg),
                        _ControlBlock(
                          label: l10n.languageSettingsTitle,
                          control: ExomSegmentedControl<_LanguageChoice>(
                            key: const Key('settings-language-control'),
                            options: _LanguageChoice.values,
                            selected: _languageOf(preferences),
                            labelOf: (choice) => _languageLabel(l10n, choice),
                            onChanged: _setLanguage,
                          ),
                          notice: _noticeFor(
                            _NoticeTarget.language,
                            padding: inBlock,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _sectionHeader(2, l10n.accountSettingsTitle, top: 0),
                  _SettingsIndex(
                    children: [
                      _SettingsIndexRow(
                        title: l10n.editProfileOption,
                        icon: ExomIcons.next,
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                      _SettingsIndexRow(
                        title: l10n.myMetricsOption,
                        icon: ExomIcons.next,
                        onTap: () => context.push('/profile/metrics'),
                      ),
                    ],
                  ),
                  _sectionHeader(3, l10n.notificationsSettingsTitle),
                  ExomFlatRowGroup(
                    children: [
                      ExomSwitchRow(
                        key: const Key('settings-push-switch'),
                        label: l10n.pushNotificationsOption,
                        value: _notificationsEnabled,
                        onChanged: _busy ? null : _toggleNotifications,
                      ),
                      _noticeFor(_NoticeTarget.push),
                      ExomSwitchRow(
                        key: const Key('settings-rest-sound-switch'),
                        label: l10n.restTimerSoundOption,
                        value: _restTimerSoundEnabled,
                        onChanged: _toggleRestTimerSound,
                      ),
                      _noticeFor(_NoticeTarget.restSound),
                      ExomSwitchRow(
                        key: const Key('settings-last-set-reminder-switch'),
                        label: l10n.lastSetVideoReminderOption,
                        value: _lastSetReminderEnabled,
                        onChanged: _toggleLastSetReminder,
                      ),
                      _noticeFor(_NoticeTarget.lastSetReminder),
                    ],
                  ),
                  _sectionHeader(4, l10n.dataAndSupportTitle),
                  ExomFlatRow(
                    title: l10n.offlineModeOption,
                    subtitles: [l10n.offlineModeDescription],
                  ),
                  _SettingsIndex(
                    children: [
                      _SettingsIndexRow(
                        key: const Key('settings-clear-cache'),
                        title: l10n.clearCacheOption,
                        onTap: _clearOfflineCache,
                      ),
                      _noticeFor(
                        _NoticeTarget.clearCache,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          ExomSpacing.xl,
                          0,
                          ExomSpacing.xl,
                          14,
                        ),
                      ),
                      _SettingsIndexRow(
                        key: const Key('settings-pending-uploads'),
                        title: l10n.pendingUploadsOption,
                        icon: ExomIcons.next,
                        status: pendingUploads == 0
                            ? null
                            : Semantics(
                                key: const Key(
                                  'settings-pending-uploads-count',
                                ),
                                label: l10n.pendingUploadsCountSubtitle(
                                  pendingUploads,
                                ),
                                excludeSemantics: true,
                                child: ExomSyncStatus(
                                  state: ExomSyncState.pendiente,
                                  label: '$pendingUploads',
                                ),
                              ),
                        onTap: _openPendingUploads,
                      ),
                      _SettingsIndexRow(
                        title: l10n.sendFeedbackOption,
                        icon: ExomIcons.next,
                        onTap: () => context.push(AppRoutes.feedback),
                      ),
                      _SettingsIndexRow(
                        title: l10n.helpAndFaqOption,
                        icon: ExomIcons.next,
                        onTap: () => context.push(AppRoutes.help),
                      ),
                    ],
                  ),
                  _sectionHeader(5, l10n.privacySettingsTitle),
                  _SettingsIndex(
                    children: [
                      _SettingsIndexRow(
                        key: const Key('settings-privacy-policy'),
                        title: l10n.privacyPolicyOption,
                        icon: ExomIcons.openExternal,
                        onTap: () => _openExternalLink(
                          ExternalLinks.privacyPolicy,
                          (l10n) => l10n.privacyPolicyNotOpenedError,
                        ),
                      ),
                      _SettingsIndexRow(
                        title: l10n.supportContactOption,
                        icon: ExomIcons.openExternal,
                        onTap: () => _openExternalLink(
                          ExternalLinks.supportPage,
                          (l10n) => l10n.supportPageNotOpenedError,
                        ),
                      ),
                      _SettingsIndexRow(
                        title: l10n.serviceSupportEmailOption,
                        icon: ExomIcons.openExternal,
                        onTap: () => _openExternalLink(
                          ExternalLinks.serviceSupportEmail,
                          (l10n) => l10n.mailAppNotOpenedError,
                        ),
                      ),
                      _SettingsIndexRow(
                        title: l10n.technicalSupportEmailOption,
                        icon: ExomIcons.openExternal,
                        onTap: () => _openExternalLink(
                          ExternalLinks.technicalSupportEmail,
                          (l10n) => l10n.mailAppNotOpenedError,
                        ),
                      ),
                    ],
                  ),
                  _noticeFor(
                    _NoticeTarget.links,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExomSpacing.xl,
                      ExomSpacing.md,
                      ExomSpacing.xl,
                      0,
                    ),
                  ),
                  _sectionHeader(6, l10n.applicationSettingsTitle),
                  ExomFlatRowGroup(
                    children: [
                      ExomValueRow(
                        label: l10n.versionOption,
                        value: appVersionLabel,
                      ),
                    ],
                  ),
                  _SettingsIndex(
                    children: [
                      _SettingsIndexRow(
                        key: const Key('settings-credits'),
                        title: l10n.creditsOption,
                        icon: ExomIcons.next,
                        onTap: _showCredits,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExomSpacing.xl,
                      32,
                      ExomSpacing.xl,
                      0,
                    ),
                    child: ExomSecondaryButton(
                      key: const Key('settings-logout'),
                      label: l10n.logOutButton,
                      onPressed: _logOut,
                    ),
                  ),
                  // `.b-danger`: the destructive link after a hairline.
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExomSpacing.xl,
                      32,
                      ExomSpacing.xl,
                      0,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: palette.borderSoft,
                            width: ExomRule.hairline,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: ExomSpacing.sm),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ExomTextLink(
                            key: const Key('settings-delete-account'),
                            label: l10n.deleteAccountOption,
                            danger: true,
                            onTap: _confirmDeleteAccount,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _noticeFor(
                    _NoticeTarget.deleteAccount,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExomSpacing.xl,
                      ExomSpacing.sm,
                      ExomSpacing.xl,
                      0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Screen title (sketch `.t1` + `.sec`): Barlow Condensed 800 painted upper
/// case, one header node with the original text, then the secondary line.
class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label: title,
            excludeSemantics: true,
            child: Text(
              title.toUpperCase(),
              style: ExomType.screenTitle.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          Text(subtitle, style: _secondaryStyle(context)),
        ],
      ),
    );
  }
}

TextStyle _secondaryStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 14,
  height: 1.35,
  color: context.exomPalette.textSecondary,
);

/// One decision of «Apariencia» (`.stack.g8`): its label, the segmented
/// control in place, an optional hint and its inline message.
class _ControlBlock extends StatelessWidget {
  const _ControlBlock({
    required this.label,
    required this.control,
    required this.notice,
    this.hint,
  });

  final String label;
  final Widget control;
  final Widget notice;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hintText = hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: context.exomPalette.textPrimary,
          ),
        ),
        const SizedBox(height: ExomSpacing.sm),
        control,
        if (hintText != null) ...[
          const SizedBox(height: ExomSpacing.sm),
          Text(hintText, style: _secondaryStyle(context)),
        ],
        notice,
      ],
    );
  }
}

/// Destinations as an index (`.x-ixs`): entries stacked and closed by a
/// bottom hairline.
class _SettingsIndex extends StatelessWidget {
  const _SettingsIndex({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.exomPalette.borderSoft,
            width: ExomRule.hairline,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Index entry of Settings (`.x-ix` without number, as in sketch B2): the
/// title in the section style (Barlow Condensed 800, 22, painted upper case
/// and read in its original case), an optional [status] and a trailing
/// [icon]. At least 60 tall with a hairline on top; one merged button node.
class _SettingsIndexRow extends StatelessWidget {
  const _SettingsIndexRow({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.status,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final trailingIcon = icon;
    final statusWidget = status;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: ExomRowSurface(
          onTap: onTap,
          minHeight: 60,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: title,
                  excludeSemantics: true,
                  child: Text(
                    title.toUpperCase(),
                    style: ExomType.section.copyWith(color: palette.textPrimary),
                  ),
                ),
              ),
              if (statusWidget != null) ...[
                const SizedBox(width: 14),
                statusWidget,
              ],
              if (trailingIcon != null) ...[
                const SizedBox(width: 14),
                ExcludeSemantics(
                  child: Icon(
                    trailingIcon,
                    size: 22,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Content of the «Créditos» sheet under its title and description: the
/// developer's GitHub profile, and an inline error with «Reintentar» when it
/// does not open (D14-3).
class _CreditsLinks extends StatefulWidget {
  const _CreditsLinks();

  @override
  State<_CreditsLinks> createState() => _CreditsLinksState();
}

class _CreditsLinksState extends State<_CreditsLinks> {
  bool _failed = false;

  Future<void> _openGithub() async {
    setState(() => _failed = false);
    var launched = false;
    try {
      launched = await launchUrl(
        ExternalLinks.developerGithub,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      launched = false;
    }
    if (!mounted) return;
    setState(() => _failed = !launched);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ExomSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MergeSemantics(
            child: Semantics(
              button: true,
              child: ExomRowSurface(
                key: const Key('settings-credits-github'),
                onTap: _openGithub,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Carlos Sánchez Román',
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            'github.com/carsan-dev',
                            style: _secondaryStyle(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Icon(
                        ExomIcons.openExternal,
                        size: 22,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExomSpacing.xl,
                ExomSpacing.md,
                ExomSpacing.xl,
                0,
              ),
              child: ExomInlineMessage(
                key: const Key('settings-credits-error'),
                kind: ExomMessageKind.error,
                title: l10n.couldNotOpenGithubProfile,
                actionLabel: l10n.retry,
                onAction: _openGithub,
              ),
            ),
        ],
      ),
    );
  }
}
