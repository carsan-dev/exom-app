import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/theme/exom_page_transitions.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/core/widgets/exom_app_bar.dart';
import 'package:exom_app/core/widgets/exom_bottom_nav.dart';
import 'package:exom_app/core/widgets/tutorial_overlay.dart';

// Auth pages
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/account_locked_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/logout_confirmation.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';

// Home pages
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';

// Training pages
import '../../features/trainings/presentation/pages/trainings_page.dart';
import '../../features/trainings/presentation/pages/training_detail_page.dart';
import '../../features/trainings/presentation/pages/active_exercise_page.dart';
import '../../features/trainings/presentation/pages/active_circuit_page.dart';

// Diet pages
import '../../features/diets/presentation/pages/diets_page.dart';

// Calendar pages
import '../../features/calendar/presentation/pages/calendar_page.dart';

// Profile pages
import '../../features/profile/presentation/pages/profile_page.dart';

// Metrics pages
import '../../features/metrics/presentation/pages/metrics_progress_page.dart';
import '../../features/progress_photos/presentation/pages/progress_photos_page.dart';

// Challenges pages
import '../../features/challenges/presentation/pages/challenges_page.dart';

// Recap pages
import '../../features/recap/presentation/pages/recap_page.dart';
import '../../features/recap/presentation/pages/recap_detail_page.dart';

// Feedback pages
import '../../features/feedback/presentation/pages/feedback_page.dart';

// Notifications pages
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';

// Settings pages
import '../../features/settings/presentation/pages/settings_page.dart';

// Help pages
import '../../features/help/presentation/pages/help_page.dart';

// Onboarding pages
import '../../features/onboarding/presentation/pages/onboarding_page.dart';

// Splash
import '../../features/splash/presentation/pages/splash_page.dart';

// Storage
import '../../core/auth/auth_token_provider.dart';
import '../../core/auth/firebase_auth_service.dart';
import '../../core/onboarding/onboarding_readers.dart';
import '../../core/prompts/automatic_prompt_coordinator.dart';
import '../../core/prompts/automatic_prompt_layer.dart';
import '../../core/services/fcm_service.dart';
import '../../core/storage/local_storage.dart';
import '../../injection_container.dart';

class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const accountLocked = '/account-locked';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const trainings = '/trainings';
  static const trainingDetail = '/trainings/:id';
  static const activeExercise = '/trainings/:id/exercises/:exerciseId';
  static const activeCircuit = '/trainings/:id/circuits/:blockId';
  static const diets = '/diets';
  static const calendar = '/calendar';
  static const profile = '/profile';
  static const metrics = '/profile/metrics';
  static const progressPhotos = '/profile/progress-photos';
  static const challenges = '/challenges';
  static const recap = '/recap';
  static const recapDetailBase = '/recap';
  static const feedback = '/feedback';
  static const notifications = '/notifications';

  static String recapDetail(String id) => '/recap/$id';
  static String activeExercisePath(String trainingId, String exerciseId) =>
      '/trainings/$trainingId/exercises/$exerciseId';
  static String activeCircuitPath(String trainingId, String blockId) =>
      '/trainings/$trainingId/circuits/$blockId';
  static const settings = '/settings';
  static const help = '/help';
}

/// Page of the main `ShellRoute` (L5-D3). The same as the default
/// `MaterialPage` of a `builder` route, except when it is created during the
/// V4d hand-off ([V4dHandoff.active]): then Inicio appears at once under the
/// splash curtain, with no entry transition, so the window of the X shows it
/// in place. The screen's later transitions (covered by a pushed route) are
/// unchanged.
@visibleForTesting
class ShellEntryPage<T> extends Page<T> {
  const ShellEntryPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) =>
      _ShellEntryRoute<T>(page: this, instant: V4dHandoff.active);
}

/// The main shell's page: [MainShell] in [V4dHomeEntrance], with the keys
/// GoRouter gives a `builder` route's `MaterialPage`.
Page<void> _mainShellPage(GoRouterState state, Widget child) =>
    ShellEntryPage<void>(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: <String, String>{
        ...state.pathParameters,
        ...state.uri.queryParameters,
      },
      restorationId: state.pageKey.value,
      child: V4dHomeEntrance(child: MainShell(child: child)),
    );

