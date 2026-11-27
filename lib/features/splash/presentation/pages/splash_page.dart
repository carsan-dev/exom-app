import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/onboarding/onboarding_readers.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_curtain.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_scene.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/features/splash/presentation/widgets/splash_update_dialog.dart';
import 'package:exom_app/injection_container.dart';

/// Start-up screen, V4d «La X de la palabra» (L5-D3, L5-D18).
///
/// The gates are the same as before: it never leaves while auth is
/// unresolved or the update decision is pending, and a required update
/// blocks. While they are pending the X is opaque and nothing is built under
/// it. Once they resolve (`t_ready`) the opening starts at once (see
/// [V4dTimeline]):
///
/// * valid session and destination Inicio: the splash hands off to a curtain
///   in the root overlay ([V4dCurtain]) and navigates to Inicio, which is
///   built under the opaque X from that moment; the opening starts when
///   Inicio has painted content, at the latest 600 ms after `t_ready` and
///   not before 660 ms (r3, D3-Q6, [V4dTimeline.inicioOpeningStart]); Inicio
///   is usable 790 ms after it starts (`max(1450, t_open + 790)`);
/// * destination login (r4, D3-Q9): [V4dTimeline.handOffOtherDestination]
///   ms after `t_ready` the splash hands off to a curtain and navigates to
///   the login, which is built under the opaque X with no transition; the X
///   opens onto it ([V4dTimeline.loginOpeningStart]) and the login is usable
///   790 ms after the opening starts. Inicio is never built;
/// * onboarding or locked account: the window opens on a neutral
///   background, Inicio is never built, and the splash navigates
///   [V4dTimeline.handOffOtherDestination] ms after `t_ready`.
///
/// Reduced motion: fixed lockup and a 120 ms fade. Destination Inicio (r4,
/// D3-Q8): Inicio is built under the lockup at `t_ready` and the fade starts
/// at `max(600, min(t_content, t_ready + 600))`; other destinations: it fades
/// to the background at `max(600, t_ready)` and navigates 120 ms later.
/// A tap skips the entry while the gates are pending and jumps to the end
/// once they are resolved; it never skips a gate. After 2 s with pending
/// gates an icon and a phrase say it is still connecting.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  /// Key of the curtain that plays the opening over Inicio.
  static const curtainKey = ValueKey<String>('splash-v4d-curtain');

  /// Key of the slow-start notice.
  static const slowStartKey = V4dScene.slowStartKey;

  /// Colour of the X of the window for [theme] (D3-Q3).
  static Color xInkFor(ThemeData theme) => v4dXInk(theme);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _gateTimeout = Duration(seconds: 6);

  late final Future<AppUpdateDecision> _updateDecisionFuture;
  late final Ticker _ticker = createTicker(_onTick);
  final _layouts = V4dLayoutCache();
  V4dLayout? _layout;

  /// Frame time stamp of the first frame: the origin of every time here.
  Duration? _origin;

  /// ms since the first frame (last frame seen).
  double _time = 0;
  double? _readyAt;
  String? _destination;
  bool _entrySkipped = false;
  bool _slowStart = false;
  bool _reduced = false;

  /// Navigated or handed off: nothing else happens here.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _updateDecisionFuture = sl<AppUpdateService>().checkForUpdates();
    _ticker.start();
    _waitForGates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  bool get _toInicio => _destination == AppRoutes.home;
  bool get _toLogin => _destination == AppRoutes.login;

  void _onTick(Duration elapsed) {
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    final origin = _origin ??= stamp - elapsed;
    _time = (stamp - origin).inMicroseconds / 1000;
    if (_done) return;
    final ready = _readyAt;
    final wasSlow = _slowStart;
    if (ready == null) {
      if (_time >= V4dTimeline.slowStart) _slowStart = true;
    } else if (_toInicio) {
      if (_layout != null && _confirmInicio()) {
        // Inicio is built under the X (or the reduced lockup) now; the
        // curtain starts the opening (or the fade) once Inicio has content
        // (D3-Q6, D3-Q8).
        _handOffToInicio();
        return;
      }
    } else if (_reduced) {
      final fadeAt = V4dTimeline.reducedFadeStart(ready);
      if (_time >= fadeAt + V4dTimeline.reducedFade) {
        _navigate();
        return;
      }
    } else if (_time >= ready + V4dTimeline.handOffOtherDestination) {
      _leave();
      return;
    }
    // At rest with the gates pending nothing moves: no rebuild per frame.
    final resting =
        ready == null &&
        (_entrySkipped || _time > V4dTimeline.entryEnd) &&
        _slowStart == wasSlow;
    if (!resting) setState(() {});
  }

  /// Waits for the real gates (auth status and update decision), as before
  /// L5-D3, then starts the opening.
  Future<void> _waitForGates() async {
    final authSettled = _waitForAuthToSettle(context.read<AuthBloc>());
    final shouldContinue = await _handlePendingUpdate();
    if (!mounted || !shouldContinue) return;
    await authSettled;
    if (!mounted) return;
    _onGatesReady();
  }

  void _onGatesReady() {
    if (_done) return;
    final ready = _time;
    _readyAt = ready;
    _destination = _resolveDestination();
    // The hand-off to Inicio (or the opening here) starts on the next frame,
    // once the layout of this frame exists; the timeline counts from `ready`.
    setState(() {});
  }

  Future<void> _waitForAuthToSettle(AuthBloc authBloc) async {
    bool pending(AuthState state) =>
        state is AuthInitial || state is AuthLoading;
    if (!pending(authBloc.state)) return;
    try {
      await authBloc.stream
          .firstWhere((state) => !pending(state))
          .timeout(_gateTimeout);
    } catch (error) {
      debugPrint('[SPLASH] Auth status still pending: $error');
    }
  }

  Future<bool> _handlePendingUpdate() async {
    final AppUpdateDecision decision;
    try {
      decision = await _updateDecisionFuture.timeout(_gateTimeout);
    } catch (error) {
      debugPrint('[SPLASH] Skipping update gate: $error');
      return mounted;
    }

    if (!mounted || !decision.shouldPrompt) {
      return mounted;
    }

    final l10n = AppLocalizations.of(context);
    final title = decision.title.isNotEmpty
        ? decision.title
        : decision.isBlocking
        ? l10n.requiredUpdateTitle
        : l10n.recommendedUpdateTitle;
    final message = decision.message.isNotEmpty
        ? decision.message
        : decision.isBlocking
        ? l10n.requiredUpdateMessage
        : l10n.recommendedUpdateMessage;

    final result = await showSplashUpdateDialog(
      context,
      title: title,
      message: message,
      blocking: decision.isBlocking,
      openStore: () => sl<AppUpdateService>().openStore(decision),
    );
    if (decision.isBlocking) return false;
    return result ?? true;
  }

  String _resolveDestination() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAccountLocked) return AppRoutes.accountLocked;
    if (authState is! AuthAuthenticated) return AppRoutes.login;

    final session = sl<FirebaseAuthService>().currentSession;
    if (session == null) return AppRoutes.login;
    final resolution = resolveOnboardingForSession(
      authState: authState,
      session: session,
      storage: sl<LocalStorage>(),
    );
    return resolution?.needsOnboarding == true
        ? AppRoutes.onboarding
        : AppRoutes.home;
  }

  /// Reads the destination again at the moment of handing off, as the splash
  /// did before L5-D3 when it navigated: the session may have changed since
  /// `t_ready` (logout, locked account). Returns whether it is still Inicio;
  /// if not, the splash continues towards the new destination and Inicio is
  /// never built.
  bool _confirmInicio() {
    _destination = _resolveDestination();
    return _toInicio;
  }

  /// Gates resolved, valid session, destination Inicio: the rest of the
  /// opening (or the reduced fade) plays in the root overlay while Inicio is
  /// mounted under it; the curtain starts it once Inicio has painted
  /// content (D3-Q6, D3-Q8).
  void _handOffToInicio() {
    final layout = _layout!;
    _insertCurtain(openAt: null, content: V4dWindowContent.inicio);
    V4dHandoff.inicioContent.value = false;
    V4dHandoff.current.value = V4dOpening.waiting(
      centre: layout.xCentre,
      reduced: _reduced,
    );
    context.go(AppRoutes.home);
  }

  /// [V4dTimeline.handOffOtherDestination] ms after `t_ready` (normal
  /// motion, destination other than Inicio). The destination is read again
  /// now: if it is still the login, hand off to it under the X (D3-Q9);
  /// otherwise navigate as before. r5: only when the login was already the
  /// planned destination. With onboarding or a locked account the window
  /// opened on the neutral background at `t_ready`; if the session is lost
  /// meanwhile, a hand-off would bring back a filled X and open it again, so
  /// it navigates to the login as before ([_navigate] reads it again).
  void _leave() {
    if (_toLogin &&
        _layout != null &&
        _resolveDestination() == AppRoutes.login) {
      _destination = AppRoutes.login;
      // The login is built under the X on this frame and the X starts to
      // empty on the next one at the earliest. This frame is the first at or
      // after the planned mount, so the start is that of the splash scene
      // or up to one frame later (never earlier: the X never jumps ahead).
      _handOffToLogin(V4dTimeline.loginOpeningStart(_time));
      return;
    }
    _navigate();
  }

  /// Start of the opening onto the login that the splash shows until it
  /// hands off (D3-Q9): the login is mounted at
  /// `t_ready + handOffOtherDestination`.
  static double _plannedLoginOpening(double ready) =>
      V4dTimeline.loginOpeningStart(
        ready + V4dTimeline.handOffOtherDestination,
      );

  /// D3-Q9: the rest of the opening plays in the root overlay while the
  /// login, built under it with no transition ([V4dHandoff.loginEntry]),
  /// shows through the X. Inicio is not involved.
  void _handOffToLogin(double openAt) {
    V4dHandoff.loginEntry.value = true;
    _insertCurtain(openAt: openAt, content: V4dWindowContent.login);
    context.go(AppRoutes.login);
  }

  void _insertCurtain({
    required double? openAt,
    required V4dWindowContent content,
  }) {
    final layout = _layout!;
    final origin = _origin!;
    _done = true;
    _ticker.stop();
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => V4dCurtain(
        key: SplashPage.curtainKey,
        origin: origin,
        startAt: _time,
        readyAt: _readyAt!,
        openAt: openAt,
        centre: layout.xCentre,
        reduced: _reduced,
        entrySkipped: _entrySkipped,
        slowStart: _slowStart,
        content: content,
        onDone: () {
          entry.remove();
          entry.dispose();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _navigate() {
    // Null until the gates resolve: never navigate before them.
    if (_done || _destination == null) return;
    // Read again now, not at `t_ready` (see [_confirmInicio]).
    final destination = _destination = _resolveDestination();
    _done = true;
    _ticker.stop();
    context.go(destination);
  }

  /// A tap never skips a gate: before they resolve it only ends the entry;
  /// after, it jumps to the end.
  void _onTap() {
    if (_done) return;
    if (_readyAt == null) {
      if (!_entrySkipped) setState(() => _entrySkipped = true);
      return;
    }
    if (!_reduced &&
        _layout != null &&
        _resolveDestination() == AppRoutes.login) {
      // D3-Q9: the end of the opening onto the login is the login, at once
      // (no fade); the curtain, already open, goes on its first frame.
      _destination = AppRoutes.login;
      _handOffToLogin(_time - V4dTimeline.usable);
      return;
    }
    _navigate();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final ready = _readyAt;
    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _layout = _layouts.resolve(
            size: constraints.biggest,
            brightness: Theme.of(context).brightness,
            textScaler: MediaQuery.textScalerOf(context),
            welcome: [l10n.splashWelcomeFirst, l10n.splashWelcomeSecond],
            baseStyle: DefaultTextStyle.of(context).style,
          );
          if (_reduced) {
            final fade = ready == null || _toInicio
                ? 0.0
                : V4dTimeline.progress(
                    _time,
                    V4dTimeline.reducedFadeStart(ready),
                    V4dTimeline.reducedFade,
                  );
            return V4dReducedScene(
              fade: fade,
              slowStart: _slowStart,
              content: V4dWindowContent.neutral,
              onTap: _onTap,
            );
          }
          return V4dScene(
            layout: layout,
            time: _time,
            // Inicio hands off at once. The login opens here until it is
            // mounted (no hole yet, D3-Q9); other destinations at t_ready.
            openAt: ready == null || _toInicio
                ? null
                : _toLogin
                ? _plannedLoginOpening(ready)
                : V4dTimeline.openingStart(ready),
            entrySkipped: _entrySkipped,
            slowStart: _slowStart,
            content: V4dWindowContent.neutral,
            onTap: _onTap,
          );
        },
      ),
    );
  }
}
