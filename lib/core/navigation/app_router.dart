import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/glass_bottom_nav.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:exom_app/core/widgets/tutorial_overlay.dart';

// Auth pages
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/account_locked_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';

// Home pages
import '../../features/home/presentation/pages/home_page.dart';

// Training pages
import '../../features/trainings/presentation/pages/trainings_page.dart';
import '../../features/trainings/presentation/pages/training_detail_page.dart';
import '../../features/trainings/presentation/pages/active_exercise_page.dart';

// Diet pages
import '../../features/diets/presentation/pages/diets_page.dart';

// Calendar pages
import '../../features/calendar/presentation/pages/calendar_page.dart';

// Profile pages
import '../../features/profile/presentation/pages/profile_page.dart';

// Metrics pages
import '../../features/metrics/presentation/pages/metrics_page.dart';

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
  static const diets = '/diets';
  static const calendar = '/calendar';
  static const profile = '/profile';
  static const metrics = '/metrics';
  static const challenges = '/challenges';
  static const recap = '/recap';
  static const recapDetailBase = '/recap';
  static const feedback = '/feedback';
  static const notifications = '/notifications';

  static String recapDetail(String id) => '/recap/$id';
  static String activeExercisePath(String trainingId, String exerciseId) =>
      '/trainings/$trainingId/exercises/$exerciseId';
  static const settings = '/settings';
  static const help = '/help';
}

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

      final user = FirebaseAuth.instance.currentUser;
      final isAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.forgotPassword ||
          loc == AppRoutes.accountLocked;
      final isCompletingAuth = _isCompletingAuth(context);

      if (user == null && !isAuthRoute) return AppRoutes.login;
      if (user != null && loc == AppRoutes.login && isCompletingAuth) {
        return null;
      }
      if (user != null && loc == AppRoutes.login) {
        final done = sl<LocalStorage>().isOnboardingCompleteFor(
          uid: user.uid,
          email: user.email,
        );
        return done ? AppRoutes.home : AppRoutes.onboarding;
      }

      // Show onboarding to newly authenticated users who haven't seen it
      if (user != null && !isAuthRoute && loc != AppRoutes.onboarding) {
        final done = sl<LocalStorage>().isOnboardingCompleteFor(
          uid: user.uid,
          email: user.email,
        );
        if (!done) return AppRoutes.onboarding;
      }

      return null;
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (ctx, animation, secondary, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
                child: child,
              ),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) {
          final initialEmail = state.uri.queryParameters['email'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: ForgotPasswordPage(initialEmail: initialEmail),
            transitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder: (ctx, animation, secondary, child) =>
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ),
                  child: child,
                ),
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
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
              transitionDuration: const Duration(milliseconds: 420),
              reverseTransitionDuration: const Duration(milliseconds: 240),
              transitionsBuilder: (ctx, animation, secondary, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: AppRoutes.trainings,
            pageBuilder: (_, state) => NoTransitionPage(
              child: TrainingsPage(
                selectedDate: state.uri.queryParameters['date'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.diets,
            pageBuilder: (_, state) => NoTransitionPage(
              child: DietsPage(selectedDate: state.uri.queryParameters['date']),
            ),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (context, state) => NoTransitionPage(
              child: CalendarPage(
                initialDate: state.uri.queryParameters['date'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.challenges,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChallengesPage()),
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
              child: const MetricsPage(),
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
          final extra = state.extra as Map<String, String?>?;
          return _platformPage(
            key: state.pageKey,
            name: state.name,
            child: FeedbackPage(
              exerciseId: extra?['exerciseId'],
              exerciseName: extra?['exerciseName'],
            ),
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
  bool _showPrompt = false;
  bool _showTutorial = false;
  bool _tutorialChecked = false;
  late final NotificationsBloc _notificationsBloc;
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _notificationsBloc = sl<NotificationsBloc>()
      ..add(const NotificationsUnreadCountRefreshRequested());
    _fcmSubscription = sl<FcmService>().onIncomingMessage.listen((_) {
      _notificationsBloc.add(
        const NotificationsUnreadCountRefreshRequested(),
      );
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  String _brandLogo(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? 'assets/images/logo_dark.svg'
        : 'assets/images/logo.svg';
  }

  int _currentIndex(String location) {
    if (location == '/') return 2; // Home is center
    if (location.startsWith('/challenges')) return 0;
    if (location.startsWith('/trainings')) return 1;
    if (location.startsWith('/diets')) return 3;
    if (location.startsWith('/calendar')) return 4;
    return 2;
  }

  void _checkTutorial() {
    if (_tutorialChecked) return;
    _tutorialChecked = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final storage = sl<LocalStorage>();
    if (!storage.isOnboardingCompleteFor(uid: user.uid, email: user.email)) {
      _tutorialChecked = false;
      return;
    }
    final done = storage.isTutorialCompleteFor(
      uid: user.uid,
      email: user.email,
    );

    if (!done) {
      setState(() => _showPrompt = true);
    }
  }

  void _startTutorial() {
    setState(() {
      _showPrompt = false;
      _showTutorial = true;
    });
  }

  void _skipTutorial() {
    _markTutorialComplete();
    setState(() {
      _showPrompt = false;
      _showTutorial = false;
    });
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
    // Only check tutorial on /home, and only after onboarding is complete.
    // Avoids races during redirects (e.g. login→home→onboarding).
    if (location == AppRoutes.home) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkTutorial();
      });
    }

    final selected = _currentIndex(location);
    final palette = context.exomPalette;
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top + kToolbarHeight;
    final bottomInset = GlassBottomNav.reservedHeight(context);

    // Scaffold wrapped in Stack so overlay renders ABOVE drawer
    return BlocProvider<NotificationsBloc>.value(
      value: _notificationsBloc,
      child: Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: GlassAppBar(
            title: SvgPicture.asset(_brandLogo(context), height: 28),
            actions: [
              BlocBuilder<NotificationsBloc, NotificationsState>(
                builder: (context, state) {
                  final unread = state.unreadCount;
                  return IconButton(
                    onPressed: () async {
                      await context.push(AppRoutes.notifications);
                      if (!mounted) return;
                      _notificationsBloc.add(
                        const NotificationsUnreadCountRefreshRequested(),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.glassBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: palette.glassBorder.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: palette.textPrimary,
                            size: 18,
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              decoration: BoxDecoration(
                                color: palette.primary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: palette.glassBackground,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: () => context.push(AppRoutes.profile),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.glassBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: palette.glassBorder.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: palette.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              Builder(
                builder: (ctx) => IconButton(
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  icon: Icon(Icons.menu, color: palette.textPrimary, size: 26),
                ),
              ),
            ],
          ),
          endDrawer: _AppDrawer(drawerItemKeys: _drawerItemKeys),
          body: ExomStaticBackground(
            child: Padding(
              padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
              child: SizedBox.expand(child: widget.child),
            ),
          ),
          bottomNavigationBar: GlassBottomNav(
            selectedIndex: selected,
            onTap: (i) => context.go(MainShell._tabs[i]),
          ),
        ),
        if (_showPrompt)
          TutorialPromptDialog(onStart: _startTutorial, onSkip: _skipTutorial),
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

// ─── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final List<GlobalKey> drawerItemKeys;

  const _AppDrawer({required this.drawerItemKeys});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);
    final name = user?.displayName ?? l10n.userDefaultName;
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.gradientStart, palette.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: palette.glassBorder.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      Theme.of(context).brightness == Brightness.light
                          ? 'assets/images/logo_dark.svg'
                          : 'assets/images/logo.svg',
                      height: 24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.exomMemberLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _DrawerItem(
                      icon: Icons.person_outline,
                      label: l10n.profileMenuItem,
                      labelKey: drawerItemKeys[0],
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.profile);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.emoji_events_outlined,
                      label: l10n.challengesMenuItem,
                      labelKey: drawerItemKeys[1],
                      onTap: () {
                        Navigator.pop(context);
                        context.go(AppRoutes.challenges);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.bar_chart_outlined,
                      label: l10n.weeklyRecapMenuItem,
                      labelKey: drawerItemKeys[2],
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.recap);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.feedback_outlined,
                      label: l10n.feedbackMenuItem,
                      labelKey: drawerItemKeys[3],
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.feedback);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: l10n.settingsMenuItem,
                      labelKey: drawerItemKeys[4],
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.settings);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.help_outline,
                      label: l10n.helpMenuItem,
                      labelKey: drawerItemKeys[5],
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.help);
                      },
                    ),
                    Divider(color: palette.divider, height: 24),
                    _DrawerItem(
                      icon: Icons.logout,
                      label: l10n.logOutMenuItem,
                      labelKey: drawerItemKeys[6],
                      color: AppColors.error,
                      onTap: () {
                        Navigator.pop(context);
                        context.read<AuthBloc>().add(
                          const AuthLogoutRequested(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final GlobalKey? labelKey;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.labelKey,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? context.exomPalette.textPrimary;
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        key: labelKey,
        label,
        style: TextStyle(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
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