class _ShellEntryRoute<T> extends MaterialPageRoute<T> {
  _ShellEntryRoute({required ShellEntryPage<T> page, required this.instant})
    : super(settings: page, builder: _unused);

  static Widget _unused(BuildContext context) => const SizedBox.shrink();

  /// Created during the V4d hand-off: no entry transition. Only the entry:
  /// its exit (popped) uses the normal reverse transition, whose duration
  /// [MaterialRouteTransitionMixin.reverseTransitionDuration] already gives.
  final bool instant;

  @override
  Widget buildContent(BuildContext context) =>
      (settings as ShellEntryPage<T>).child;

  @override
  Duration get transitionDuration =>
      instant ? Duration.zero : super.transitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions(
    context,
    instant && animation.status != AnimationStatus.reverse
        ? kAlwaysCompleteAnimation
        : animation,
    secondaryAnimation,
    child,
  );
}

/// Page of the login route: a 600 ms fade, except when the splash hands off
/// to the login under its curtain (L5-D3, D3-Q9, [V4dHandoff.loginEntry]).
/// Then the login appears at once under the X, which opens onto it. Every
/// other entry to the login (logout, expired session) keeps the fade.
@visibleForTesting
Page<void> loginRoutePage({required LocalKey key, required Widget child}) =>
    CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: V4dHandoff.loginEntry.value
          ? Duration.zero
          : const Duration(milliseconds: 600),
      transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      ),
    );

/// Build a platform-aware [Page]: native iOS swipe-back via [CupertinoPage],
/// Material slide on Android. Used for full-screen routes outside the shell.
Page<T> _platformPage<T>({
  required LocalKey key,
  required Widget child,
  String? name,
}) {
  final isIos = !kIsWeb && Platform.isIOS;
  if (isIos) {
    return CupertinoPage<T>(key: key, name: name, child: child);
  }
  return MaterialPage<T>(key: key, name: name, child: child);
}

String? resolveAppRouteRedirect({
  required String location,
  required bool isAuthenticated,
  required bool hasFirebaseUser,
  required bool isOnboardingComplete,
  bool isLocked = false,
  bool isCompletingAuth = false,
}) {
  if (location == AppRoutes.splash) return null;

  final isAuthRoute =
      location == AppRoutes.login ||
      location == AppRoutes.forgotPassword ||
      location == AppRoutes.accountLocked;
  if (isLocked && location != AppRoutes.accountLocked) {
    return AppRoutes.accountLocked;
  }
  if (!isAuthenticated && !isAuthRoute) return AppRoutes.login;
  if (isAuthenticated && !hasFirebaseUser && !isAuthRoute) {
    return AppRoutes.login;
  }
  if (hasFirebaseUser && location == AppRoutes.login && isCompletingAuth) {
    return null;
  }
  if (isAuthenticated && hasFirebaseUser && location == AppRoutes.login) {
    return isOnboardingComplete ? AppRoutes.home : AppRoutes.onboarding;
  }
  if (isAuthenticated &&
      hasFirebaseUser &&
      !isAuthRoute &&
      location != AppRoutes.onboarding &&
      !isOnboardingComplete) {
    return AppRoutes.onboarding;
  }
  return null;
}

/// Reads the auth state, the local Firebase session and the onboarding
/// readers, then delegates the decision to [resolveAppRouteRedirect].
String? resolveAppRouteRedirectFor({
  required String location,
  required AuthState authState,
  required LocalAuthSession? session,
  required LocalStorage storage,
  bool isCompletingAuth = false,
}) {
  if (location == AppRoutes.splash) return null;

  final isAuthenticated = authState is AuthAuthenticated;
  final isLocked = authState is AuthAccountLocked;
  final isAuthRoute =
      location == AppRoutes.login ||
      location == AppRoutes.forgotPassword ||
      location == AppRoutes.accountLocked;
  final shouldCheckOnboarding =
      isAuthenticated &&
      session != null &&
      (location == AppRoutes.login ||
          (!isAuthRoute && location != AppRoutes.onboarding));
  final isOnboardingComplete =
      shouldCheckOnboarding &&
      isOnboardingSettled(
        resolveOnboardingForSession(
          authState: authState,
          session: session,
          storage: storage,
        ),
      );
  return resolveAppRouteRedirect(
    location: location,
    isAuthenticated: isAuthenticated,
    hasFirebaseUser: session != null,
    isOnboardingComplete: isOnboardingComplete,
    isLocked: isLocked,
    isCompletingAuth: isCompletingAuth,
  );
}

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final Listenable _refreshListenable = GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == AppRoutes.splash) return null;

      return resolveAppRouteRedirectFor(
        location: loc,
        authState: context.read<AuthBloc>().state,
        session: sl<FirebaseAuthService>().currentSession,
        storage: sl<LocalStorage>(),
        isCompletingAuth: _isCompletingAuth(context),
      );
    },
    refreshListenable: _refreshListenable,
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      // Auth
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            loginRoutePage(key: state.pageKey, child: const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) {
          final initialEmail = state.uri.queryParameters['email'];
          return _platformPage(
            key: state.pageKey,
            child: ForgotPasswordPage(initialEmail: initialEmail),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.accountLocked,
        builder: (context, state) => const AccountLockedPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        // L5-D3: Inicio under the splash. Only the splash navigates here
        // during the hand-off, after the gates resolve with a valid session.
        pageBuilder: (context, state, child) => _mainShellPage(state, child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => ExomTabPage(
              key: state.pageKey,
              child: HomePage(
                completionRefresh: switch (state.extra) {
                  HomeCompletionRefresh refresh => refresh,
                  _ => null,
                },
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.trainings,
            pageBuilder: (_, state) => ExomTabPage(
              key: state.pageKey,
              child: TrainingsPage(
                selectedDate: state.uri.queryParameters['date'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.diets,
            pageBuilder: (_, state) => ExomTabPage(
              key: state.pageKey,
              child: DietsPage(selectedDate: state.uri.queryParameters['date']),
            ),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (context, state) => ExomTabPage(
              key: state.pageKey,
              child: CalendarPage(
                initialDate: state.uri.queryParameters['date'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.challenges,
            pageBuilder: (context, state) =>
                ExomTabPage(key: state.pageKey, child: const ChallengesPage()),
          ),
        ],
      ),

      // Training detail (no shell — full-screen push with native iOS swipe-back)
      GoRoute(
        path: AppRoutes.trainingDetail,
        pageBuilder: (_, state) => _platformPage(
          key: state.pageKey,
          name: state.name,
          child: TrainingDetailPage(
            trainingId: state.pathParameters['id']!,
            selectedDate: state.uri.queryParameters['date'],
            selectedExecutionId: state.uri.queryParameters['execution'],
            finalizeSelected: state.uri.queryParameters['action'] == 'finalize',
          ),
        ),
        routes: [
          GoRoute(
            path: 'exercises/:exerciseId',
            pageBuilder: (_, state) => _platformPage(
              key: state.pageKey,
              name: state.name,
              child: ActiveExercisePage(
                trainingId: state.pathParameters['id']!,
                exerciseId: state.pathParameters['exerciseId']!,
                args: state.extra as ActiveExercisePageArgs?,
              ),
            ),
          ),
          GoRoute(
            path: 'circuits/:blockId',
            pageBuilder: (_, state) => _platformPage(
              key: state.pageKey,
              name: state.name,
              child: ActiveCircuitPage(
                trainingId: state.pathParameters['id']!,
                blockId: state.pathParameters['blockId']!,
                args: state.extra as ActiveCircuitPageArgs?,
              ),
            ),
          ),
        ],
      ),

      // Profile (no shell nav bar — accessible from drawer)
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, state) => _platformPage(
          key: state.pageKey,
          name: state.name,
          child: const ProfilePage(),
        ),
        routes: [
          GoRoute(
            path: 'metrics',
            pageBuilder: (_, state) => _platformPage(
              key: state.pageKey,
              name: state.name,
              child: const MetricsProgressPage(),
            ),
          ),
          GoRoute(
            path: 'progress-photos',
            pageBuilder: (_, state) => _platformPage(
              key: state.pageKey,
              name: state.name,
              child: const ProgressPhotosPage(),
            ),
          ),
        ],
      ),

      // Modal routes (no shell)
      GoRoute(
        path: AppRoutes.recap,
        pageBuilder: (_, state) => _platformPage(
          key: state.pageKey,
          name: state.name,
          child: const RecapPage(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (_, state) => _platformPage(
              key: state.pageKey,
              name: state.name,
              child: RecapDetailPage(recapId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.feedback,
        pageBuilder: (_, state) {
          final extra = state.extra as FeedbackPageArgs?;
          return _platformPage(
            key: state.pageKey,
            name: state.name,
            child: FeedbackPage(args: extra),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (_, state) => _platformPage(
          key: state.pageKey,
          name: state.name,
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, state) => _platformPage(
          key: state.pageKey,
          name: state.name,
          child: const SettingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        pageBuilder: (_, state) => _platformPage(
          key: state.pageKey,
          name: state.name,
          child: const HelpPage(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          AppLocalizations.of(
            context,
          ).pageNotFoundError(state.error.toString()),
        ),
      ),
    ),
  );
}

// ─── Main Shell ────────────────────────────────────────────────────────────────

bool _isCompletingAuth(BuildContext context) {
  try {
    return context.read<AuthBloc>().state is AuthLoading;
  } catch (_) {
    return false;
  }
}

/// Inicio shows its data (from the cache or the network), not the skeleton
/// nor an error: the V4d opening may start (L5-D3 r3, D3-Q6).
@visibleForTesting
bool isInicioContent(HomeState state) =>
    state is HomeLoaded || state is HomeRestDay;

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  // Tab order: Challenges, Trainings, Home (center), Diets, Calendar
  static const _tabs = [
    AppRoutes.challenges,
    AppRoutes.trainings,
    AppRoutes.home,
    AppRoutes.diets,
    AppRoutes.calendar,
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _drawerItemKeys = List.generate(7, (_) => GlobalKey());
  bool _showTutorial = false;
  late final NotificationsBloc _notificationsBloc;
  late final HomeBloc _homeBloc;
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  StreamSubscription<HomeState>? _inicioContent;
  StreamSubscription<HomeState>? _bellRecovery;
  bool _inicioUnavailable = false;

  @override
  void initState() {
    super.initState();
    _homeBloc = sl<HomeBloc>()..add(const HomeLoadRequested());
    // L5-D3 r3 (D3-Q6): under the splash, the opening waits for this.
    _inicioContent = V4dHandoff.watchInicioContent(
      () => _homeBloc.stream,
      isInicioContent,
    );
    _notificationsBloc = sl<NotificationsBloc>()
      ..add(const NotificationsUnreadCountRefreshRequested());
    _fcmSubscription = sl<FcmService>().onIncomingMessage.listen((_) {
      _notificationsBloc.add(const NotificationsUnreadCountRefreshRequested());
    });
    _bellRecovery = _homeBloc.stream.listen(_refreshBellOnReconnection);
  }

  /// L5-D49: the counter failed silently while offline, so when Inicio goes
  /// from stale data (or an error) to fresh data, which means the network is
  /// back, the bell asks again: once per transition, to the bloc of the
  /// session that is current now, never one held from another account.
  void _refreshBellOnReconnection(HomeState state) {
    final summary = switch (state) {
      HomeLoaded(:final summary) || HomeRestDay(:final summary) => summary,
      _ => null,
    };
    if (state is HomeError ||
        (summary != null && summary.staleReason != null)) {
      _inicioUnavailable = true;
    } else if (summary != null && _inicioUnavailable) {
      _inicioUnavailable = false;
      sl<NotificationsBloc>().add(
        const NotificationsUnreadCountRefreshRequested(),
      );
    }
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _inicioContent?.cancel();
    _bellRecovery?.cancel();
    _homeBloc.close();
    super.dispose();
  }

  int _currentIndex(String location) {
    if (location == '/') return 2; // Home is center
    if (location.startsWith('/challenges')) return 0;
    if (location.startsWith('/trainings')) return 1;
    if (location.startsWith('/diets')) return 3;
    if (location.startsWith('/calendar')) return 4;
    return 2;
  }

  AutomaticPromptSession? _readPromptSession() => automaticPromptSessionFor(
    authState: context.read<AuthBloc>().state,
    session: sl<FirebaseAuthService>().currentSession,
    storage: sl<LocalStorage>(),
  );

  void _startTutorial() {
    setState(() => _showTutorial = true);
  }

  void _completeTutorial() {
    // Close drawer if open
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    _markTutorialComplete();
    setState(() => _showTutorial = false);
    context.go(AppRoutes.home);
  }

  void _markTutorialComplete() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    sl<LocalStorage>().setTutorialCompleteFor(uid: user.uid, email: user.email);
  }

  void _onTutorialOpenDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _onTutorialCloseDrawer() {
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    final selected = _currentIndex(location);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top + kToolbarHeight;
    final bottomInset = ExomBottomNav.reservedHeight(context);

    // Scaffold wrapped in Stack so overlay renders ABOVE drawer
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>.value(value: _homeBloc),
        BlocProvider<NotificationsBloc>.value(value: _notificationsBloc),
      ],
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: ExomAppBar(
              // L5-D3: the header logo lands at the end of the V4d opening.
              title: const V4dHeaderLanding(child: ExomBrandLogo(height: 28)),
              actions: [
                BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    final unread = state.unreadCount;
                    return IconButton(
                      tooltip: l10n.notificationsTitle,
                      onPressed: () async {
                        await context.push(AppRoutes.notifications);
                        if (!mounted) return;
                        _notificationsBloc.add(
                          const NotificationsUnreadCountRefreshRequested(),
                        );
                      },
                      // The badge digit alone would be the node's label: it is
                      // replaced by one that names the bell and its count.
                      icon: Semantics(
                        label: l10n.notificationsBellLabel(unread),
                        excludeSemantics: true,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              ExomIcons.notifications,
                              color: palette.textPrimary,
                              size: 24,
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -8,
                                top: -7,
                                child: ShellUnreadBadge(count: unread),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: l10n.profileMenuItem,
                  onPressed: () => context.push(AppRoutes.profile),
                  icon: Icon(
                    ExomIcons.profile,
                    color: palette.textPrimary,
                    size: 24,
                  ),
                ),
                Builder(
                  builder: (ctx) => IconButton(
                    tooltip: l10n.shellMenuTooltip,
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    icon: Icon(
                      ExomIcons.menu,
                      color: palette.textPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            endDrawer: AppDrawer(drawerItemKeys: _drawerItemKeys),
            body: ExomStaticBackground(
              child: Padding(
                padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                child: SizedBox.expand(child: widget.child),
              ),
            ),
            bottomNavigationBar: ExomBottomNav(
              selectedIndex: selected,
              onTap: (i) => context.go(MainShell._tabs[i]),
            ),
          ),
          // Automatic prompts only on /home, after the first frame and once
          // the onboarding is settled (avoids races during redirects, e.g.
          // login→home→onboarding).
          AutomaticPromptLayer(
            coordinator: sl<AutomaticPromptCoordinator>(),
            active: location == AppRoutes.home,
            readSession: _readPromptSession,
            onStartTutorial: _startTutorial,
            onOpenRecap: () => context.push(AppRoutes.recap),
          ),
          if (_showTutorial)
            TutorialOverlay(
              onNavigate: (route) => context.go(route),
              onOpenDrawer: _onTutorialOpenDrawer,
              onCloseDrawer: _onTutorialCloseDrawer,
              onComplete: _completeTutorial,
              drawerItemKeys: _drawerItemKeys,
            ),
        ],
      ),
    );
  }
}

// ─── Shell badge ───────────────────────────────────────────────────────────────

/// Unread counter of the shell's notification bell (V4, redesign L2): `text`
/// fill with the background colour as label, DM Sans 600 13 (was 9 px).
/// Its text scale is capped at 1.0 so it stays inside the 48x48 button.
@visibleForTesting
class ShellUnreadBadge extends StatelessWidget {
  const ShellUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: Container(
        height: 19,
        constraints: const BoxConstraints(minWidth: 19),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.textPrimary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            color: palette.background,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─── App Drawer ────────────────────────────────────────────────────────────────

/// End drawer of [MainShell] (L5-F2). Panel of 304 dp (screen - 56 when
/// narrower) with a left rule: logo, the account name as protagonist (Barlow
/// 28) and «Miembro EXOM»; the six destinations as a numbered index 01-06 and
/// «Cerrar sesión» as a secondary button after a rule. The panel scrolls when
/// it does not fit (large text, short screens).
///
/// [drawerItemKeys] (in order: profile, challenges, weekly recap, feedback,
/// settings, help, log out) sit on the label texts and are used by the
/// tutorial overlay to locate them.
///
/// [displayName] is a test seam: when null the name is read from Firebase.
@visibleForTesting
class AppDrawer extends StatelessWidget {
  final List<GlobalKey> drawerItemKeys;
  final String? displayName;

  const AppDrawer({
    super.key,
    required this.drawerItemKeys,
    this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name =
        displayName ??
        FirebaseAuth.instance.currentUser?.displayName ??
        l10n.userDefaultName;
    final palette = context.exomPalette;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // The destination being shown (L5-F2-ICONOS): by the router's matched
    // location, prefix of the destination's route. None outside a router or
    // on any other screen.
    final location = GoRouter.maybeOf(context)?.state.matchedLocation;
    bool isCurrent(String route) =>
        location != null &&
        (location == route || location.startsWith('$route/'));

    // Pops the drawer and then runs [go]: the order every entry always had.
    VoidCallback leave(VoidCallback go) => () {
      Navigator.pop(context);
      go();
    };

    // «Cerrar sesión» (L5-D67): the confirmation, if any, opens while the
    // drawer is still mounted; it closes only once the user goes on. Cancel
    // leaves everything as it was.
    Future<void> logOut() async {
      final authBloc = context.read<AuthBloc>();
      final confirmed = await confirmLogoutIfUnfinishedWorkout(context);
      if (!confirmed || !context.mounted) return;
      Navigator.pop(context);
      authBloc.add(const AuthLogoutRequested());
    }

    return Drawer(
      width: math.min(304.0, math.max(0.0, screenWidth - 56)),
      backgroundColor: palette.background,
      shape: const RoundedRectangleBorder(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(
            left: BorderSide(color: palette.borderSoft, width: 1),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExomBrandLogo(height: 24),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        label: name,
                        excludeSemantics: true,
                        child: Text(
                          name.toUpperCase(),
                          style: ExomType.headline2Section.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.exomMemberLabel,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFontFamily,
                          color: palette.textSecondary,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                ExomIndexList(
                  items: [
                    ExomIndexItem(
                      title: l10n.profileMenuItem,
                      leading: ExomIcons.profile,
                      selected: isCurrent(AppRoutes.profile),
                      titleKey: drawerItemKeys[0],
                      onTap: leave(() => context.push(AppRoutes.profile)),
                    ),
                    ExomIndexItem(
                      title: l10n.challengesMenuItem,
                      leading: ExomIcons.trophy,
                      selected: isCurrent(AppRoutes.challenges),
                      titleKey: drawerItemKeys[1],
                      onTap: leave(() => context.go(AppRoutes.challenges)),
                    ),
                    ExomIndexItem(
                      title: l10n.weeklyRecapMenuItem,
                      leading: ExomIcons.barChart,
                      selected: isCurrent(AppRoutes.recap),
                      titleKey: drawerItemKeys[2],
                      onTap: leave(() => context.push(AppRoutes.recap)),
                    ),
                    ExomIndexItem(
                      title: l10n.feedbackMenuItem,
                      leading: ExomIcons.feedback,
                      selected: isCurrent(AppRoutes.feedback),
                      titleKey: drawerItemKeys[3],
                      onTap: leave(() => context.push(AppRoutes.feedback)),
                    ),
                    ExomIndexItem(
                      title: l10n.settingsMenuItem,
                      leading: ExomIcons.settings,
                      selected: isCurrent(AppRoutes.settings),
                      titleKey: drawerItemKeys[4],
                      onTap: leave(() => context.push(AppRoutes.settings)),
                    ),
                    ExomIndexItem(
                      title: l10n.helpMenuItem,
                      leading: ExomIcons.help,
                      selected: isCurrent(AppRoutes.help),
                      titleKey: drawerItemKeys[5],
                      onTap: leave(() => context.push(AppRoutes.help)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: ExomSecondaryButton(
                    label: l10n.logOutMenuItem,
                    labelKey: drawerItemKeys[6],
                    onPressed: logOut,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── GoRouter Refresh Stream ───────────────────────────────────────────────────

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
